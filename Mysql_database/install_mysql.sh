#!/bin/bash

# === STEP 1: Check if MySQL is Already Installed ===
echo " 🔍 Checking MySQL installation..."

if command -v mysql &> /dev/null; then
    echo
    echo " ✅ MySQL is already installed. Skipping installation."
    echo
    echo " ℹ️  If you want to reconfigure it, uninstall MySQL and rerun this script."
    exit 0
else
    echo
    echo " ❌ MySQL not found. Proceeding with installation..."
fi

# === STEP 2: Ask User for Root Password ===
echo
read -s -p " 🔐 Enter a New MySQL root password: " MYSQL_ROOT_PASSWORD
echo
echo
read -s -p " 🔐 Confirm MySQL root password: " MYSQL_ROOT_PASSWORD_CONFIRM
echo

if [ "$MYSQL_ROOT_PASSWORD" != "$MYSQL_ROOT_PASSWORD_CONFIRM" ]; then
    echo
    echo " ❌ Passwords do not match. Exiting."
    exit 1
fi

# === STEP 3: Install MySQL Server ===
echo
echo " 📦 Installing MySQL Server..."
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

if [ $? -ne 0 ]; then
    echo
    echo " ❌ MySQL installation failed!"
    exit 1
fi
echo
echo " ✅ MySQL installed successfully."

# === STEP 4: Secure MySQL Installation ===
echo
echo " 🔒 Securing MySQL..."

SECURE_MYSQL=$(cat <<EOF
-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';
-- Disallow remote root login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost');
-- Remove test database
DROP DATABASE IF EXISTS test;
-- Remove privileges on test databases
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- Apply changes
FLUSH PRIVILEGES;
EOF
)

echo "$SECURE_MYSQL" | sudo mysql -u root

if [ $? -eq 0 ]; then
    echo
    echo " ✅ MySQL secured successfully."
else
    echo
    echo " ❌ Failed to apply security settings."
    exit 1
fi

# === STEP 5: Test MySQL Root Login ===
echo
echo " 🔑 Verifying MySQL root login..."

mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo
    echo " ✅ MySQL root login successful."
else
    echo
    echo " ❌ MySQL root login failed. Please check the password."
    exit 1
fi

# === STEP 6: Final Status Check ===
sudo systemctl status mysql | grep Active

echo " 🎉 MySQL installation and secure setup completed successfully."

