# 📘 Nextcloud Installation & Configuration Guide

**Project Repository:** [https://github.com/billoven/MyNextCloudInstall](https://github.com/billoven/MyNextCloudInstall)
**Maintainer:** Pierre
**Environment:** Ubuntu Server 24.04 LTS
**Version:** Automatically displayed by the installer (from Git commit)

---

## 🧩 1. Purpose

This document explains how to **install, configure, and maintain Nextcloud** on a self-hosted server in a **multi-webapp environment** (`/var/www`) alongside other applications such as `cashcue*`, `adminer`, and `wconditions*`.

It also describes the **automated installation script** that simplifies deployment, configuration, and certificate management.

* These are Billoven personal applications that have nothing to deal with NextCloud.
---

## ⚙️ 2. System Requirements

| Component      | Version / Notes                    |
| -------------- | ---------------------------------- |
| **OS**         | Ubuntu 24.04 LTS (or compatible)   |
| **Web Server** | Apache 2.4.x                       |
| **Database**   | MariaDB 10.6+                      |
| **PHP**        | PHP 8.3.x with required extensions |
| **Nextcloud**  | Version 31.x or higher             |
| **OpenSSL**    | For SSL certificate generation     |

Update your system before starting:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 🧱 3. Folder Structure

| Path                                                         | Purpose                                           |
| ------------------------------------------------------------ | ------------------------------------------------- |
| `/var/www/nextcloud`                                         | Web root for Nextcloud                            |
| `/srv/nextcloud_data`                                        | User data storage (outside web root for security) |
| `/etc/apache2/sites-available/nextcloud.conf`                | HTTP configuration                                |
| `/etc/apache2/sites-available/nextcloud-ssl.conf`            | HTTPS configuration                               |
| `/etc/apache2/ssl/server.crt`, `/etc/apache2/ssl/server.key` | SSL certificates                                  |
| `/var/log/nextcloud.log`                                     | Application logs                                  |

---

## 🧮 4. The Automated Installation Script

The script `install_nextcloud.sh` handles the entire installation process — **from package installation to web configuration and SSL setup**.

### ✅ Features

* Checks system requirements
* Installs Apache, MariaDB, PHP, and Nextcloud dependencies
* Creates a secure database and user
* Deploys Nextcloud under `/var/www/nextcloud`
* Configures Apache for both HTTP and HTTPS
* Automatically generates **self-signed certificates** (if missing)
* Creates the admin account
* Displays **version information** from GitHub (`git describe` or commit hash)
* Can be **re-run safely** for updates or redeployment

---

## 💡 5. Script Execution

### 5.1 Clone the Repository

```bash
git clone https://github.com/billoven/MyNextCloudInstall.git
cd MyNextCloudInstall
```

### 5.2 Make the Script Executable

```bash
chmod +x install_nextcloud.sh
```

### 5.3 Run the Script

```bash
sudo ./install_nextcloud.sh
```

### 5.4 Interactive Prompts

The script will sequentially ask for:

1. **Local server IP** (e.g. `192.168.17.30`)
2. **Public (Box) IP** (e.g. `88.173.194.204`)
3. **MariaDB root password**
4. **Nextcloud database name, user, and password**
5. **Nextcloud admin user and password**

Each input is **confirmed interactively** before proceeding.

---

## 🔒 6. SSL Certificate Management

If the certificates `/etc/apache2/ssl/server.crt` and `/etc/apache2/ssl/server.key` do not exist, the script automatically creates **self-signed certificates** valid for 10 years using OpenSSL:

```bash
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/apache2/ssl/server.key \
  -out /etc/apache2/ssl/server.crt \
  -subj "/C=FR/ST=IDF/L=Villebon/O=LocalServer/OU=IT/CN=192.168.17.30"
```

You can replace them later with Let’s Encrypt certificates if desired.

---

## 🗃️ 7. Database Configuration

After script execution, the MariaDB setup includes:

```sql
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nc_user'@'localhost' IDENTIFIED BY 'NcPass2025!';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nc_user'@'localhost';
FLUSH PRIVILEGES;
```

To test the connection:

```bash
mysql -u nc_user -p -h localhost nextcloud
```

---

## 🌐 8. Apache Configuration Overview

Two virtual hosts are automatically configured:

### `/etc/apache2/sites-available/nextcloud.conf`

Handles HTTP redirection:

```apache
<VirtualHost *:80>
    ServerName 192.168.17.30
    ServerAlias 88.173.194.204
    DocumentRoot /var/www/nextcloud
    <Directory /var/www/nextcloud>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [R=301,L]
</VirtualHost>
```

### `/etc/apache2/sites-available/nextcloud-ssl.conf`

Handles HTTPS traffic:

```apache
<VirtualHost *:443>
    ServerName 192.168.17.30
    ServerAlias 88.173.194.204
    DocumentRoot /var/www/nextcloud
    <Directory /var/www/nextcloud>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/server.crt
    SSLCertificateKeyFile /etc/apache2/ssl/server.key
</VirtualHost>
```

---

## 👤 9. Creating New Nextcloud Users

To create a new user (non-admin):

```bash
sudo -u www-data php /var/www/nextcloud/occ user:add newuser
```

Automated version:

```bash
export OC_PASS="UserPassword!"
sudo -u www-data php /var/www/nextcloud/occ user:add --password-from-env newuser
```

---

## 🗾️ 10. Nextcloud Configuration File

Stored at: `/var/www/nextcloud/config/config.php`

Example:

```php
<?php
$CONFIG = array (
  'datadirectory' => '/srv/nextcloud_data',
  'dbtype' => 'mysql',
  'dbname' => 'nextcloud',
  'dbuser' => 'nc_user',
  'dbpassword' => 'NcPass2025!',
  'dbhost' => 'localhost',
  'trusted_domains' =>
  array (
    0 => 'localhost',
    1 => '192.168.17.30',
  ),
  'overwrite.cli.url' => 'https://192.168.17.30/nextcloud',
  'overwriteprotocol' => 'https',
  'htaccess.RewriteBase' => '/nextcloud',
  'logtimezone' => 'Europe/Paris',
  'logfile' => '/var/log/nextcloud.log',
  'loglevel' => 2,
);
```

---

## ⚠️ 11. Constraints & Limitations

* Designed for **LAN/private use** — not hardened for public Internet.
* SSL is **self-signed**, browsers will show a warning.
* Must be run as **root or sudo**.
* Works only on **Ubuntu/Debian-based** systems.
* Do not move the Nextcloud data directory inside `/var/www` for security reasons.

---

## ↺ 12. Updating or Re-running

You can re-run the script anytime.
It detects existing installations and **skips already configured steps** unless forced with:

```bash
sudo ./install_nextcloud.sh --force
```

---

## 📋 13. Version Information Display

At each execution, the script displays version details:

```
-----------------------------------------------
 MyNextCloudInstall - Version: v1.0.3 (commit a4b29f2)
 Repository: https://github.com/billoven/MyNextCloudInstall
-----------------------------------------------
```

Version info is retrieved dynamically via `git describe --always --tags`.

---

## 🧹 14. Maintenance Commands

### View Logs

```bash
tail -f /var/log/nextcloud.log
```

### Check Nextcloud Integrity

```bash
sudo -u www-data php /var/www/nextcloud/occ maintenance:check
```

### Enable Maintenance Mode

```bash
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on
```

---

## 🗟️ 15. Verification

After installation, open:

```
https://192.168.17.30/nextcloud
```

Login with the **admin credentials** you defined during setup.

---

**End of Document**
