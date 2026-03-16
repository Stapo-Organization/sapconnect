#!/bin/bash
set -e

echo "Starting Deployment (Retry)..."

# 1. Clean up old extraction
# 1. Clean up old extraction (Preserve .env)
echo "Preserving .env..."
if [ -f "sapconnect_app/.env" ]; then
    cp sapconnect_app/.env .env.backup
fi

rm -rf sapconnect_app
mkdir sapconnect_app

# 2. Extract
echo "Extracting..."
tar -xzf sapconnect.tar.gz -C sapconnect_app --strip-components=1 2>/dev/null || true

# 3. Enter directory
cd sapconnect_app

# 4. Install Composer manually with config override
echo "Checking Composer..."
# Always download to ensure we have it, or check first
if [ ! -f "composer.phar" ]; then
    echo "Downloading Composer..."
    curl -sS https://getcomposer.org/installer -o composer-setup.php
    php -d allow_url_fopen=On composer-setup.php
    rm composer-setup.php
fi

COMPOSER_BIN="php -d allow_url_fopen=On composer.phar"

# 5. Install Dependencies
echo "Running Composer Install..."
$COMPOSER_BIN install --no-dev --optimize-autoloader

# 6. Environment Setup
if [ -f "../.env.backup" ]; then
    echo "Restoring .env..."
    mv ../.env.backup .env
elif [ ! -f .env ]; then
    echo "Using .env.example..."
    cp .env.example .env
fi

# Generate Key
php artisan key:generate

# 7. Migrate (Attempt)
echo "Running Migrations..."
# We use force. If DB fails, it fails (user needs to fix .env).
# We append '|| true' to not exit on migration failure so we can finish linking.
php artisan migrate --force || echo "MIGRATION FAILED - CHECK DATABASE CREDENTIALS"

# 8. Filament Assets
echo "Publishing Filament Assets..."
php artisan filament:upgrade

# 9. Link to Public
cd ..
echo "Updating public_html..."

# Backup public_html
if [ -d "public_html" ] && [ ! -L "public_html" ]; then
    timestamp=$(date +%s)
    echo "Backing up public_html to public_html_$timestamp"
    mv public_html "public_html_$timestamp"
fi

# Remove symlink if exists
if [ -L "public_html" ]; then
    rm public_html
fi

# Create Symlink
ln -s sapconnect_app/public public_html

# 10. Permissions
echo "Setting Permissions..."
chmod -R 775 sapconnect_app/storage sapconnect_app/bootstrap/cache

# 11. Clear Caches
echo "Clearing Caches..."
cd sapconnect_app
php artisan optimize:clear
cd ..

echo "Deployment Complete!"
