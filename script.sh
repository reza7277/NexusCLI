#!/bin/bash

# Function to display a banner
display_banner() {
    echo "
██████╗ ███████╗███████╗ █████╗     ███████╗██████╗ ███████╗███████╗
██╔══██╗██╔════╝╚══███╔╝██╔══██╗    ╚════██║╚════██╗╚════██║╚════██║
██████╔╝█████╗    ███╔╝ ███████║        ██╔╝ █████╔╝    ██╔╝    ██╔╝
██╔══██╗██╔══╝   ███╔╝  ██╔══██║       ██╔╝ ██╔═══╝    ██╔╝    ██╔╝ 
██║  ██║███████╗███████╗██║  ██║       ██║  ███████╗   ██║     ██║  
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝       ╚═╝  ╚══════╝   ╚═╝     ╚═╝  
"
    echo "Created by: Reza"
    echo "Join us: https://t.me/Web3loverz"
}

# Display the banner
display_banner

# Wait for 3 seconds before continuing
sleep 3

# 1. Install dependencies
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential pkg-config libssl-dev unzip

# 2. Install Cargo and Rust
echo "Installing Rust and Cargo..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# Ensure Rust environment is always loaded
echo 'source $HOME/.cargo/env' >> ~/.bashrc
source ~/.bashrc

# 3. Check versions
echo "Checking versions..."
rustc --version
cargo --version
rustup update

# 4. Install Protobuf
echo "Installing Protobuf..."
wget -q https://github.com/protocolbuffers/protobuf/releases/download/v21.12/protoc-21.12-linux-x86_64.zip
unzip -o protoc-21.12-linux-x86_64.zip -d $HOME/.local > /dev/null
rm protoc-21.12-linux-x86_64.zip

export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install Protobuf Codegen
cargo install --force protobuf-codegen

# 5. Add Rust target and components
rustup target add riscv32i-unknown-none-elf
rustup component add rust-src

# 6. Install Nexus CLI from official source
echo "Installing Nexus CLI from official source..."
curl https://cli.nexus.xyz/ | sh

# 7. Install Nexus
echo "Installing Nexus CLI..."
mkdir -p $HOME/.nexus
cd $HOME/.nexus

if [ -d "network-api" ]; then
    echo "Updating existing repository..."
    cd network-api
    git fetch --tags
    latest_tag=$(git rev-list --tags --max-count=1)
    git checkout "$latest_tag"
    git pull origin "$latest_tag"
else
    echo "Cloning Nexus repository..."
    git clone https://github.com/nexus-xyz/network-api
    cd network-api
    git fetch --tags
    git checkout $(git rev-list --tags --max-count=1)
fi

# 8. Build and run Nexus CLI
echo "Building Nexus CLI..."
cd clients/cli
cargo clean
cargo build --release

echo "Running Nexus CLI..."
cargo run --release start --beta

# Final installation of Nexus CLI
echo "Running final Nexus CLI installation..."
curl https://cli.nexus.xyz/ | sh
