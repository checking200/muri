#!/bin/bash
# setup_and_run.sh - Fully automated setup for VibeAccount (with Yarn repo fix)
# Usage: chmod +x setup_and_run.sh && ./setup_and_run.sh

set -e  # Exit on error

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   VibeAccount Automation Setup Script   ${NC}"
echo -e "${GREEN}========================================${NC}"

status() { echo -e "${YELLOW}[*] $1${NC}"; }
success() { echo -e "${GREEN}[✔] $1${NC}"; }
error() { echo -e "${RED}[✘] $1${NC}"; exit 1; }

# Do not run as root (sudo will be used internally)
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Run as a normal user with sudo privileges."
fi

# ----- Yarn repository GPG key fix -----
status "Checking for Yarn repository issues..."
YARN_KEY="62D54FD4003F6525"

if apt-key list 2>/dev/null | grep -q "$YARN_KEY"; then
    success "Yarn GPG key already present."
else
    status "Attempting to add missing Yarn GPG key from multiple servers..."
    KEY_ADDED=false
    for server in keyserver.ubuntu.com pgp.mit.edu keys.openpgp.org; do
        if sudo apt-key adv --keyserver "$server" --recv-keys "$YARN_KEY" >/dev/null 2>&1; then
            success "Key added successfully from $server"
            KEY_ADDED=true
            break
        fi
    done

    if ! $KEY_ADDED; then
        status "Key addition failed. Disabling Yarn repository to continue..."
        # Find and comment out any line containing dl.yarnpkg.com in apt sources
        sudo find /etc/apt/ -type f -name '*.list' -exec grep -l 'dl.yarnpkg.com' {} \; | while read file; do
            echo "Disabling yarn repo in $file"
            sudo sed -i 's/^deb /#deb /' "$file"
        done
    fi
fi

# Update package list (should now succeed)
status "Updating package list..."
sudo apt-get update -qq || error "Failed to update package list. Please check your repositories manually."

# ----- Install required system packages -----
status "Installing essential tools (wget, curl, unzip, software-properties-common)..."
sudo apt-get install -y wget curl unzip software-properties-common gnupg2 > /dev/null

# ----- Python3 & pip -----
if ! command -v python3 &> /dev/null; then
    status "Installing Python3..."
    sudo apt-get install -y python3 python3-pip > /dev/null
else
    success "Python3 already installed"
fi

if ! command -v pip3 &> /dev/null; then
    status "Installing pip3..."
    sudo apt-get install -y python3-pip > /dev/null
fi

# ----- Google Chrome -----
if ! command -v google-chrome &> /dev/null; then
    status "Installing Google Chrome..."
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
    sudo apt-get update -qq
    sudo apt-get install -y google-chrome-stable > /dev/null
    success "Google Chrome installed"
else
    success "Google Chrome already installed"
fi

# ----- Python dependencies -----
status "Installing Python packages (selenium, undetected-chromedriver, requests)..."
pip3 install --quiet --upgrade pip
pip3 install --quiet selenium undetected-chromedriver requests pyotp 2captcha-python \
    || error "Failed to install Python packages"
success "Python packages installed"

# ----- Create the Python automation script -----
status "Creating Python script (vibe_automation.py)..."
cat > vibe_automation.py << 'EOF'
# PASTE THE FULL PYTHON CODE FROM THE PREVIOUS ANSWER HERE
# (The 200+ line script we provided earlier – keep it unchanged)
EOF
success "Python script created"

# ----- Prompt for credentials (if not already set) -----
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

# ----- Run the automation -----
status "Starting automation..."
python3 vibe_automation.py

EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    success "Automation completed successfully!"
else
    error "Automation failed. Check logs above."
fi

exit $EXIT_CODE
