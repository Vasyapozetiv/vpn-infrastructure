# 📖 Installation Guide

Complete step-by-step guide to deploy VPN infrastructure.

## Prerequisites

### 1. VPS Requirements
- **OS**: Ubuntu 22.04 or 24.04
- **Resources**: 1 vCPU, 1GB RAM, 20GB SSD minimum
- **Network**: Public IP, port 443 UDP/TCP open

### 2. Local Machine Requirements
- **Terminal**: SSH client (Linux/Mac: built-in, Windows: PuTTY or WSL)
- **Git**: Version control system
- **Telegram**: Account for bot management

### 3. Accounts Needed
- [GitHub](https://github.com) account
- [Telegram](https://telegram.org) account

---

## Step 1: Server Initial Setup

### 1.1 Connect to VPS
```bash
# Connect via SSH
ssh root@your_server_ip
# Enter password provided by VPS provider
```

### 1.2 Basic Security Setup
```bash
# Create new user
adduser vpnadmin
usermod -aG vnpadmin

# Set up SSH keys (from local machine)
# On your LOCAL computer:
ssh-keygen -t ed25519  # Press Enter for all defaults
ssh-copy-id vpnadmin@your_server_ip

# Now connect without password
ssh vpnadmin@your_server_ip
```

### 1.3 Install Basic Tools
```bash
 Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
  curl \
  wget \
  git \
  nano \
  htop \
  ufw \
  net-tools \
  python3 \
  python3-pip \
  python3-venv
```

## Step 2: Clone and Setup Project

### 2.1 Clone Repository
```bash
# Clone from GitHub
git clone https://github.com/vasyapozetiv/vpn-infrastructure.git
cd vpn-infrastructure

# Or if starting fresh
mkdir vpn-project && cd vpn-project
git init
```

### 2.2 Project Structure
```bash
# Create project structure
mkdir -p {scripts,src,docs,config}

# Create deployment script
touch scripts/setup-vpn.sh
chmod +x scripts/setup-vpn.sh
```

## Step 3: Deploy VPN Server

### 3.1 Run Deployment Script
```bash
# Make script executable
chmod +x scripts/deploy/setup-vpn.sh

# Run as root
sudo ./scripts/deploy/setup-vpn.sh
```

### 3.2 Verify installation
```bash
# Check Service status
systemctl status hysteria

# Check if port is listening
sudo ss -tulpn | grep :443

# Test connectivity (from another machine)
# Replace with your server IP
curl --max-time 5 https://your_server_ip:443
```

### 3.3 Get Connection Details
After installation, the script will display:

- Server IP address
- VPN password
- Connection URL for mobile devices

Save this information!

## Step 4: Setup Telegram Bot

### 4.1 Create Telegram Bot
1. Open Telegram
2. Search for `@botFather`
3. Send `/newbot`
4. Follow instructions to create bot
5. Save the bot token (format: '1234567890:ABCdefGHIjklMnoPQRstuVWXYz')

### 4.2 Get Your telegram ID
1. Open Telegram
2. Search for `@userinfobot`
3. Send `/start`
4. Copy your ID number

### 4.3 Configure and Run Bot
```bash
# Install Python dependencies
cd src/telegram-bot
pip3 install -r requirements.txt

# Set environment variables
export BOT_TOKEN="your_bot_token_here"
export ADMIN_ID="your_telegram_id_here"

# Run the bot
python3 bot.py
```

### 4.4 Test Bot Commands
In Telegram with your bot:

- `/start` \- Show main menu
- Use buttons to get VPN config, check status, etc.

## Step 5: Configure Automatic Startup

### 5.1 Create Systemd Service for Bot
```bash
# Create service file
sudo nano /etc/systemd/system/vpn-bot.service
```
Add this content:
```ini
[Unit]
Description=VPN Telegram Bot
After=network.target hysteria.service
Wants=network-online.target

[Service]
Type=simple
User=vpnadmin
WorkingDirectory=/home/vpnadmin/vpn-project/src/telegram-bot
Environment="BOT_TOKEN=your_bot_token"
Environment="ADMIN_ID=your_telegram_id"
ExecStart=/usr/bin/python3 bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 5.2 Enable and Start
```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable auto-start
sudo systemctl enable vpn-bot

# Start service
sudo systemctl start vpn-bot

# Check status
sudo systemctl status vpn-bot
```

## Step 6: Testing and Validation

### 6.1 Test VPN Connection
**On Android/iOS:**
1. Install NekoBox or Hysteria client
2. Use the QR code or connection URL from setup
3. Connect and visit https://ipinfo.io to verify

**On Desktop:**
```bash
# Using curl with SOCKS5 proxy
curl --socks5 127.0.0.1:1080 https://api.ipify.org
```

### 6.2 Monitor Logs
```bash
# VPN logs
sudo journalctl -u hysteria -f

# Bot logs
sudo journalctl -u vpn-bot -f

# Combined status check
./scripts/monitoring/health-check.sh
```

## Step 7: Backup Configuration

### 7.1 Backup Important Files
```bash
# Create backup directory
mkdir ~/vpn-backups

# Backup Hysteria config
sudo cp /etc/hysteria/config.yaml ~/vpn-backups/

# Backup SSL certificates
sudo cp -r /etc/hysteria/certs ~/vpn-backups/

# Backup systemd services
sudo cp /etc/systemd/system/hysteria.service ~/vpn-backups/
sudo cp /etc/systemd/system/vpn-bot.service ~/vpn-backups/
```

### 7.2 Create Backup Script
```bash
nano scripts/backup/backup-vpn.sh
```

```bash
#!/bin/bash
# Backup script for VPN configuration

BACKUP_DIR="/home/vpnadmin/vpn-backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

echo "📦 Creating backup in $BACKUP_DIR"

# Backup configs
sudo cp /etc/hysteria/config.yaml $BACKUP_DIR/
sudo cp -r /etc/hysteria/certs $BACKUP_DIR/
sudo cp /etc/systemd/system/hysteria.service $BACKUP_DIR/
sudo cp /etc/systemd/system/vpn-bot.service $BACKUP_DIR/

# Backup project files
cp -r ~/vpn-project $BACKUP_DIR/

echo "✅ Backup complete"
echo "Size: $(du -sh $BACKUP_DIR | cut -f1)"
```

## Step 8: Maintenance

### 8.1 Update VPN Software

```bash
# Run update script
sudo ./scripts/deploy/update-vpn.sh
```
### 8.2 Renew SSL Certificate

Certificates are valid for 365 days. To renew:
```bash
cd /etc/hysteria/certs
sudo openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout server.key -out server.crt \
    -subj "/C=US/ST=CA/L=SF/O=MyVPN/CN=vpn.example.com" \
    -days 365
sudo systemctl restart hysteria
```

### 8.3 Change VPN Password
```bash
# Generate new password
NEW_PASS=$(openssl rand -base64 32)

# Update config
sudo sed -i "s/password:.*/password: \"$NEW_PASS\"/" /etc/hysteria/config.yaml

# Restart service
sudo systemctl restart hysteria

echo "New password: $NEW_PASS"
```


# Troubleshooting

## Common Issues

### 1. VPN Not Connecting
```bash
# Check firewall
sudo ufw status

# Check service
systemctl status hysteria

# Check logs
sudo journalctl -u hysteria -n 50
```

### 2. Bot Not Starting
```bash
# Check token and ID
echo "BOT_TOKEN: $BOT_TOKEN"
echo "ADMIN_ID: $ADMIN_ID"

# Check Python dependencies
pip3 list | grep telegram

# Check logs
sudo journalctl -u vpn-bot -n 50
```

### 3. Port 443 Already in Use
```bash
# Check what's using port 443
sudo lsof -i :443
sudo ss -tulpn | grep :443
```

## Useful Commands
```bash
# Restart everything
sudo systemctl restart hysteria vpn-bot

# View real-time logs
sudo journalctl -fu hysteria
sudo journalctl -fu vpn-bot

# Test connectivity
curl -v --max-time 5 https://your_server_ip:443
```


# Security Recommendations

1. **Regular Updates:** Keep system and software updated
2. **Firewall:** Only open necessary ports (22, 443)
3. **Backups:** Regular backups of configuration
4. **Monitoring:** Use heath check scripts
5. **Access Control:** Limit SSH access to specific IPs


# Support

If you encounter issues:

1. Check the Troubleshooting section
2. Review logs: `sudo journalctl -u hysteria -n 100`
3. Check GitHub issues for similar problems
4. Create a new issue with detailed error logs



# License

This project is licensed under the MIT License - see the LICENSE file for details.
