#!/usr/bin/env bash
# Read-only extraction of the sapconnect production mirror (SELECT only, streamed over ssh, nothing written on the server).
# Usage: WH=RUH010 ./10_extract_prod.sh [only_name ...]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$ROOT/storage/analysis/raw/db"; mkdir -p "$OUT"
WH="${WH:-RUH010}"
DB="sapapimuntajat_apisap"
only=("$@")
for f in "$HERE"/sql/*.sql; do
  base="$(basename "$f")"; name="${base%%.*}"; kind="${base#*.}"; kind="${kind%.sql}"   # tsv | ndjson
  if [ ${#only[@]} -gt 0 ] && ! printf '%s\n' "${only[@]}" | grep -qx "$name"; then continue; fi
  outname="${name/_WH/_$WH}"
  sql="$(sed "s/__WH__/$WH/g" "$f" | tr '\n' ' ')"
  flags="--batch --quick"; [ "$kind" = "ndjson" ] && flags="--batch --quick --raw --skip-column-names"
  t0=$(date +%s)
  # shellcheck disable=SC2029
  printf '%s\n' "$sql" | ssh -o ConnectTimeout=20 alofq "sudo -n mysql $DB $flags" 2>"$OUT/$outname.err" | gzip -6 > "$OUT/$outname.$kind.gz"
  rc=${PIPESTATUS[1]}
  n=$(gzip -dc "$OUT/$outname.$kind.gz" | wc -l | tr -d ' ')
  grep -v 'post-quantum\|store now, decrypt\|openssh.com/pq' "$OUT/$outname.err" > "$OUT/$outname.err.clean" 2>/dev/null; mv "$OUT/$outname.err.clean" "$OUT/$outname.err"
  echo "$(date +%H:%M:%S) $outname.$kind.gz rc=$rc lines=$n bytes=$(stat -f %z "$OUT/$outname.$kind.gz") took=$(( $(date +%s) - t0 ))s $( [ -s "$OUT/$outname.err" ] && echo "ERR: $(head -c 200 "$OUT/$outname.err")" )"
done
echo "extract done → $OUT"
