#!/bin/bash
# setup_and_run.sh - One‑click installer and runner for VibeAccount phone update automation
# Usage: chmod +x setup_and_run.sh && ./setup_and_run.sh

set -e  # Exit on any error

# Color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   VibeAccount Automation Setup Script   ${NC}"
echo -e "${GREEN}========================================${NC}"

# Function to print status
status() {
    echo -e "${YELLOW}[*] $1${NC}"
}

success() {
    echo -e "${GREEN}[✔] $1${NC}"
}

error() {
    echo -e "${RED}[✘] $1${NC}"
    exit 1
}

# Check if running as root (not recommended)
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Run as a normal user with sudo privileges."
fi

# Update package list
status "Updating package list..."
sudo apt-get update -qq || error "Failed to update package list"

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

# Create the Python script
status "Creating Python automation script (vibe_automation.py)..."
cat > vibe_automation.py << 'EOF'
#!/usr/bin/env python3
"""
Advanced VibeAccount Phone Number Updater
Uses hybrid API + stealth browser approach with anti‑detection.
"""

import os
import sys
import pickle
import time
import random
import logging
from typing import Optional
import requests
import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class VibeAccountAutomator:
    def __init__(self, email, password, new_phone, proxy=None):
        self.email = email
        self.password = password
        self.new_phone = new_phone
        self.proxy = proxy
        self.session = requests.Session()
        self.driver = None
        self.cookie_file = "cookies.pkl"

    def _setup_requests_session(self):
        if self.proxy:
            self.session.proxies.update({'http': self.proxy, 'https': self.proxy})
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Origin': 'https://www.vibeaccount.com',
            'Referer': 'https://www.vibeaccount.com/',
        })

    def _login_via_api(self) -> bool:
        login_url = "https://www.vibeaccount.com/api/auth/login"
        payload = {"email": self.email, "password": self.password}
        try:
            resp = self.session.post(login_url, json=payload, timeout=10)
            if resp.status_code == 200:
                logging.info("API login successful")
                with open(self.cookie_file, "wb") as f:
                    pickle.dump(self.session.cookies, f)
                return True
            elif resp.status_code == 401:
                logging.error("Invalid credentials")
                return False
            elif resp.status_code == 403 and "captcha" in resp.text:
                logging.warning("CAPTCHA required, falling back to browser")
                return False
            else:
                logging.warning(f"API login unexpected response: {resp.status_code}")
                return False
        except Exception as e:
            logging.error(f"API login exception: {e}")
            return False

    def _login_via_browser(self) -> bool:
        options = uc.ChromeOptions()
        if self.proxy:
            options.add_argument(f'--proxy-server={self.proxy}')
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_argument("--start-maximized")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        self.driver = uc.Chrome(options=options)
        self.driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")

        wait = WebDriverWait(self.driver, 30)

        try:
            self.driver.get("https://www.vibeaccount.com/login")
            time.sleep(random.uniform(2,4))

            email_field = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "input[type='email']")))
            for char in self.email:
                email_field.send_keys(char)
                time.sleep(random.uniform(0.05, 0.15))

            password_field = self.driver.find_element(By.CSS_SELECTOR, "input[type='password']")
            for char in self.password:
                password_field.send_keys(char)
                time.sleep(random.uniform(0.05, 0.15))

            if self._is_captcha_present():
                self._solve_captcha()

            login_button = self.driver.find_element(By.XPATH, "//button[@type='submit']")
            login_button.click()

            wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, ".dashboard")))
            logging.info("Browser login successful")

            with open(self.cookie_file, "wb") as f:
                pickle.dump(self.driver.get_cookies(), f)
            return True

        except TimeoutException:
            logging.error("Browser login timeout")
            self.driver.save_screenshot("login_timeout.png")
            return False
        except Exception as e:
            logging.error(f"Browser login exception: {e}")
            return False

    def _is_captcha_present(self):
        try:
            self.driver.find_element(By.CSS_SELECTOR, "iframe[src*='recaptcha'], .g-recaptcha, .captcha-image")
            return True
        except:
            return False

    def _solve_captcha(self):
        # Placeholder – integrate 2Captcha or Anti-Captcha if needed
        logging.warning("CAPTCHA detected but solver not implemented. Please solve manually.")
        input("Press Enter after solving the CAPTCHA manually...")

    def _load_cookies(self):
        try:
            with open(self.cookie_file, "rb") as f:
                cookies = pickle.load(f)
                if isinstance(cookies, requests.cookies.RequestsCookieJar):
                    self.session.cookies.update(cookies)
                elif isinstance(cookies, list):
                    if self.driver:
                        for cookie in cookies:
                            self.driver.add_cookie(cookie)
                logging.info("Cookies loaded")
                return True
        except FileNotFoundError:
            logging.warning("No cookie file found")
            return False

    def _update_phone_via_api(self) -> bool:
        update_url = "https://www.vibeaccount.com/api/user/phone"
        payload = {"phone": self.new_phone}
        try:
            resp = self.session.put(update_url, json=payload, timeout=10)
            if resp.status_code == 200:
                logging.info("Phone updated via API")
                return True
            else:
                logging.warning(f"API update failed: {resp.status_code} - {resp.text}")
                return False
        except Exception as e:
            logging.error(f"API update exception: {e}")
            return False

    def _update_phone_via_browser(self) -> bool:
        if not self.driver:
            logging.error("Browser not initialized")
            return False

        wait = WebDriverWait(self.driver, 30)
        try:
            self.driver.get("https://www.vibeaccount.com/settings")
            time.sleep(random.uniform(2,3))

            phone_field = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "input[name='phone']")))
            phone_field.clear()
            for char in self.new_phone:
                phone_field.send_keys(char)
                time.sleep(random.uniform(0.05, 0.15))

            save_btn = self.driver.find_element(By.XPATH, "//button[contains(text(), 'Save Changes')]")
            save_btn.click()

            wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, ".alert-success")))
            logging.info("Phone updated via browser")
            return True
        except Exception as e:
            logging.error(f"Browser update failed: {e}")
            self.driver.save_screenshot("update_failed.png")
            return False

    def run(self):
        self._setup_requests_session()

        if not self._login_via_api():
            logging.info("Falling back to browser login")
            if not self._login_via_browser():
                logging.error("Both API and browser login failed. Exiting.")
                return False

        if not self._update_phone_via_api():
            logging.info("API update failed, trying browser update")
            if not self.driver:
                self._login_via_browser()
            if self.driver:
                success = self._update_phone_via_browser()
            else:
                success = False

            if not success:
                logging.error("All update methods failed")
                return False

        logging.info("Phone number updated successfully!")
        return True

    def cleanup(self):
        if self.driver:
            self.driver.quit()

if __name__ == "__main__":
    email = os.environ.get("VIBE_EMAIL")
    password = os.environ.get("VIBE_PASSWORD")
    new_phone = os.environ.get("VIBE_NEW_PHONE")
    proxy = os.environ.get("VIBE_PROXY")

    if not email or not password or not new_phone:
        print("ERROR: Please set VIBE_EMAIL, VIBE_PASSWORD, and VIBE_NEW_PHONE environment variables.")
        sys.exit(1)

    automator = VibeAccountAutomator(email, password, new_phone, proxy)
    try:
        success = automator.run()
        if not success:
            sys.exit(1)
    finally:
        automator.cleanup()
EOF

success "Python script created: vibe_automation.py"

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

# Capture exit code
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    success "Automation completed successfully!"
else
    error "Automation failed. Check logs above."
fi

exit $EXIT_CODE
