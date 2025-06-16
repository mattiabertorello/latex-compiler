# Base image with common components
FROM ubuntu:latest AS base
LABEL maintainer="Mattia Bertorello <mattiabertorello@gmail.com>"
ENV DEBIAN_FRONTEND=noninteractive

# Install core system dependencies (always needed)
RUN apt-get update -q && \
    apt-get install -qy \
    wget \
    perl \
    perl-doc \
    libfontconfig1 \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Download and extract TeX Live installer (common for all variants)
RUN wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    mkdir /install-tl-unx && \
    tar -xf install-tl-unx.tar.gz -C /install-tl-unx --strip-components=1 && \
    rm install-tl-unx.tar.gz

# Set up environment variables for TeX Live
RUN export PLATFORM=$(/install-tl-unx/install-tl --print-platform) && \
    export LIVE_YEAR=$(/install-tl-unx/install-tl --version | grep -Eo "20[0-9]{2}") && \
    echo "PLATFORM=${PLATFORM}" >> /etc/environment && \
    echo "LIVE_YEAR=${LIVE_YEAR}" >> /etc/environment