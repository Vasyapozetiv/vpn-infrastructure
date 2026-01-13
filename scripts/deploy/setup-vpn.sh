#!/bin/bash
# setup-vpn.sh - Simple VPN setup script

set -e  # Stop on error

echo "🚀 Starting VPN setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No color

# Log function
log () {
	echo -e "${GREEN}[ERROR] $1${NC}"
	exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Update system

log "Install dependencies..."
sudo apt install -y curl wget git openssl ufw

# Download Hysteria
Log "Downloading Hysteria..."
HY_VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep tag_name | cut -d'"' -f4)
wget "https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/hysteria-linux-amd64" -O /usr/local/bin/hysteria
chmod +x /usr/local/bin/hysteria

# Create dirs
log "Creating directories..."
mkdir -p /etc/hysteria/certs
mkdir -p /var/log/hysteria

# Generate SSL certificate
log "Generating SSL certificate..."
cd /etc/hysteria/certs
openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout server.key -out server.crt \
    -subj "/C=US/ST=CA/L=SF/O=MyVPN/CN=vpn.example.com" \
    -days 365
    
# Create config
log "Creating Hysteria config..."
cat > /etc/hysteria/config.yaml << 'EOF'
listen: :443

tls:
  cert: /etc/hysteria/certs/server.crt
  key: /etc/hysteria/certs/server.key
  sni: vpn.example.com
  alpn: [h3]

auth:
  type: password
  password: "$(openssl rand -base64 32)"

masquerade:
  type: proxy
  proxy:
    url: https://www.google.com
    rewriteHost: true

bandwidth:
  up: 100 mbps
  down: 100 mbps

acl:
  inline:
    - direct(all)

log:
  level: info
  format: text
EOF

# Create systemd service
log "Creating systemd service..."
cat > /etc/systemd/system/hysteria.service << 'EOF'
[Unit]
Description=Hysteria VPN Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Configure firewall
log "Configuring firewall..."
ufw allow 22/tcp
ufw allow 443/udp
ufw allow 443/tcp
ufw --force enable

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Start service
log "Starting Hysteria..."
systemctl daemon-reload
systemctl enable hysteria
systemctl start hysteria

# Check status
sleep 2
log "Checking service status..."
systemctl status hysteria --no-pager

# Get connection info
PASSWORD=$(grep -o 'password:.*' /etc/hysteria/config.yaml | cut -d'"' -f2)
IP=$(curl -s ifconfig.me)

log "✅ VPN setup complete!"
echo ""
echo "🔗 Connection info:"
echo "   Server: $IP:443"
echo "   Password: $PASSWORD"
echo "   SNI: vpn.example.com"
echo ""
echo "📱 For mobile: hy2://$PASSWORD@$IP:443?sni=vpn.example.com&insecure=1&alpn=h3"
