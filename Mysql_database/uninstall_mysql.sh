#!/bin/bash

# === STEP 1: Check if MySQL is installed ===
if ! command -v mysql >/dev/null 2>&1; then
    echo " ❌ MySQL is not installed on this system. Exiting."
    exit 1
fi

echo "✅ MySQL installation found."

# === STEP 2: Ask for MySQL root password and validate ===
echo
read -s -p " 🔑 Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo
echo
echo " 🔍 Validating MySQL root password..."

mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo
    echo " ❌ Incorrect MySQL root password. Exiting."
    exit 1
fi
echo
echo " ✅ Root password is correct."

# === STEP 3: Ask if user wants to back up databases ===
echo
read -p " 💾 Do you want to back up all MySQL databases before uninstalling? (yes/no): " BACKUP_CONFIRM

if [[ "$BACKUP_CONFIRM" == "yes" ]]; then
    BACKUP_DIR="$HOME/mysql_backup"
    mkdir -p "$BACKUP_DIR"

    echo
    echo " 📦 Backing up all databases to: $BACKUP_DIR"

    mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases --single-transaction --quick --lock-tables=false > "$BACKUP_DIR/all_databases_backup_$(date +%Y:%m:%d_%H:%M:%S).sql"

    if [ $? -eq 0 ]; then
	echo    
        echo " ✅ Backup successful: $BACKUP_DIR/all_databases_backup_$(date +%Y:%m:%d_%H:%M:%S).sql"
    else
	echo
        echo " ❌ Backup failed. Exiting for safety."
        exit 1
    fi
else
    echo
    echo " ⚠️  Skipping database backup as per user input."
fi

# === STEP 4: Final confirmation before uninstalling ===
echo
echo " ⚠️  WARNING: This will COMPLETELY uninstall MySQL Server and remove ALL related files."
echo
read -p " ❓ Are you absolutely sure you want to continue? (yes/no): " FINAL_CONFIRM

if [[ "$FINAL_CONFIRM" != "yes" ]]; then
    echo
    echo " ❌ Uninstallation cancelled by user."
    exit 0
fi

# === STEP 5: Stop MySQL service ===
echo
echo " 🛑 Stopping MySQL service..."
sudo systemctl stop mysql

# === STEP 6: Purge MySQL packages ===
echo
echo " 🧹 Removing MySQL packages..."
sudo apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* > /dev/null

# === STEP 7: Delete configs and data ===
echo
echo " 🗑️  Deleting MySQL configuration and data directories..."
sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/log/mysql.*

# === STEP 8: Cleanup ===
echo
echo " 🧼 Cleaning up orphaned packages and cached files..."
sudo apt-get autoremove -y > /dev/null
sudo apt-get autoclean > /dev/null
echo
echo "✅ MySQL Server has been completely uninstalled from this system."

