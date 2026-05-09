#!/bin/bash

# ------------------------------------------------------------------------------------------#
# Popola la cache locale dei link PDF per ogni mese disponibile sul sito della
# Regione Sicilia (sezione "Monitoraggio giornaliero invasi ad uso potabile").
#
# La cache viene letta da check_convert_volumi_giornalieri.sh per evitare di
# rifetchare ad ogni esecuzione i mesi del passato (che non vengono più
# aggiornati). Lo script può essere lanciato:
#   - una tantum in locale per pre-popolare la cache prima del primo run in CI
#   - quando si vuole forzare un refresh completo (passare --force)
#
# Uso:
#   ./scripts/build_months_cache_giornalieri.sh           # popola solo i mesi mancanti
#   ./scripts/build_months_cache_giornalieri.sh --force   # rifetcha tutti i mesi
# ------------------------------------------------------------------------------------------#

set -e

readonly URL="https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/monitoraggio-giornaliero-invasi-ad-uso-potabile"
readonly PATH_DIR_CACHE_MONTHS="./risorse/processed-urls/cache_months_giornalieri"

force=false
[ "${1:-}" = "--force" ] && force=true

extract_h3_links() {
   local page_url=$1
   curl -skL "$page_url" \
   | scrape -e "#it-block-field-blocknodegeneric-pagefield-p-body h3 a" 2>/dev/null \
   | grep -oE 'href="[^"]+"' | sed 's/^href="//;s/"$//'
}

mkdir -p "$PATH_DIR_CACHE_MONTHS"

echo "🔎 Recupero elenco anni..."
year_urls=$(extract_h3_links "$URL")
n_years=$(echo "$year_urls" | grep -c .)
echo "   trovati $n_years anni"

echo "🔎 Recupero elenco mesi per ogni anno..."
month_urls=""
for year_url in $year_urls; do
   m=$(extract_h3_links "$year_url")
   month_urls+="$m"$'\n'
done
month_urls=$(echo "$month_urls" | awk 'NF')
n_months=$(echo "$month_urls" | grep -c .)
echo "   trovati $n_months mesi totali"

echo "📥 Fetch dei PDF per ogni mese..."
n_cached=0; n_fetched=0; n_skipped=0
while IFS= read -r month_url; do
   [ -z "$month_url" ] && continue
   slug=$(basename "$month_url")
   cache_file="$PATH_DIR_CACHE_MONTHS/$slug.txt"

   if [ "$force" = false ] && [ -s "$cache_file" ]; then
      n_cached=$((n_cached+1))
      echo "   ⏭️  $slug già in cache ($(wc -l < "$cache_file") PDF) — skip"
      continue
   fi

   echo "   ⬇️  fetch $slug..."
   month_pdfs=$(curl -skL "$month_url" | grep -oE 'href="[^"]+\.pdf"' | sed 's/^href="//;s/"$//' || true)
   if [ -n "$month_pdfs" ]; then
      echo "$month_pdfs" > "$cache_file"
      n_fetched=$((n_fetched+1))
      echo "      → $(echo "$month_pdfs" | wc -l) PDF salvati in $cache_file"
   else
      n_skipped=$((n_skipped+1))
      echo "      ⚠️  nessun PDF trovato per $slug"
   fi
done <<< "$month_urls"

echo ""
echo "✅ Cache aggiornata:"
echo "   già in cache: $n_cached"
echo "   nuovi fetch:  $n_fetched"
echo "   senza PDF:    $n_skipped"
echo "   directory:    $PATH_DIR_CACHE_MONTHS"
