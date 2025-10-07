# MyNextCloudInstall

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Project Repository:** [https://github.com/billoven/MyNextCloudInstall](https://github.com/billoven/MyNextCloudInstall)

## Legal & Attribution

This project provides an automated installation script for Nextcloud servers.

- Nextcloud © Nextcloud GmbH. Licensed under the GNU AGPLv3.
- This script is an independent work by Pierre (https://github.com/billoven).
- No affiliation or endorsement by Nextcloud GmbH is implied.
- This script is licensed under the MIT License (see LICENSE file).

---

## Overview

MyNextCloudInstall is an automated **Nextcloud installation and configuration script** designed for Ubuntu 24.04 LTS servers. It allows users to deploy Nextcloud in a **multi-webapp environment** alongside other applications such as `cashcue`, `adminer`, and `wconditions`.

The script handles package installation, database setup, Apache configuration, SSL certificate management, and admin/user account creation.

---

## Features

* Automated installation of Nextcloud (v31.x+) on Ubuntu 24.04
* Apache virtual host configuration for HTTP and HTTPS
* MariaDB database creation and user management
* Self-signed SSL certificate generation if missing
* Admin and user account creation via CLI
* Version tracking using Git commit and tags
* Safe to re-run for updates or redeployment

---

## Requirements

* Ubuntu Server 24.04 LTS
* Apache 2.4.x
* PHP 8.3.x with required extensions
* MariaDB 10.6+
* OpenSSL

---

## Quick Start

1. Clone the repository:

```bash
git clone https://github.com/billoven/MyNextCloudInstall.git
cd MyNextCloudInstall
```

2. Make the script executable:

```bash
chmod +x nextcloud-auto-install.sh
```

3. Run the script with sudo:

```bash
sudo ./nextcloud-auto-install.sh
```

Follow the interactive prompts for IP addresses, passwords, and admin account setup.

---

## SSL Certificates

The script automatically generates **self-signed certificates** if not present at `/etc/apache2/ssl/`:

* `server.crt`
* `server.key`

Later, you can replace them with Let’s Encrypt certificates if desired.

---

## Database

The script creates a MariaDB database and user for Nextcloud. Example:

```sql
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nc_user'@'localhost' IDENTIFIED BY 'NcPass2025!';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nc_user'@'localhost';
FLUSH PRIVILEGES;
```

---

## Apache Configuration

Two virtual hosts are created:

* `nextcloud.conf` for HTTP (port 80) with redirect to HTTPS
* `nextcloud-ssl.conf` for HTTPS (port 443) with SSL certificates

---

## User Management

Create new Nextcloud users:

```bash
sudo -u www-data php /var/www/nextcloud/occ user:add username
```

Or automated with environment variable:

```bash
export OC_PASS="UserPassword!"
sudo -u www-data php /var/www/nextcloud/occ user:add --password-from-env username
```

---

## Maintenance

* View logs: `tail -f /var/log/nextcloud.log`
* Enable maintenance mode: `sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on`
* Check Nextcloud integrity: `sudo -u www-data php /var/www/nextcloud/occ maintenance:check`

---

## Version Tracking

At each script execution, version details from Git are displayed:

```
-----------------------------------------------
 MyNextCloudInstall - Version: v1.0.3 (commit a4b29f2)
 Repository: https://github.com/billoven/MyNextCloudInstall
-----------------------------------------------
```

---

## License

MIT License. See LICENSE file for details.

---

## More Information

See the detailed **INSTALL_GUIDE.md** in the repository for step-by-step installation instructions, configuration tips, and troubleshooting guidance.
