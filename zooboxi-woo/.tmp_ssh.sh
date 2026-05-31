#!/bin/bash
# Temporary script to check server readiness
export SSHPASS='^Vw_HCPI(Sq&y+v*'
sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 storezooboxi@62.138.14.178 << 'REMOTE_COMMANDS'
echo "=== CONNECTION OK ==="
echo "--- User & Home ---"
whoami
pwd
echo "--- PHP Version ---"
php -v 2>&1 | head -1
echo "--- PHP Modules ---"
php -m 2>&1 | grep -iE "(mysql|curl|gd|xml|mbstring|zip|json|openssl|intl|sodium)" | sort
echo "--- MySQL Version ---"
mysql --version 2>&1 || echo "mysql CLI not found"
echo "--- Disk Space ---"
df -h /home 2>&1 | tail -1
echo "--- public_html contents ---"
ls -la ~/public_html/ 2>&1
echo "--- WP-CLI ---"
wp --version 2>&1 || echo "WP-CLI not installed"
echo "--- Node/NPM ---"
node --version 2>&1 || echo "node not installed"
echo "--- Git ---"
git --version 2>&1 || echo "git not installed"
echo "=== CHECK COMPLETE ==="
REMOTE_COMMANDS
