#!/usr/bin/env bash
# ShipGo customers + statement PDF → production (sapapi.muntajat.sa)
# Run from your Mac:  bash deploy-shipgo/deploy.sh
# Needs: `ssh alofq` (key auth, passwordless sudo). Never git-pulls; installs only the listed files.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
HOST=alofq
A=/home/sapapimuntajat/sapconnect_app
U=sapapimuntajat
PHP=/opt/cpanel/ea-php82/root/usr/bin/php

echo "== 1/6 upload bundle"
ssh $HOST 'mkdir -p ~/zb_deploy/shipgo && rm -rf ~/zb_deploy/shipgo/*'
scp -q "$HERE/shipgo_files.tgz" "$HERE/lang_keys.json" "$HERE/merge_lang.php" $HOST:~/zb_deploy/shipgo/

echo "== 2/6 install files (owner $U)"
ssh $HOST "set -e; cd ~/zb_deploy/shipgo && mkdir -p stage && tar xzf shipgo_files.tgz -C stage && cd stage
  for f in \$(find . -type f | sed 's|^\./||'); do
    sudo -n install -d -o $U -g $U -m 0755 \"$A/\$(dirname \$f)\"
    sudo -n install -o $U -g $U -m 0644 \"\$f\" \"$A/\$f\"
  done
  sudo -n install -d -o $U -g $U -m 0775 $A/storage/app/mpdf
  echo \"installed \$(find . -type f | wc -l) files\""

echo "== 3/6 merge translation keys (adds only, keeps server edits)"
ssh $HOST "sudo -n cp ~/zb_deploy/shipgo/lang_keys.json ~/zb_deploy/shipgo/merge_lang.php /tmp/ && sudo -n -u $U $PHP /tmp/merge_lang.php $A /tmp/lang_keys.json"

echo "== 4/6 composer: install mpdf/mpdf (no composer on the box → temporary composer.phar)"
ssh $HOST "sudo -n -u $U bash -c 'set -e; cd $A
  [ -f /tmp/composer.phar ] || curl -sS https://getcomposer.org/download/latest-stable/composer.phar -o /tmp/composer.phar
  COMPOSER_MEMORY_LIMIT=-1 $PHP -d memory_limit=-1 /tmp/composer.phar require mpdf/mpdf:^8.3 --no-interaction --no-progress --prefer-dist 2>&1 | tail -5
  ls -d vendor/mpdf/mpdf'"

echo "== 5/6 migrate + clear caches"
ssh $HOST "sudo -n -u $U $PHP $A/artisan migrate --force && sudo -n -u $U $PHP $A/artisan optimize:clear"

echo "== 6/6 verify: route + first sync from SAP"
ssh $HOST "sudo -n -u $U $PHP $A/artisan route:list --name=shipgo && sudo -n -u $U $PHP $A/artisan shipgo:sync-customers"
echo "DONE → https://sapapi.muntajat.sa/admin/ship-go-customers"
