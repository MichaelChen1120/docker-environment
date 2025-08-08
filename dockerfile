# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS base

## set as non-interactive mode
ENV DEBIAN_FRONTEND=noninteractive
# set timezone in Taipei
ENV TZ=Asia/Taipei

# === System Configuration ===
# Set timezone and install essential packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
        tzdata \
        bash \
        sudo \
        ca-certificates \
    && ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# === Stage: common_pkg_provider ===
# ============================================================================
FROM base AS common_pkg_provider

# Install core development tools and network packages
RUN apt-get update && apt-get install -y \
    vim \
    git \
    curl \
    wget \
    ca-certificates \
    build-essential \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    bzip2 \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda (ARM64 architecture)
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

RUN echo "Installing Miniconda for ARM64 architecture..." && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh && \
    ln -s $CONDA_DIR/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". $CONDA_DIR/etc/profile.d/conda.sh" >> /etc/bash.bashrc && \
    conda init bash && \
    conda clean -ya

# ============================================================================
# === Stage: verilator_provider ===
# ============================================================================
FROM common_pkg_provider AS verilator_provider

# Install additional Verilator-specific dependencies (only missing ones)
RUN apt-get update && apt-get install -y \
    perl \
    autoconf \
    flex \
    bison \
    ccache \
    libgoogle-perftools-dev \
    numactl \
    perl-doc \
    help2man \
    && rm -rf /var/lib/apt/lists/*

# Clone and build Verilator from source
RUN echo "Cloning Verilator from official GitHub repository..." && \
    git clone https://github.com/verilator/verilator.git /tmp/verilator && \
    cd /tmp/verilator && \
    echo "Checking out stable version..." && \
    git checkout stable && \
    echo "Configuring build..." && \
    autoconf && \
    ./configure --prefix=/opt/verilator && \
    echo "Building Verilator (this may take several minutes)..." && \
    make -j$(nproc) && \
    echo "Installing Verilator..." && \
    make install && \
    echo "Cleaning up build files..." && \
    rm -rf /tmp/verilator

# Add Verilator to PATH
ENV PATH="/opt/verilator/bin:$PATH"

# ============================================================================
# === Stage: systemc_provider ===
# ============================================================================
FROM verilator_provider AS systemc_provider

# Install SystemC-specific build dependencies
RUN apt-get update && apt-get install -y \
    automake \
    libtool \
    && rm -rf /var/lib/apt/lists/*

# Download and build SystemC 2.3.4 from source
RUN echo "Downloading SystemC 2.3.4 from Accellera..." && \
    cd /tmp && \
    wget https://github.com/accellera-official/systemc/archive/refs/tags/2.3.4.tar.gz -O systemc-2.3.4.tar.gz && \
    tar -xzf systemc-2.3.4.tar.gz && \
    cd systemc-2.3.4 && \
    echo "Configuring SystemC build..." && \
    autoreconf -i && \
    mkdir build && \
    cd build && \
    ../configure --prefix=/opt/systemc && \
    echo "Building SystemC (this may take several minutes)..." && \
    make -j$(nproc) && \
    echo "Installing SystemC..." && \
    make install && \
    echo "Cleaning up build files..." && \
    cd /tmp && \
    rm -rf systemc-2.3.4*

# Set SystemC environment variables
ENV SYSTEMC_HOME="/opt/systemc"
ENV SYSTEMC_CXXFLAGS="-I${SYSTEMC_HOME}/include -std=c++17"
ENV SYSTEMC_LDFLAGS="-L${SYSTEMC_HOME}/lib-linux64 -lsystemc"
ENV LD_LIBRARY_PATH="${SYSTEMC_HOME}/lib-linux64:${LD_LIBRARY_PATH}"

# ============================================================================
# === Final Stage ===
# ============================================================================
FROM systemc_provider AS final

# === Non-root User Settings ===
# build arguments for user management
ARG USER_UID=1001
ARG USER_GID=1001
ARG USERNAME=appuser

# === User Management ===
# build a non-root user with sudo privileges  
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    passwd -d "${USERNAME}" && \
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Install necessary packages
# Create application directory with proper ownership
RUN mkdir -p /app && \
    chown -R $USERNAME:$USERNAME /app

# Switch to non-root user
USER $USERNAME
# Set working directory
WORKDIR /app
# Default command
CMD ["/bin/bash"]