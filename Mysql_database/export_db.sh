#!/bin/bash

# Step 1: Prompt for MySQL root password and validate
echo
read -s -p " 🔐 Enter MySQL root password: " MYSQL_PWD
echo
echo
echo " 🔄 Verifying MySQL connection..."
if ! mysql -u root -p"$MYSQL_PWD" -e "EXIT" 2>/dev/null; then
    echo
    echo " ❌ Error: MySQL authentication failed. Please check your password."
    exit 1
fi
echo
echo " ✅ MySQL login successful!"

# Step 2: Fetch and show list of user-created databases
echo
echo " 📋 Fetching list of databases..."
databases=$(mysql -u root -p"$MYSQL_PWD" -e "SHOW DATABASES;" | tail -n +2 | grep -Ev "(information_schema|performance_schema|mysql|sys)")

if [ -z "$databases" ]; then
    echo
    echo " ⚠️  No user databases found."
    exit 1
fi
echo
echo " 📂 Available databases:"
echo "$databases"

# Step 3: Ask user which database to export
echo
read -p " 📌 Enter the database name to export: " DB_NAME

# Validate input
if ! echo "$databases" | grep -q "^$DB_NAME$"; then
    echo
    echo " ❌ Error: Database '$DB_NAME' not found in the list!"
    exit 1
fi

# Step 4: Ask for encryption password
echo
read -s -p " 🔑 Enter encryption password: " ENC_PWD
echo
echo
read -s -p " 🔁 Confirm encryption password: " ENC_PWD_CONFIRM
echo

if [ "$ENC_PWD" != "$ENC_PWD_CONFIRM" ]; then
    echo
    echo " ❌ Error: Passwords do not match!"
    exit 1
fi

# Generate filenames
DATE=$(date +%Y:%m:%d)
OUTPUT_FILE="${DB_NAME}_${DATE}.sql"
ENCRYPTED_FILE="${OUTPUT_FILE}.enc"

# Dump the database
echo
echo " 💾 Exporting database '$DB_NAME'..."
mysqldump -u root -p"$MYSQL_PWD" "$DB_NAME" > "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
    echo
    echo " ❌ Error: Database export failed."
    rm -f "$OUTPUT_FILE"
    exit 1
fi
echo
echo " ✅ Database export completed."

# Encrypt the file
echo
echo " 🔐 Encrypting export file..."
openssl enc -aes-256-cbc -salt -pbkdf2 -in "$OUTPUT_FILE" -out "$ENCRYPTED_FILE" -pass pass:"$ENC_PWD"
if [ $? -ne 0 ]; then
    echo
    echo " ❌ Error: Encryption failed."
    rm -f "$OUTPUT_FILE" "$ENCRYPTED_FILE"
    exit 1
fi

# Remove plain SQL file
rm -f "$OUTPUT_FILE"
echo
echo " ✅ Encrypted file saved as: $ENCRYPTED_FILE"

