#!/bin/bash

# Step 1: Prompt for MySQL root password
read -s -p "🔑 Enter MySQL root password: " MYSQL_PWD
echo
echo

# Step 2: Test MySQL password
echo
echo "🔍 Verifying MySQL root password..."
if ! mysql -u root -p"$MYSQL_PWD" -e "SELECT 1;" &>/dev/null; then
    echo
    echo "❌ Error: Invalid MySQL root password."
    exit 1
fi
echo
echo "✅ Password verified!"

# Step 3: Try auto-detecting .sql.enc file in current folder
shopt -s nullglob

ENC_FILES=(*.sql.enc)

# Check if no matching files
if [ ${#ENC_FILES[@]} -eq 0 ]; then
    echo
    echo "❌ No .sql.enc files found in current directory."
    echo
    while true; do
        # -e enables tab completion, -r disables backslash escapes
	echo
        read -e -r -p "📥 Please enter full path to the encrypted file (*.sql.enc): " ENC_FILE
        if [ -f "$ENC_FILE" ]; then
            break
        else
            echo
            echo "❌ File not found. Try again."
        fi
    done

elif [ ${#ENC_FILES[@]} -eq 1 ]; then
    ENC_FILE="${ENC_FILES[0]}"
    echo
    echo "📄 Found encrypted backup: $ENC_FILE"

else
    echo
    echo "⚠️  Could not auto-select a file because multiple exist."
    echo
    echo "📂 Available encrypted files:"
    ls -1 *.sql.enc

    while true; do
        echo
        read -e -r -p "📥 Please enter path to the encrypted file (*.sql.enc): " ENC_FILE
        if [ -f "$ENC_FILE" ]; then
            break
        else
            echo
            echo "❌ File not found. Try again."
        fi
    done
fi

# Step 4: Prompt for decryption password
echo
read -s -p "🔐 Enter decryption password: " DEC_PWD
echo

# Step 5: Decrypt to temp file 🔧
TEMP_SQL="temp_restore.sql"
echo
echo "🔄 Decrypting backup..."
openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$ENC_FILE" -out "$TEMP_SQL" -pass pass:"$DEC_PWD"
if [ $? -ne 0 ]; then
    echo
    echo "❌ Error: Decryption failed."
    echo " Possible reasons:"
    echo "    -Incorrect password."
    echo "    -Corrupted or invalid encrypted file"
    rm -f "$TEMP_SQL"
    exit 1
fi
echo
echo "✅ Decryption successful!"

# Step 6: Fetch the database Name from the exported file
#=====> 1. Try CREATE DATABASE ---
DB_NAME=$(grep -iE '^CREATE DATABASE' "$TEMP_SQL" | sed -E "s/.*\`?([a-zA-Z0-9_]+)\`?.*/\1/" | head -n1)

#=====> 2. Try USE statement ---
if [ -z "$DB_NAME" ]; then
    DB_NAME=$(grep -iE '^USE ' "$TEMP_SQL" | sed -E "s/^USE \`?([a-zA-Z0-9_]+)\`?;.*/\1/I" | head -n1)
fi

#=====> 3. Try comment line with database name ---
if [ -z "$DB_NAME" ]; then
    DB_NAME=$(grep -i '^-- Host: .*Database:' "$TEMP_SQL" | sed -E "s/^-- Host: .*Database: ([a-zA-Z0-9_]+)/\1/" | head -n1)
fi

#====> 4. Fallback: use filename base ---
if [ -z "$DB_NAME" ]; then
    DB_NAME=$(basename "$ENC_FILE" | sed 's/\.sql\.enc$//')
    echo
    echo "ℹ️  No DB name found in SQL — using fallback from filename: $DB_NAME"
else
    echo
    echo "✅ Extracted database name: $DB_NAME"
fi

# Step 7: Check if DB already exists
if mysql -u root -p"$MYSQL_PWD" -e "USE \`$DB_NAME\`" &>/dev/null; then
    echo
    echo "❌ Database '$DB_NAME' already exists."
    rm -f "$TEMP_SQL"
    exit 1
fi

# Step 8: Create the new database
echo
echo "🛠️ Creating database '$DB_NAME'..."
mysql -u root -p"$MYSQL_PWD" -e "CREATE DATABASE \`$DB_NAME\`;"
if [ $? -ne 0 ]; then
    echo
    echo "❌ Error: Failed to create database."
    rm -f "$TEMP_SQL"
    exit 1
fi
echo
echo "✅ Database '$DB_NAME' created!"

# Step 9: Import the SQL
echo
echo "📥 Importing SQL into '$DB_NAME'..."
mysql -u root -p"$MYSQL_PWD" "$DB_NAME" < "$TEMP_SQL"
if [ $? -ne 0 ]; then
    echo
    echo "❌ Error: Import failed."
    rm -f "$TEMP_SQL"
    exit 1
fi

# Step 10: Cleanup
rm -f "$TEMP_SQL"
echo
echo "✅ Import successful into database '$DB_NAME'!"

