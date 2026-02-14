#!/bin/bash
# setup_and_run.sh - VibeAccount automation (no Yarn repo)
# Usage: chmod +x setup_and_run.sh && ./setup_and_run.sh

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   VibeAccount Automation (Clean Install) ${NC}"
echo -e "${GREEN}========================================${NC}"

status() { echo -e "${YELLOW}[*] $1${NC}"; }
success() { echo -e "${GREEN}[✔] $1${NC}"; }
error() { echo -e "${RED}[✘] $1${NC}"; exit 1; }

# --- Step 1: Remove the problematic Yarn repository ---
status "Removing Yarn repository (we don't need it)..."
sudo rm -f /etc/apt/sources.list.d/yarn.list || true
sudo apt-get update -qq || error "apt-get update failed even after removing yarn repo. Check network."

# --- Step 2: Install system dependencies (no Chrome repo yet) ---
status "Installing basic tools..."
sudo apt-get install -y wget curl unzip software-properties-common gnupg2 > /dev/null

# --- Step 3: Install Python3 and pip if missing ---
if ! command -v python3 &> /dev/null; then
    sudo apt-get install -y python3 python3-pip > /dev/null
fi

# --- Step 4: Install Google Chrome directly (without repository) ---
if ! command -v google-chrome &> /dev/null; then
    status "Downloading and installing Google Chrome (direct .deb)..."
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo dpkg -i google-chrome-stable_current_amd64.deb > /dev/null 2>&1 || sudo apt-get install -f -y > /dev/null
    rm google-chrome-stable_current_amd64.deb
    success "Google Chrome installed"
else
    success "Google Chrome already installed"
fi

# --- Step 5: Python packages ---
status "Installing Python libraries..."
pip3 install --quiet --upgrade pip
pip3 install --quiet selenium undetected-chromedriver requests pyotp 2captcha-python \
    || error "Python package installation failed"

# --- Step 6: Create Python script (same as before, but we'll include it here) ---
status "Creating vibe_automation.py..."
cat > vibe_automation.py << 'EOF'
# PASTE THE FULL PYTHON CODE FROM PREVIOUS ANSWER HERE
# (The 200+ line script with class VibeAccountAutomator)
EOF

# --- Step 7: Prompt for credentials ---
if [[ -z "$VIBE_EMAIL" ]]; then read -p "Email: " VIBE_EMAIL; export VIBE_EMAIL; fi
if [[ -z "$VIBE_PASSWORD" ]]; then read -s -p "Password: " VIBE_PASSWORD; echo; export VIBE_PASSWORD; fi
if [[ -z "$VIBE_NEW_PHONE" ]]; then read -p "New phone number: " VIBE_NEW_PHONE; export VIBE_NEW_PHONE; fi
if [[ -z "$VIBE_PROXY" ]]; then read -p "Proxy (optional): " VIBE_PROXY; export VIBE_PROXY; fi

# --- Step 8: Run ---
status "Executing automation..."
python3 vibe_automation.py
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    success "Phone number updated successfully!"
else
    error "Automation failed. Check logs."
fi
