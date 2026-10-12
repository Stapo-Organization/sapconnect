#!/bin/bash
# Install the B2B storefront + its catalogue API on sapapi.muntajat.sa.
# Run ON THE SERVER, from the directory holding this file and b2b-deploy.tar.gz.
#
#   bash install_b2b.sh
#
# Idempotent: re-running replaces the site and the two API files.
set -euo pipefail

APP="${APP:-$HOME/sapconnect_app}"
[ -d "$APP" ] || { echo "Laravel app not found at $APP — set APP=/path/to/app"; exit 1; }

# The public dir is wherever index.php lives.
if   [ -f "$APP/public/index.php" ];    then PUB="$APP/public"
elif [ -f "$HOME/public_html/index.php" ]; then PUB="$HOME/public_html"
else echo "could not locate the public directory"; exit 1; fi
echo "app    : $APP"
echo "public : $PUB"

echo "==> unpacking"
rm -rf ./_b2b_stage && mkdir ./_b2b_stage
tar -xzf b2b-deploy.tar.gz -C ./_b2b_stage

echo "==> backend files"
mkdir -p "$APP/app/Http/Controllers/Api" "$APP/config"
cp ./_b2b_stage/backend/B2bCatalogController.php "$APP/app/Http/Controllers/Api/"
cp ./_b2b_stage/backend/b2b_showrooms.php "$APP/config/"
cp ./_b2b_stage/backend/b2b_labels_ar.php   "$APP/config/"
chmod 644 "$APP/app/Http/Controllers/Api/B2bCatalogController.php" \
          "$APP/config/b2b_showrooms.php" "$APP/config/b2b_labels_ar.php"

# Add the two routes only if they are not already there.
ROUTES="$APP/routes/api.php"
cp "$ROUTES" "$ROUTES.bak.$(date +%s)"
if ! grep -q "B2bCatalogController" "$ROUTES"; then
  echo "==> registering routes"
  python3 - "$ROUTES" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
block = """
// Muntajat B2B storefront — whole-catalogue feed and per-product marketing copy.
// Publishes retail (RRP) prices only; wholesale never leaves the server.
Route::prefix('store')->group(function () {
    Route::get('/b2b/catalog', [\\App\\Http\\Controllers\\Api\\B2bCatalogController::class, 'catalog']);
    Route::get('/b2b/product/{code}', [\\App\\Http\\Controllers\\Api\\B2bCatalogController::class, 'product']);
});
"""
open(p, 'w').write(s.rstrip() + "\n" + block)
print("   routes appended")
PY
else
  echo "==> routes already registered"
fi

echo "==> static site -> $PUB/b2b"
rm -rf "$PUB/b2b"
mv ./_b2b_stage/muntajat-b2b-deploy "$PUB/b2b"
chmod -R a+rX "$PUB/b2b"

echo "==> clearing caches"
cd "$APP"
php artisan route:clear  >/dev/null 2>&1 || true
php artisan config:clear >/dev/null 2>&1 || true
php artisan cache:clear  >/dev/null 2>&1 || true

rm -rf "$OLDPWD/_b2b_stage" 2>/dev/null || true

echo
echo "done."
echo "  site : http://sapapi.muntajat.sa/b2b/"
echo "  api  : http://sapapi.muntajat.sa/api/store/b2b/catalog"
echo
echo "verify:"
echo "  curl -s -o /dev/null -w '%{http_code}\\n' http://sapapi.muntajat.sa/api/store/b2b/catalog"
echo "  curl -s -o /dev/null -w '%{http_code}\\n' http://sapapi.muntajat.sa/b2b/brands/kit-cat.html"
