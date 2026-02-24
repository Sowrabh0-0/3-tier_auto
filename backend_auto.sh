#!/bin/bash
set -e

echo "Updating system..."
sudo apt update -y

echo "Installing dependencies..."
sudo apt install -y python3 python3-venv python3-pip git nginx mysql-client

echo "Enter backend GitHub repository URL:"
read REPO_URL

git clone "$REPO_URL"

REPO_NAME=$(basename "$REPO_URL" .git)
cd "$REPO_NAME"

echo "Creating Python virtual environment..."
python3 -m venv venv

echo "Activating virtual environment..."
source venv/bin/activate

echo "Installing requirements..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Enter DATABASE_URL:"
read DATABASE_URL

echo "Creating .env file..."
echo "DATABASE_URL=$DATABASE_URL" > .env

echo "Running database initialization..."
python app/init_db.py

echo "Removing default nginx configs..."
sudo rm -f /etc/nginx/sites-enabled/default
sudo rm -f /etc/nginx/sites-available/default

echo "Creating nginx config..."

sudo tee /etc/nginx/sites-available/sales-invoice > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF

echo "Enabling nginx site..."
sudo ln -sf /etc/nginx/sites-available/sales-invoice /etc/nginx/sites-enabled/

echo "Testing nginx configuration..."
sudo nginx -t

echo "Restarting nginx..."
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "Starting backend server..."

cd "$HOME/$REPO_NAME"
source venv/bin/activate
nohup uvicorn app.main:app --host 127.0.0.1 --port 8000 > backend.log 2>&1 &

echo ""
echo "======================================"
echo "✔ System updated"
echo "✔ Python + venv installed"
echo "✔ mysql-client installed"
echo "✔ Requirements installed"
echo "✔ .env created"
echo "✔ Database initialized"
echo "✔ Nginx configured"
echo "✔ Backend started on 127.0.0.1:8000"
echo "======================================"
echo "Backend setup complete!"