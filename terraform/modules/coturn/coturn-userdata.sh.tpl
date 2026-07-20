#!/bin/bash
set -euo pipefail

# Install coturn
apt-get update -q
apt-get install -y coturn awscli

# Enable coturn service
sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

# Detect private IP
PRIVATE_IP=$(curl -sf http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4)

# Write coturn config
cat > /etc/turnserver.conf <<EOF
# Network
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
relay-ip=$${PRIVATE_IP}
external-ip=$${PUBLIC_IP}/$${PRIVATE_IP}

# Realm
realm=${realm}

# REST API auth (HMAC-SHA1 time-limited credentials)
# Never store actual user passwords — backend generates credentials on the fly.
use-auth-secret
static-auth-secret=${turn_secret}
lt-cred-mech

# Relay port range (must match security group)
min-port=${min_relay_port}
max-port=${max_relay_port}

# Logging
log-file=/var/log/coturn/turnserver.log
verbose

# Security
no-multicast-peers
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
EOF

mkdir -p /var/log/coturn
systemctl enable coturn
systemctl start coturn

echo "COTURN started — TURN host: $${PUBLIC_IP}:3478"
