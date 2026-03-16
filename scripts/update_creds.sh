#!/bin/bash

# Remove existing keys
sed -i '/^SAP_COMPANY_DB=/d' .env
sed -i '/^SAP_USERNAME=/d' .env
sed -i '/^SAP_PASSWORD=/d' .env

# Append new keys safely
# Using single quotes for values in .env to disable variable expansion parsing by PHP DotEnv
# Using shell escaping to ensure correct characters are written

echo "SAP_COMPANY_DB=PPTC_V5_PROD" >> .env
echo "SAP_USERNAME='ppte\\C001111.29'" >> .env
echo "SAP_PASSWORD='$>B1\$Sap4VA0'" >> .env

# Clear cache
php artisan config:clear
