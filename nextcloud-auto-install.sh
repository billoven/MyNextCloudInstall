#!/usr/bin/env bash
# ============================================================
# 🧭 Nextcloud Manager Script
# Author: Pierre / billoven
# Repository: https://github.com/billoven/MyNextCloudInstall
# Description: Automated setup and management of Nextcloud
# Environment: Ubuntu 24.04 / Apache2 / MariaDB
# ============================================================

set -e

# --- Git Versioning Info ---
REPO_URL="https://github.com/billoven/MyNextCloudInstall"
SCRIPT_NAME=$(basename "$0")

if [ -d .git ]; then
  GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  GIT_DATE=$(git log -1 --format=%cd --date=short 2>/dev/null)
  GIT_TAG=$(git describe --tags --always 2>/dev/null)
else
  GIT_COMMIT="manual"
  GIT_BRANCH="N/A"
  GIT_DATE=$(date +%F)
  GIT_TAG="v0.0"
fi

VERSION_INFO="${GIT_TAG} (${GIT_COMMIT}, ${GIT_DATE})"

# --- Helper Functions ---
confirm() {
  read -rp "$1 [y/N]: " response
  [[ "$response" =~ ^[Yy]$ ]]
}

pause() {
  read -rp "Press [Enter] to continue..."
}

# --- Display Header ---
clear
echo "======================================================"
echo "       🧭 Nextcloud Manager Script"
echo "======================================================"
echo " Repository : billoven/MyNextCloudInstall"
echo " Version    : ${VERSION_INFO}"
echo "------------------------------------------------------"

# --- Ask for basic configuration ---
read -rp "Enter LAN IP of this server (ex: 192.168.17.30): " LAN_IP
read -rp "Enter your public Box IP (ex: 88.173.194.204): " BOX_IP
read -rp "Enter desired port on Box (ex: 17443): " BOX_PORT
read -rp "Enter Nextcloud DB name [nextcloud]: " DB_NAME
DB_NAME=${DB_NAME:-nextcloud}
read -rp "Enter DB user [nc_user]: " DB_USER
DB_USER=${DB_USER:-nc_user}
read -rp "Enter DB password: " DB_PASS
read -rp "Enter admin username [admin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}
read -rp "Enter admin password: " ADMIN_PASS

echo ""
echo "LAN_IP=${LAN_IP}"
echo "BOX_IP=${BOX_IP}:${BOX_PORT}"
echo "DB_NAME=${DB_NAME}"
echo "DB_USER=${DB_USER}"
echo "ADMIN_USER=${ADMIN_USER}"
confirm "Proceed with installation?" || exit 1

# --- Auto-update check ---
if confirm "Check for updates from GitHub?"; then
  if [ -d .git ]; then
    echo "Checking for updates..."
    git fetch origin
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    if [ "$LOCAL" != "$REMOTE" ]; then
      echo "New version available. Updating..."
      git pull --rebase
      echo "✅ Script updated. Please re-run."
      exit 0
    else
      echo "✅ Already up-to-date."
    fi
  else
    echo "No .git repository found — skipping update check."
  fi
fi

# --- Package installation ---
echo "Installing dependencies..."
sudo apt update -y
sudo apt install -y apache2 mariadb-server unzip openssl php php-mysql libapache2-mod-php php-xml php-zip php-curl php-gd php-mbstring php-intl php-bcmath php-imagick wget

# --- Download and unpack Nextcloud ---
NEXTCLOUD_VERSION="31.0.9"
echo "Downloading Nextcloud ${NEXTCLOUD_VERSION}..."
wget -q "https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.zip" -P /tmp
sudo unzip -q /tmp/nextcloud-${NEXTCLOUD_VERSION}.zip -d /var/www/
sudo chown -R www-data:www-data /var/www/nextcloud
sudo chmod -R 755 /var/www/nextcloud

# --- Create data directory ---
sudo mkdir -p /srv/nextcloud_data
sudo chown -R www-data:www-data /srv/nextcloud_data

# --- Configure MariaDB ---
echo "Configuring MariaDB..."
sudo systemctl enable mariadb --now
sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

# --- Generate SSL certificates ---
SSL_CERT="/etc/apache2/ssl/server.crt"
SSL_KEY="/etc/apache2/ssl/server.key"
if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
  echo "Generating self-signed certificate..."
  sudo mkdir -p /etc/apache2/ssl
  sudo openssl req -x509 -newkey rsa:4096 -keyout "$SSL_KEY" -out "$SSL_CERT" -days 365 -nodes \
    -subj "/CN=${LAN_IP}"
fi

# --- Apache configuration ---
echo "Configuring Apache..."
sudo tee /etc/apache2/sites-available/nextcloud.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${LAN_IP}
    ServerAlias ${BOX_IP}
    Redirect permanent / https://${LAN_IP}/
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/nextcloud-ssl.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName ${LAN_IP}
    ServerAlias ${BOX_IP}

    DocumentRoot /var/www/nextcloud
    <Directory /var/www/nextcloud>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
        SetEnv HOME /var/www/nextcloud
        SetEnv HTTP_HOME /var/www/nextcloud
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined

    SSLEngine on
    SSLCertificateFile ${SSL_CERT}
    SSLCertificateKeyFile ${SSL_KEY}

    <IfModule mod_headers.c>
        Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-Frame-Options "SAMEORIGIN"
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Referrer-Policy "no-referrer"
    </IfModule>
</VirtualHost>
EOF

sudo a2ensite nextcloud.conf nextcloud-ssl.conf
sudo a2enmod rewrite headers ssl env dir mime
sudo systemctl reload apache2

# --- Install Nextcloud ---
echo "Installing Nextcloud..."
sudo -u www-data php /var/www/nextcloud/occ maintenance:install \
  --database "mysql" \
  --database-name "${DB_NAME}" \
  --database-user "${DB_USER}" \
  --database-pass "${DB_PASS}" \
  --admin-user "${ADMIN_USER}" \
  --admin-pass "${ADMIN_PASS}" \
  --data-dir "/srv/nextcloud_data"

# --- Configure Trusted Domains ---
sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 0 --value="localhost"
sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value="${LAN_IP}"
sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 2 --value="${BOX_IP}"

# --- Final message ---
echo "=========================================================="
echo " ✅ Nextcloud installation complete!"
echo " Access it at: https://${LAN_IP}/nextcloud"
echo " Admin user: ${ADMIN_USER}"
echo "=========================================================="
pause

# --- User Management Menu ---
while true; do
  clear
  echo "=============================================="
  echo "     🧭 Nextcloud Manager Script"
  echo "=============================================="
  echo " Repository: billoven/MyNextCloudInstall"
  echo " Version: ${VERSION_INFO}"
  echo "----------------------------------------------"
  echo "1) Add new user"
  echo "2) Reset user password"
  echo "3) Show system status"
  echo "4) Exit"
  echo "----------------------------------------------"
  read -rp "Select an option [1-4]: " CHOICE
  case "$CHOICE" in
    1)
      read -rp "Enter new username: " NEW_USER
      read -rsp "Enter password for ${NEW_USER}: " NEW_PASS
      echo
      export OC_PASS="${NEW_PASS}"
      sudo -u www-data php /var/www/nextcloud/occ user:add --password-from-env "${NEW_USER}"
      ;;
    2)
      read -rp "Enter username to reset: " RESET_USER
      sudo -u www-data php /var/www/nextcloud/occ user:resetpassword "${RESET_USER}"
      ;;
    3)
      sudo -u www-data php /var/www/nextcloud/occ status
      pause
      ;;
    4)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid choice."
      ;;
  esac
done
