# Use the base image from build argument
ARG BASE_IMAGE=temp-latex-base:latest
FROM ${BASE_IMAGE} AS builder

# Accept build arguments for customization
ARG APT_PACKAGES=apt-packages-minimal.txt
ARG TEXLIVE_PROFILE=texlive-profile-minimal.txt
ARG PACKAGE_LIST=texlive-packages-minimal.txt
ARG TARGETARCH

WORKDIR /build

# Copy configuration files
COPY ${APT_PACKAGES} /tmp/apt-packages.txt
COPY ${TEXLIVE_PROFILE} /tmp/texlive.profile
COPY ${PACKAGE_LIST} /tmp/texlive-packages.txt

# Install additional apt packages
RUN apt-get update -q && \
    apt-get install -qy $(grep -v '^#' /tmp/apt-packages.txt | grep -v '^$') && \
    rm -rf /var/lib/apt/lists/* && \
    rm /tmp/apt-packages.txt

# Install TeX Live with profile
RUN export $(grep -v '^#' /etc/environment | xargs -d '\n') && \
    export LIVE_FOLDER=/usr/local/texlive/$LIVE_YEAR && \
    export LIVE_BIN=${LIVE_FOLDER}/bin/$PLATFORM && \
    echo "LIVE_FOLDER=${LIVE_FOLDER}" >> /etc/environment && \
    echo "LIVE_BIN=${LIVE_BIN}" >> /etc/environment && \
    cp /tmp/texlive.profile /install-tl-unx/texlive.profile && \
    /install-tl-unx/install-tl -profile /install-tl-unx/texlive.profile && \
    # Configure tlmgr
    ${LIVE_BIN}/tlmgr option docfiles 0 && \
    ${LIVE_BIN}/tlmgr update --self && \
    # Install packages
    grep -v '^#' /tmp/texlive-packages.txt | grep -v '^$' | xargs ${LIVE_BIN}/tlmgr -v install || \
    { echo "==== TLMGR INSTALLATION FAILED ===="; \
      echo "==== tlmgr.log ===="; \
      cat ${LIVE_FOLDER}/texmf-var/web2c/tlmgr.log; \
      echo "==== tlmgr-commands.log ===="; \
      cat ${LIVE_FOLDER}/texmf-var/web2c/tlmgr-commands.log; \
      exit 1; \
    } && \
    # Clean up
    rm -rf ${LIVE_FOLDER}/tlpkg/backups/*.tar.xz && \
    rm -rf ${LIVE_FOLDER}/texmf-var/web2c/tlmgr.log ${LIVE_FOLDER}/texmf-var/web2c/tlmgr-commands.log && \
    rm -rf /tmp/texlive-packages.txt /tmp/texlive.profile && \
    rm -rf /install-tl-unx

# Final image with minimal layers
FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /data

# Copy apt packages list for documentation
ARG APT_PACKAGES=apt-packages-minimal.txt
COPY ${APT_PACKAGES} /etc/latex-compiler/apt-packages.txt

# Install only the runtime dependencies
RUN apt-get update -q && \
    apt-get install -qy \
    libfontconfig1 \
    perl \
    $(grep -v '^#' /etc/latex-compiler/apt-packages.txt | grep -v '^$') && \
    rm -rf /var/lib/apt/lists/*

# Copy TeX Live from builder
COPY --from=builder /usr/local/texlive /usr/local/texlive
COPY --from=builder /etc/environment /etc/environment

# Copy the compilation helper script
COPY compile.sh /usr/local/bin/compile.sh
RUN chmod +x /usr/local/bin/compile.sh

# Set up symlinks and PATH
RUN export $(grep -v '^#' /etc/environment | xargs -d '\n') && \
    ln -sf ${LIVE_BIN} /usr/texbin && \
    echo "PATH=/usr/texbin:$PATH" >> /etc/environment

# Set PATH for TeX Live
ENV PATH="/usr/texbin:/usr/local/bin/:$PATH"

VOLUME ["/data"]

# Default command shows usage information
CMD ["bash", "-c", "echo 'LaTeX Compilation Container\n\nUser: $(whoami) ($(id))\n\nUsage examples:\n  docker run --rm -v $(pwd):/data latex-compiler pdflatex main.tex\n  docker run --rm -v $(pwd):/data latex-compiler compile.sh\n  docker run --rm -v $(pwd):/data latex-compiler compile.sh -i document.tex -c\n  docker run --rm -v $(pwd):/data latex-compiler latexmk -pdf main.tex\n  docker run --rm -v $(pwd):/data latex-compiler texliveonfly --compiler=pdflatex main.tex\n  docker run --rm -v $(pwd):/data latex-compiler lualatex main.tex\n  docker run --rm -v $(pwd):/data latex-compiler xelatex main.tex\n\nHelper script usage:\n  compile.sh [OPTIONS]\n  -i, --input FILE     Input LaTeX file (default: main.tex)\n  -o, --output DIR     Output directory (default: current directory)\n  -c, --clean          Clean auxiliary files after compilation\n  -h, --help           Display help message'"]
