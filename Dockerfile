FROM ubuntu:latest
LABEL maintainer="Mattia Bertorello <mattiabertorello@gmail.com>"
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /data

# Accept build arguments package lists
ARG APT_PACKAGES=apt-packages-minimal.txt

# Install core system dependencies (always needed)
RUN apt-get update -q && \
    apt-get install -qy \
    wget \
    perl \
    perl-doc \
    libfontconfig1 \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Copy and install additional apt packages from file
COPY ${APT_PACKAGES} /tmp/apt-packages.txt
RUN apt-get update -q && \
    # Install packages from file (filtering out comments and empty lines)
    apt-get install -qy $(grep -v '^#' /tmp/apt-packages.txt | grep -v '^$') && \
    rm -rf /var/lib/apt/lists/* && \
    rm /tmp/apt-packages.txt

# Copy the TexLive profile
ARG TEXLIVE_PROFILE=texlive-profile-minimal.txt
COPY ${TEXLIVE_PROFILE} /tmp/texlive.profile

# Install TeX Live and packages in one step
RUN wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    mkdir /install-tl-unx && \
    tar -xf install-tl-unx.tar.gz -C /install-tl-unx --strip-components=1 && \
    export PLATFORM=$(/install-tl-unx/install-tl --print-platform) && \
    export LIVE_YEAR=$(/install-tl-unx/install-tl --version | grep -Eo "20[0-9]{2}") && \
    export LIVE_FOLDER=/usr/local/texlive/$LIVE_YEAR && \
    export LIVE_BIN=${LIVE_FOLDER}/bin/$PLATFORM && \
    echo "LIVE_FOLDER=${LIVE_FOLDER}" >> /etc/environment && \
    echo "LIVE_BIN=${LIVE_BIN}" >> /etc/environment && \
    echo "PATH=${LIVE_BIN}:$PATH" >> /etc/environment && \
    cp /tmp/texlive.profile /install-tl-unx/texlive.profile && \
    /install-tl-unx/install-tl -profile /install-tl-unx/texlive.profile && \
    rm -rf /install-tl-unx install-tl-unx.tar.gz /tmp/texlive.profile && \
    # Clean up
    rm -rf ${LIVE_FOLDER}/tlpkg/backups/*.tar.xz && \
    rm -rf ${LIVE_FOLDER}/texmf-var/web2c/tlmgr.log ${LIVE_FOLDER}/texmf-var/web2c/tlmgr-commands.log  && \
    # Create symlink for easier access
    ln -sf ${LIVE_BIN} /usr/texbin

# Configure tlmgr (separate layer for better caching)
RUN export $(grep -v '^#' /etc/environment | xargs -d '\n') && \
    tlmgr option docfiles 0 && \
    tlmgr update --self

# Accept build arguments package lists
ARG PACKAGE_LIST=texlive-packages-minimal.txt

# Copy package list (this will invalidate cache only when packages change)
COPY ${PACKAGE_LIST} /tmp/texlive-packages.txt

# Install LaTeX packages from file (this layer rebuilds only when packages change)
RUN export $(grep -v '^#' /etc/environment | xargs -d '\n') && \
    # Install packages from file (filtering out comments and empty lines)
    grep -v '^#' /tmp/texlive-packages.txt | grep -v '^$' | xargs tlmgr -v install || \
    { echo "==== TLMGR INSTALLATION FAILED ===="; \
      echo "==== tlmgr.log ===="; \
      cat ${LIVE_FOLDER}/texmf-var/web2c/tlmgr.log; \
      echo "==== tlmgr-commands.log ===="; \
      cat ${LIVE_FOLDER}/texmf-var/web2c/tlmgr-commands.log; \
      exit 1; \
    } && \
    # Clean up \
    rm -rf ${LIVE_FOLDER}/tlpkg/backups/*.tar.xz && \
    rm -rf ${LIVE_FOLDER}/texmf-var/web2c/tlmgr.log ${LIVE_FOLDER}/texmf-var/web2c/tlmgr-commands.log && \
    rm -rf /tmp/texlive-packages.txt


# Copy the compilation helper script
COPY compile.sh /usr/local/bin/compile.sh
RUN chmod +x /usr/local/bin/compile.sh

# Set PATH for TeX Live
ENV PATH="/usr/texbin:$PATH"

VOLUME ["/data"]

# Default command shows usage information
CMD ["bash", "-c", "echo 'LaTeX Compilation Container\n\nUser: $(whoami) ($(id))\n\nUsage examples:\n  docker run --rm -v $(pwd):/data latex-compiler pdflatex main.tex\n  docker run --rm -v $(pwd):/data latex-compiler compile.sh\n  docker run --rm -v $(pwd):/data latex-compiler compile.sh -i document.tex -c\n  docker run --rm -v $(pwd):/data latex-compiler latexmk -pdf main.tex\n  docker run --rm -v $(pwd):/data latex-compiler texliveonfly --compiler=pdflatex main.tex\n  docker run --rm -v $(pwd):/data latex-compiler lualatex main.tex\n  docker run --rm -v $(pwd):/data latex-compiler xelatex main.tex\n\nHelper script usage:\n  compile.sh [OPTIONS]\n  -i, --input FILE     Input LaTeX file (default: main.tex)\n  -o, --output DIR     Output directory (default: current directory)\n  -c, --clean          Clean auxiliary files after compilation\n  -h, --help           Display help message'"]