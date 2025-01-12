#!/bin/bash

# Script to install PyTorch and torchvision with ROCm support
# Automatically builds PyTorch from source if no prebuilt wheel is available

# Variables
LOGFILE="$HOME/pytorch_rocm_install.log"
VENV_DIR="$HOME/deepseek-env"
PYTHON_VERSION=$(python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')")
TORCHVISION_VERSION="0.18.0"
ROCM_VERSION="6.3"
TORCHVISION_WHEEL="torchvision-${TORCHVISION_VERSION}+rocm${ROCM_VERSION}-${PYTHON_VERSION}-${PYTHON_VERSION}-linux_x86_64.whl"
TORCHVISION_URL="https://example.com/path/to/${TORCHVISION_WHEEL}"  # Replace with actual URL

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Function to create a virtual environment
create_venv() {
    log "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
        log "Error: Failed to create virtual environment."
        exit 1
    fi
    log "Virtual environment created at $VENV_DIR."
}

# Function to install PyTorch with ROCm support
install_pytorch() {
    log "Installing PyTorch with ROCm support..."
    "$VENV_DIR/bin/pip" install torch --index-url https://download.pytorch.org/whl/rocm${ROCM_VERSION}
    if [ $? -ne 0 ]; then
        log "Failed to install PyTorch from prebuilt wheel. Building PyTorch from source..."
        build_pytorch_from_source
    else
        log "PyTorch installed successfully."
    fi
}

# Function to build PyTorch from source
build_pytorch_from_source() {
    log "Building PyTorch from source..."
    sudo apt install -y git cmake ninja-build libopenblas-dev libnuma-dev
    git clone --recursive https://github.com/pytorch/pytorch.git
    cd pytorch
    git submodule sync
    git submodule update --init --recursive

    # Set ROCm architecture for RX 580 (Polaris)
    export PYTORCH_ROCM_ARCH="gfx803"

    # Build PyTorch with ROCm support
    python3 tools/amd_build/build_amd.py
    USE_ROCM=1 USE_NINJA=1 python3 setup.py install
    if [ $? -ne 0 ]; then
        log "Error: Failed to build PyTorch from source."
        exit 1
    fi
    log "PyTorch built and installed successfully."
}

# Function to download and install torchvision wheel
install_torchvision_wheel() {
    log "Downloading torchvision wheel..."
    wget "$TORCHVISION_URL" -O "$TORCHVISION_WHEEL"
    if [ $? -ne 0 ]; then
        log "Error: Failed to download torchvision wheel."
        return 1
    fi
    log "Torchvision wheel downloaded successfully."

    log "Installing torchvision..."
    "$VENV_DIR/bin/pip" install "$TORCHVISION_WHEEL"
    if [ $? -ne 0 ]; then
        log "Error: Failed to install torchvision."
        return 1
    fi
    log "torchvision installed successfully."
    return 0
}

# Function to build torchvision from source
build_torchvision_from_source() {
    log "Building torchvision from source..."
    sudo apt install -y libjpeg-dev libopenblas-dev libnuma-dev git
    git clone https://github.com/pytorch/vision.git
    cd vision
    git checkout "v${TORCHVISION_VERSION}"
    "$VENV_DIR/bin/python3" setup.py install
    if [ $? -ne 0 ]; then
        log "Error: Failed to build torchvision from source."
        return 1
    fi
    log "torchvision built and installed successfully."
    return 0
}

# Function to verify installation
verify_installation() {
    log "Verifying PyTorch and torchvision installation..."
    "$VENV_DIR/bin/python3" -c "import torch; import torchvision; print(f'PyTorch version: {torch.__version__}'); print(f'torchvision version: {torchvision.__version__}'); print(f'ROCm available: {torch.cuda.is_available()}')" | tee -a "$LOGFILE"
    if [ $? -ne 0 ]; then
        log "Error: PyTorch or torchvision is not working correctly."
        exit 1
    fi
}

# Main script logic
log "Starting PyTorch and torchvision installation with ROCm support..."

# Step 1: Create a virtual environment
create_venv

# Step 2: Install PyTorch
install_pytorch

# Step 3: Install torchvision (try wheel first, then build from source)
if ! install_torchvision_wheel; then
    log "Falling back to building torchvision from source..."
    if ! build_torchvision_from_source; then
        log "Error: Failed to install torchvision."
        exit 1
    fi
fi

# Step 4: Verify installation
verify_installation

log "Installation complete. PyTorch and torchvision are installed with ROCm support in the virtual environment at $VENV_DIR."
log "Activate the virtual environment using: source $VENV_DIR/bin/activate"
