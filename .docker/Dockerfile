# Base Image
FROM ubuntu:22.04

ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG APP_DIR=/home/${USERNAME}/rnaframework

# Metadata
LABEL base_image="ubuntu:22.04" \
    software="RNA Framework" \
    about.summary="RNA structure probing and post-transcriptional modifications mapping high-throughput data analysis" \
    about.home="https://github.com/dincarnato/RNAFramework" \
    about.documentation="https://rnaframework-docs.readthedocs.io/en/latest/" \
    about.license="SPDX:GPL-3.0-or-later"

# Maintainer
LABEL maintainer="Ken Brewer <ken@kenbrewer.com>"

ENV DEBIAN_FRONTEND=noninteractive
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Add apt-get repositories
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    procps \
    build-essential \
    perl \
    cpanminus \
    libxml2-dev \
    libdbd-mysql-perl \
    git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Perl non-core modules (inc::latest, XML::LibXML, Config::Simple)
RUN cpanm \
    inc::latest \
    XML::LibXML \
    Config::Simple

# Install Mambaforge
USER ${USERNAME}
WORKDIR /home/${USERNAME}
RUN wget -O Mambaforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-$(uname)-$(uname -m).sh" && \
    bash Mambaforge.sh -b -p "${HOME}/conda"
ENV PATH="/home/${USERNAME}/conda/bin:${PATH}"

# Setup Bioconda channel configuration and install dependencies
RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    mamba install -y \
        python=3.10 \
        gxx_linux-64 \
        bowtie>=1.2.3 \
        bowtie2>=2.3.5 \
        samtools>=1.2 \
        bedtools>=2.0 \
        cutadapt>=2.1 \
        viennarna>=2.4.0 \
        rnastructure>=5.6 && \
    mamba clean -a -y

# Install RNA Framework
COPY --chown=${USER_UID}:${USER_GID} . ${APP_DIR}
ENV PATH="${APP_DIR}:${PATH}"
WORKDIR /data