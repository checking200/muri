#!/bin/bash
# setup_and_run.sh - One‑click installer with Yarn repository fix for GitHub Codespaces
# Usage: chmod +x setup_and_run.sh && ./setup_and_run.sh

set -e  # Exit on any error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   VibeAccount Automation Setup Script   ${NC}"
echo -e "${GREEN}========================================${NC}"

# Function to print status
status() { echo -e "${YELLOW}[*] $1${NC}"; }
success() { echo -e "${GREEN}[✔] $1${NC}"; }
error() { echo -e "${RED}[✘] $1${NC}"; exit 1; }

# Do not run as root (the script will use sudo internally)
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Run as a normal user with sudo privileges."
fi

# --- Fix for Yarn repository missing GPG key (common in Codespaces) ---
status "Checking for Yarn repository issues..."
YARN_KEY="62D54FD4003F6525"
if apt-key list | grep -q "$YARN_KEY"; then
    success "Yarn GPG key already present."
else
    status "Adding missing Yarn GPG key..."
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "$YARN_KEY" || {
        # If key addition fails, disable the Yarn repository temporarily
        status "Key addition failed. Disabling Yarn repository to continue..."
        sudo sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/yarn.list 2>/dev/null || true
    }
fi

# Update package list (now with fixed key or disabled repo)
status "Updating package list..."
sudo apt-get update -qq || error "Failed to update package list. Please check your repositories manually."

# Install essential tools
status "Installing essential tools (wget, curl, unzip, software-properties-common)..."
sudo apt-get install -y wget curl unzip software-properties-common gnupg2 > /dev/null || error "Failed to install essential tools"

# Install Python3 and pip3 if missing
status "Checking Python3 installation..."
if ! command -v python3 &> /dev/null; then
    status "Python3 not found. Installing..."
    sudo apt-get install -y python3 python3-pip > /dev/null || error "Failed to install Python3"
else
    success "Python3 already installed"
fi

if ! command -v pip3 &> /dev/null; then
    status "pip3 not found. Installing..."
    sudo apt-get install -y python3-pip > /dev/null || error "Failed to install pip3"
else
    success "pip3 already installed"
fi

# Install Google Chrome
status "Checking Google Chrome installation..."
if ! command -v google-chrome &> /dev/null; then
    status "Google Chrome not found. Installing..."
    # Add Google Chrome repository
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - || error "Failed to add Chrome signing key"
    sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
    sudo apt-get update -qq
    sudo apt-get install -y google-chrome-stable > /dev/null || error "Failed to install Google Chrome"
    success "Google Chrome installed"
else
    success "Google Chrome already installed"
fi

# Install Python dependencies
status "Installing Python packages (selenium, undetected-chromedriver, requests)..."
pip3 install --quiet --upgrade pip
pip3 install --quiet selenium undetected-chromedriver requests pyotp 2captcha-python \
    || error "Failed to install Python packages"
success "Python packages installed"

# Create the Python script (same as before, omitted for brevity – see previous answer)
# ... (paste the full Python code here or keep it as a heredoc)

# [Insert the full Python code from the previous answer between the cat > vibe_automation.py << 'EOF' and EOF]

# Prompt for environment variables if not already set
if [[ -z "$VIBE_EMAIL" ]]; then
    read -p "Enter your VibeAccount email: " VIBE_EMAIL
    export VIBE_EMAIL
fi
if [[ -z "$VIBE_PASSWORD" ]]; then
    read -s -p "Enter your VibeAccount password: " VIBE_PASSWORD
    echo
    export VIBE_PASSWORD
fi
if [[ -z "$VIBE_NEW_PHONE" ]]; then
    read -p "Enter the new phone number (e.g., 1234567890): " VIBE_NEW_PHONE
    export VIBE_NEW_PHONE
fi
if [[ -z "$VIBE_PROXY" ]]; then
    read -p "Enter proxy (optional, format http://user:pass@ip:port): " VIBE_PROXY
    export VIBE_PROXY
fi

# Run the Python script
status "Starting automation..."
python3 vibe_automation.py

EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    success "Automation completed successfully!"
else
    error "Automation failed. Check logs above."
fi

exit $EXIT_CODE
