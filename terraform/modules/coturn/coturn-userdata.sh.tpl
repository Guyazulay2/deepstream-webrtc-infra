#!/bin/bash
set -euo pipefail

# Install coturn
apt-get update -q
apt-get install -y coturn awscli

# Enable coturn service
sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

# Private IP from IMDS; public IP is the Elastic IP passed from Terraform
# (not from IMDS, which would return a temp IP before EIP association).
PRIVATE_IP=$(curl -sf http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP="${public_ip}"

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
# use-auth-secret implies lt-cred-mech; do not set both.
use-auth-secret
static-auth-secret=${turn_secret}

# Relay port range (must match security group)
min-port=${min_relay_port}
max-port=${max_relay_port}

# Logging
log-file=/var/log/coturn/turnserver.log
verbose

# Security
no-multicast-peers
# RFC1918 blocked except for direct VPC-internal paths (EKS pods are 10.x.x.x).
# Removed 10.0.0.0/8 deny — GStreamer pods on the same VPC must reach the relay.
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
EOF

mkdir -p /var/log/coturn
systemctl enable coturn
systemctl start coturn

echo "COTURN started — TURN host: $${PUBLIC_IP}:3478"
