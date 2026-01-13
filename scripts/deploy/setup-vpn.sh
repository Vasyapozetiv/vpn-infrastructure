#!/bin/bash
# setup-vpn.sh - VPN Server Setup Script
# Version: 1.0

set -e  # Stop on error

echo ""
echo "=========================================="
echo "🚀 VPN Server Setup Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo $0"
    fi
    log "Running as root: OK"
}

# Update system
update_system() {
    log "Updating system packages..."
    apt update -y || warning "apt update failed, trying to continue..."
    apt upgrade -y || warning "apt upgrade failed, trying to continue..."
    success "System updated"
}

<<<<<<< HEAD
# Install dependencies
install_deps() {
    log "Installing dependencies..."
    
    # Basic tools
    apt install -y \
        curl \
        wget \
        git \
        nano \
        htop \
        ufw \
        net-tools \
        openssl \
        cron \
        systemd \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https \
        || warning "Some packages failed to install"
    
    success "Dependencies installed"
}
=======
log "Install dependencies..."
sudo apt install -y curl wget git openssl ufw
>>>>>>> 446b9634d4fc654d4fce5193b10531f235128f80

# Download Hysteria
install_hysteria() {
    log "Downloading Hysteria..."
    
    # Get latest version
    HY_VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$HY_VERSION" ]; then
        HY_VERSION="v2.2.2"  # Fallback version
        warning "Could not fetch latest version, using $HY_VERSION"
    fi
    
    log "Latest version: $HY_VERSION"
    
    # Download
    wget -q "https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/hysteria-linux-amd64" -O /usr/local/bin/hysteria
    
    if [ ! -f /usr/local/bin/hysteria ]; then
        error "Failed to download Hysteria"
    fi
    
    chmod +x /usr/local/bin/hysteria
    success "Hysteria downloaded: $(/usr/local/bin/hysteria version 2>/dev/null || echo 'version check failed')"
}

# Create directories
create_dirs() {
    log "Creating directories..."
    
    mkdir -p /etc/hysteria
    mkdir -p /etc/hysteria/certs
    mkdir -p /var/log/hysteria
    
    chmod 700 /etc/hysteria
    chmod 755 /var/log/hysteria
    
    success "Directories created"
}

# Generate SSL certificate
generate_cert() {
    log "Generating SSL certificate..."
    
    cd /etc/hysteria/certs
    
    # Generate private key and certificate
    openssl ecparam -genkey -name prime256v1 -out server.key
    openssl req -new -x509 -days 365 -key server.key -out server.crt \
        -subj "/C=US/ST=California/L=San Francisco/O=MyVPN/CN=vpn.example.com"
    
    # Set permissions
    chmod 600 server.key
    chmod 644 server.crt
    
    if [ ! -f server.crt ] || [ ! -f server.key ]; then
        error "Failed to generate SSL certificate"
    fi
    
    success "SSL certificate generated"
}

# Create Hysteria config
create_config() {
    log "Creating Hysteria configuration..."
    
    # Generate random password
    PASSWORD=$(openssl rand -base64 32)
    
    # Get server IP
    SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org || hostname -I | awk '{print $1}')
    
    cat > /etc/hysteria/config.yaml << EOF
# Hysteria 2 Server Configuration
# Generated: $(date)

# Server settings
listen: :443
protocol: udp

# TLS settings
tls:
  cert: /etc/hysteria/certs/server.crt
  key: /etc/hysteria/certs/server.key
  sni: vpn.example.com
  alpn:
    - h3

# Authentication
auth:
  type: password
  password: "${PASSWORD}"

# Masquerade (traffic obfuscation)
masquerade:
  type: proxy
  proxy:
    url: https://www.google.com
    rewriteHost: true

# Bandwidth limits
bandwidth:
  up: 100 mbps
  down: 100 mbps

# QUIC settings
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024

# Access control
acl:
  inline:
    - direct(all)

# Logging
log:
  level: info
  format: text
  timestamp: true
EOF
    
    # Save password for later
    echo "$PASSWORD" > /etc/hysteria/password.txt
    chmod 600 /etc/hysteria/password.txt
    
    success "Configuration created"
}

# Create systemd service
create_service() {
    log "Creating systemd service..."
    
    cat > /etc/systemd/system/hysteria.service << EOF
[Unit]
Description=Hysteria 2 VPN Server
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/hysteria
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=infinity

# Security
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/etc/hysteria /var/log/hysteria

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    success "Systemd service created"
}

# Configure firewall
setup_firewall() {
    log "Configuring firewall..."
    
    # Disable UFW if it blocks everything
    ufw --force disable 2>/dev/null || true
    
    # Simple iptables rules
    iptables -F
    iptables -X
    iptables -Z
    
    # Default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Allow localhost
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow SSH
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Allow Hysteria ports
    iptables -A INPUT -p udp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # Allow ping
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    
    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    sysctl -p
    
    # NAT for VPN traffic
    iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -j MASQUERADE
    iptables -t nat -A POSTROUTING -s 172.16.0.0/12 -j MASQUERADE
    iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -j MASQUERADE
    
    success "Firewall configured"
}

# Start services
start_services() {
    log "Starting services..."
    
    systemctl enable hysteria
    systemctl start hysteria
    
    sleep 3
    
    # Check if running
    if systemctl is-active --quiet hysteria; then
        success "Hysteria service is running"
    else
        error "Failed to start Hysteria service"
    fi
}

# Show connection info
show_info() {
    log "Generating connection information..."
    
    PASSWORD=$(cat /etc/hysteria/password.txt 2>/dev/null || echo "NOT_FOUND")
    SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org || ip addr show | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
    
    echo ""
    echo "=========================================="
    echo "✅ VPN SETUP COMPLETE!"
    echo "=========================================="
    echo ""
    echo "📡 SERVER INFORMATION:"
    echo "   IP Address: $SERVER_IP"
    echo "   Port: 443 (UDP/TCP)"
    echo "   Protocol: Hysteria 2"
    echo ""
    echo "🔐 CREDENTIALS:"
    echo "   Password: $PASSWORD"
    echo "   SNI: vpn.example.com"
    echo ""
    echo "📱 MOBILE CONFIGURATION:"
    echo "   URL: hy2://$PASSWORD@$SERVER_IP:443?sni=vpn.example.com&insecure=1&alpn=h3"
    echo ""
    echo "💻 DESKTOP CONFIGURATION:"
    cat > /tmp/vpn-client.json << EOF
{
  "server": "$SERVER_IP:443",
  "auth": "$PASSWORD",
  "tls": {
    "sni": "vpn.example.com",
    "insecure": true,
    "alpn": ["h3"]
  },
  "socks5": {
    "listen": "127.0.0.1:1080"
  }
}
EOF
    echo "   Config file: /tmp/vpn-client.json"
    echo ""
    echo "🔧 MANAGEMENT COMMANDS:"
    echo "   Check status: systemctl status hysteria"
    echo "   View logs: journalctl -u hysteria -f"
    echo "   Restart: systemctl restart hysteria"
    echo ""
    echo "⚠️ IMPORTANT:"
    echo "   - Save the password above!"
    echo "   - Change 'vpn.example.com' to your domain if you have one"
    echo "   - Test connection from another device"
    echo ""
    echo "=========================================="
}

# Main execution flow
main() {
    echo "Starting VPN setup process..."
    
    # Step 1: Check privileges
    check_root
    
    # Step 2: Update system
    update_system
    
    # Step 3: Install dependencies
    install_deps
    
    # Step 4: Install Hysteria
    install_hysteria
    
    # Step 5: Create directories
    create_dirs
    
    # Step 6: Generate SSL
    generate_cert
    
    # Step 7: Create config
    create_config
    
    # Step 8: Create service
    create_service
    
    # Step 9: Setup firewall
    setup_firewall
    
    # Step 10: Start services
    start_services
    
    # Step 11: Show info
    show_info
    
    echo ""
    success "Setup completed successfully!"
    echo ""
}

# Run main function
main "$@"
