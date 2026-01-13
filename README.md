# 🚀 VPN Infrastructure Project

A professional VPN setup with DevOps practices.

## Features
- ✅ VPN Server (Hysteria 2)
- ✅ Telegram Bot for management
- ✅ Automated deployment scripts
- ✅ Monitoring and logging

## Quick Start

### 1. Server Setup
```bash
# On your VPS
git clone https://github.com/yourusername/vpn-infrastructure.git
cd vpn-infrastructure

# Run setup script
sudo bash scripts/deploy/setup-vpn.sh
```

### 2. Telegram Bot Setup
```bash
# Install dependencies
pip install -r src/telegram-bot/requirements.txt

# Set environment variables
export BOT_TOKEN="your_bot_token"
export ADMIN_ID="your_telegram_id"

# Run bot
python src/telegram-bot/bot.py
```
### 3. Connect to VPN
Use the credentials printed at the end of setup.


### Project Structure
```text
vpn-project/
├── scripts/deploy/       # Deployment scripts
├── src/telegram-bot/     # Telegram bot
├── docs/                 # Documentation
└── README.md             # This file
```

### Useful Commands
```bash
# Check VPN status
systemctl status hysteria

# View logs
journalctl -u hysteria -f

# Restart VPN
systemctl restart hysteria
```

### License
MIT
