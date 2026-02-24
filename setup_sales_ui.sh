#!/bin/bash

set -e

echo "Updating system..."
sudo apt update -y

echo "Installing dependencies..."
sudo apt install -y curl git nginx

echo "Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

NODE_VERSION=$(node -v | sed 's/v//')
echo "Installed Node version: $NODE_VERSION"

echo "Cloning repository..."
read -p "Enter git repo URL: " REPO_URL
git clone "$REPO_URL"

REPO_NAME=$(basename "$REPO_URL" .git)
cd "$REPO_NAME"

echo "Creating .env file..."
echo "NEXT_PUBLIC_API_URL=/api" > .env

echo "Installing npm packages..."
npm install

echo "Removing default nginx config..."
sudo rm -f /etc/nginx/sites-enabled/default
sudo rm -f /etc/nginx/sites-available/default

echo "Enter PRIVATE BACKEND EC2 IP (example: 10.0.2.246)"
read -p "Private IP: " BACKEND_IP

echo "Creating nginx config..."

sudo tee /etc/nginx/sites-available/sales-invoice-ui > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /api/ {
        proxy_pass http://$BACKEND_IP/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "Enabling nginx site..."
sudo ln -sf /etc/nginx/sites-available/sales-invoice-ui /etc/nginx/sites-enabled/

echo "Testing nginx configuration..."
sudo nginx -t

echo "Restarting nginx..."
sudo systemctl restart nginx
sudo systemctl enable nginx

echo ""
echo "======================================"
echo "✔ System updated"
echo "✔ Node.js installed"
echo "✔ Nginx installed"
echo "✔ Repo cloned"
echo "✔ .env created"
echo "✔ npm install completed"
echo "✔ Nginx configured"
echo "✔ Nginx restarted"
echo "======================================"
echo "Setup complete!"