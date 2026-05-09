#!/bin/bash


# ------------------------------------------------------------------------------------------#
# Questo script apre il sito della Regione Sicilia e controlla la presenza di nuovi 
# documenti PDF contenenti # dati sui volumi invasati dalle dighe siciliane con aggiornamento 
# mensile. Se trova nuovi PDF, li scarica e prova (in N_ATTEMPTS tentativi) a 
# convertirli in CSV sfruttando un LLM. 
# ------------------------------------------------------------------------------------------#



set -e
#set -x



#-----------------constants-----------------#
readonly URL="https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/monitoraggio-giornaliero-invasi-ad-uso-potabile"
readonly PATH_PDFS_LIST="./risorse/processed-urls/pdfs_list_volumi_giornalieri.txt"
readonly PATH_DIR_CACHE_MONTHS="./risorse/processed-urls/cache_months_giornalieri"
readonly PATH_DIR_VOLUMI_GIORNALIERI="./risorse/volumi-giornalieri"
readonly PATH_CSV_VOLUMI_GIORNALIERI="./risorse/sicilia_dighe_volumi_giornalieri.csv"
readonly PATH_CSV_VOLUMI_GIORNALIERI_LATEST="./risorse/sicilia_dighe_volumi_giornalieri_latest.csv"
readonly PATH_MSG_TELEGRAM="./risorse/msgs/new_volumi_giornalieri.md"
readonly PATH_EXTRACTION_REPORT="./risorse/report/extraction_giornalieri_latest.json"
readonly URL_HOMEPAGE="https://www.regione.sicilia.it"
readonly URL_CSV_ANAGRAFICA_DIGHE="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main/risorse/sicilia_dighe_anagrafica.csv"
readonly AI_RPM=5
readonly AI_RPD=20
readonly AI_RPD_LIMIT=19   # soglia oltre la quale si cambia modello (free tier = 20 RPD)
readonly AI_SLEEP=60
# LLM_MODEL_LITE viene usato SOLO come fallback dalla normalize_pdf_date,
# se la regex non riesce a estrarre la data dal nome file. In pratica
# raramente o mai (regex copre il 100% dei pattern storici noti).
# NB: i modelli gemma-3-* sono stati rimossi dall'API; gemma-4-31b-it è
# il sostituto. Per evitare il falso-positivo del safety filter su path
# con slash, la chiamata sostituisce '/' con ' ' nel prompt.
readonly LLM_MODEL_LITE="gemma-4-31b-it"
readonly LLM_MODEL_PRIMARY="gemini-2.5-flash"
readonly LLM_MODEL_FALLBACK="gemini-3-flash-preview"
readonly N_ATTEMPTS=2

# contatori per quota giornaliera per-modello (gestiti in pick_ai_model / count_ai_call)
n_ai_primary=0
n_ai_fallback=0
current_ai_model="$LLM_MODEL_PRIMARY"

# rotazione API key: il workflow esporta GEMINI_KEY (già impostata via `llm keys set gemini`)
# ed eventualmente GEMINI_KEY_2, GEMINI_KEY_3, ... Quando i contatori di entrambi i modelli
# sono saturi sulla key corrente, passo alla successiva e resetto i contatori.
api_keys=()
[ -n "${GEMINI_KEY:-}" ]   && api_keys+=("$GEMINI_KEY")
[ -n "${GEMINI_KEY_2:-}" ] && api_keys+=("$GEMINI_KEY_2")
[ -n "${GEMINI_KEY_3:-}" ] && api_keys+=("$GEMINI_KEY_3")
current_key_idx=0

rotate_api_key() {
   # Passa alla prossima API key disponibile e resetta i contatori per-modello.
   # Ritorna 0 se la rotazione è avvenuta, 1 se non ci sono altre key.
   local next_idx=$((current_key_idx+1))
   if [ $next_idx -ge ${#api_keys[@]} ]; then
      return 1
   fi
   current_key_idx=$next_idx
   echo "🔑 Passo alla API key #$((current_key_idx+1)) e resetto i contatori" >&2
   echo "${api_keys[$current_key_idx]}" | llm keys set gemini >/dev/null 2>&1 \
      || { echo "   ❌ Errore impostando la nuova API key" >&2; return 1; }
   n_ai_primary=0
   n_ai_fallback=0
   current_ai_model="$LLM_MODEL_PRIMARY"
   return 0
}

selected_model=""
pick_ai_model() {
   # Sceglie il modello da usare in base ai contatori giornalieri.
   # IMPORTANTE: NON va chiamata in subshell `$(...)`, altrimenti le modifiche
   # ai contatori globali e a current_ai_model non si propagano. Imposta la
   # variabile globale `selected_model`. Ritorna 1 se tutte le quote sono esaurite.
   if [ "$current_ai_model" = "$LLM_MODEL_PRIMARY" ] && [ $n_ai_primary -ge $AI_RPD_LIMIT ]; then
      echo "🔄 Raggiunte $n_ai_primary chiamate a $LLM_MODEL_PRIMARY, passo a $LLM_MODEL_FALLBACK" >&2
      current_ai_model="$LLM_MODEL_FALLBACK"
   fi
   if [ "$current_ai_model" = "$LLM_MODEL_FALLBACK" ] && [ $n_ai_fallback -ge $AI_RPD_LIMIT ]; then
      # provo a passare alla prossima API key (riparto da PRIMARY con contatori a zero)
      if ! rotate_api_key; then
         return 1
      fi
   fi
   selected_model="$current_ai_model"
   return 0
}

count_ai_call() {
   # Incrementa il contatore del modello attualmente in uso.
   if [ "$current_ai_model" = "$LLM_MODEL_PRIMARY" ]; then
      n_ai_primary=$((n_ai_primary+1))
   else
      n_ai_fallback=$((n_ai_fallback+1))
   fi
}



#----------------- functions -----------------#

# importing external 
source ./scripts/functions.sh

# custom

normalize_pdf_date() {
   # Estrae la data (YYYY-MM-DD) dal nome di un PDF dei volumi giornalieri.
   # Ordine dei tentativi:
   #   1) regex YYYY-MM-DD o YYYY-MM-D nel basename (copre il 99% dei file)
   #   2) regex DD.MM.YYYY o DD.MM.YY (es. "05.03.2025.pdf", "Volumi del 18.04.25.pdf")
   #   3) fallback AI con gemma-4-31b-it: il prompt sostituisce '/' con ' ' per
   #      evitare il falso positivo del content filter Gemini sui path filesystem-like
   # Stampa la data normalizzata su stdout, oppure ritorna 1 se nessun pattern matcha.
   local url=$1
   local fname=$(basename "$url")
   # url-decode minimale (%20 → spazio) per gestire nomi file con spazi
   fname=${fname//%20/ }

   # Pattern 1: YYYY-MM-DD o YYYY-MM-D
   local d=$(echo "$fname" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{1,2}' | head -1)
   if [ -n "$d" ]; then
      local y=${d%%-*}
      local rest=${d#*-}
      local m=${rest%%-*}
      local dd=${rest#*-}
      [ ${#dd} -eq 1 ] && dd="0$dd"
      echo "$y-$m-$dd"
      return 0
   fi

   # Pattern 2: DD.MM.YYYY o DD.MM.YY
   d=$(echo "$fname" | grep -oE '[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{2,4}' | head -1)
   if [ -n "$d" ]; then
      local dd=$(echo "$d" | cut -d. -f1)
      local m=$(echo "$d" | cut -d. -f2)
      local y=$(echo "$d" | cut -d. -f3)
      [ ${#dd} -eq 1 ] && dd="0$dd"
      [ ${#m} -eq 1 ] && m="0$m"
      [ ${#y} -eq 2 ] && y="20$y"
      echo "$y-$m-$dd"
      return 0
   fi

   # Fallback AI: prompt-only (gemma-4 non supporta system prompt e va in
   # "Internal error" sui path con slash → li sostituisco con spazi)
   echo "   ⚠️  regex fallita su '$fname', uso LLM fallback ($LLM_MODEL_LITE)" >&2
   local safe_url=${url//\// }
   local llm_out
   llm_out=$(llm -m "$LLM_MODEL_LITE" -o temperature 0 \
      "Estrai la data dal nome '$safe_url' e formattala come YYYY-MM-DD. Output: solo la data, una riga." 2>/dev/null) || return 1
   # gemma-4 a volte restituisce reasoning verboso: estraggo l'ultima occorrenza valida
   echo "$llm_out" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | tail -1 | grep . || return 1
}

save_clean_csv() {
   # Save LLM response to CSV with basic cleaning operations
   #
   # This function processes the response from an LLM (extracting data from PDF)
   # by removing empty lines, filtering out rows with missing volume values,
   # and cleaning whitespace. The result is saved to a CSV file.
   #
   # Args:
   #   llm_response: The text response from the LLM
   #   output_path: Path where the cleaned CSV will be saved
   #
   # Usage example:
   # save_clean_csv "$llm_response" "cleaned_file.csv"

   local llm_response=$1
   local output_path=$2
   
   # Call remove_trailing_empty_lines function from functions.sh
   remove_trailing_empty_lines "$llm_response" \
   | mlr --csv filter '$volume != ""' then clean-whitespace then skip-trivial-records > "$output_path"
}     

generate_telegram_message() {
   # Generate a formatted message for Telegram notification
   #
   # This function prepares a standardized notification message for Telegram
   #
   # Args:
   #   url_pdf: The URL of the source PDF file that was converted
   #   path_msg: Path where the message content will be saved
   #
   # Returns:
   #   Nothing, but creates a text file with formatted Telegram message content
   #   at the specified path_msg location.
   #
   # The message includes:
   #   - Notification of new extracted data
   #   - Link to source PDF
   #   - Link to resulting CSV file
   #   - Information about the extraction process
   #   - Link to submit issues if errors are found

   local url_pdf=$1
   local path_msg=$2

   # crea messaggio da inviare su telegram
   echo "🔎 Ho trovato ed estratto *nuovi dati* sui *volumi* (giornalieri) invasati dalle dighe siciliane!

   🔄 In particolare ho convertito [questo file PDF]($url_pdf) in [questo file CSV](https://github.com/opendatasicilia/emergenza-idrica-sicilia/blob/main/risorse/sicilia_dighe_volumi_giornalieri_latest.csv) tramite [✨ Gemini AI](https://gemini.google.com/). 

   ✅ L'estrazione automatica ha superato alcuni sanity check, ma se trovi un errore [apri una issue](https://github.com/opendatasicilia/emergenza-idrica-sicilia/issues/new?template=Blank+issue). Grazie!

   Se vuoi saperne di più sui dati estratti da ODS nell'ambito di questo progetto, puoi visitare [questa pagina](https://github.com/opendatasicilia/emergenza-idrica-sicilia/tree/main/risorse#dati-sugli-invasi-delle-dighe-e-sulle-riduzioni-idriche-in-sicilia).

   _Questo è un messaggio automatico gestito da un_ [workflow di GitHub](https://github.com/opendatasicilia/emergenza-idrica-sicilia/blob/main/.github/workflows/new_pdfs.yaml)" > $path_msg
}

try_extraction() {
   # funzione per l'estrazione dei dati dai PDF con tentativi multipli
   local new_filename=$1
   local max_attempts=$2
   local success=false
   
   # creo (se non esiste già) la cartella per i csv temporanei
   mkdir -p ./risorse/tmp
   
   for attempt in $(seq 1 $max_attempts); do
      echo "   🔄 Tentativo $attempt/$max_attempts: Converto in CSV..."
      
      # FIRST EXTRACTION (with anagrafica)
      system_prompt="Il tuo compito è quello di estrarre dati da un pdf allegato e di incrociarli con i dati di un'anagrafica csv passata come prompt. Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna invaso (chiamala 'diga_pdf') e quelli della colonne relative alla quota autorizzata, volume autorizzato, quota, volume, volume utile netto per utilizzatori (chiamale rispettivamente: quota_autorizzata, volume_autorizzato, quota, volume, volume_utile). Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. Dal CSV, estrai la colonna 'diga' che chiamerai 'diga_anagrafica' popolata con il nome corretto (da includere esattamente nell'output). Confronta le colonne 'diga_pdf' e 'diga_anagrafica' per fare in modo di arricchire il dataset e assegnare a ogni diga il corrispondente codice identificativo presente nella colonna 'cod' del csv. Talvolta è presente una diga chiamata ogliastro che coincide don sturzo; se questa diga non è presente nel pdf, non la includere nel tuo output. Assicurati di estrarre correttamente i dati relativi a tutte le dighe presenti nel pdf. Se il PDF contiene la diga castello, assicurati di estrarre i dati anche di questa diga. In ultimo, cestina la colonna 'diga_pdf' e  nell'output includi i valori di 'diga_anagrafica' sotto il nome di 'diga'. Attenzione ad attribuire correttamente il codice al nome della diga secondo l'anagrafica csv. Se l'anagrafica csv contiene più dighe della tabella pdf, l'output deve contenere solo ed esclusivamente le dighe presenti nel file pdf. L'output deve avere questa struttura 'cod,diga,data,quota_autorizzata,volume_autorizzato,quota,volume,volume_utile' e non deve avere righe vuote finali. Tieni presente che i valori di 'diga' devono essere esattamente coincidenti con quelli di 'diga_anagrafica'. I separatori di decimali dei volumi devono essere i punti e non le virgole (correggi la sintassi dei numeri da formato italiano a formato internazionale). Se l'output csv contiene righe finali senza valori, rimuovile."

      check_limits $AI_RPM $AI_SLEEP
      if ! pick_ai_model; then echo "   🛑 Quota giornaliera esaurita per tutte le API key."; return 2; fi
      model="$selected_model"
      llm_response=$(cat risorse/sicilia_dighe_anagrafica.csv | llm -x \
      -m "$model" \
      -s "$system_prompt" \
      -a "./risorse/pdf/volumi-giornalieri/$new_filename.pdf" \
      -o temperature 0.11) \
      || { echo "   ❌ Tentativo $attempt: Errore durante l'estrazione dati (prima estrazione)"; count_ai_call; n_ai=$((n_ai+1)); continue; }
      count_ai_call; n_ai=$((n_ai+1))

      # controlla se llm_response è vuota
      if [ -z "$llm_response" ]; then
         echo "   ❌ Tentativo $attempt: L'estrazione dati ha prodotto una risposta vuota. Riprovo..."
         continue
      fi
      
      # controlla sintassi csv con mlr --csv check
      if ! echo "$llm_response" | mlr --csv check 2>/dev/null; then
         echo "   ❌ Tentativo $attempt: L'estrazione dati ha prodotto un CSV con sintassi errata. Riprovo..."
         continue
      fi

      # rimuovo eventuali righe vuote finali e salvo il csv
      save_clean_csv "$llm_response" "./risorse/tmp/$new_filename.csv"
      echo "   🟢 Prima conversione da $new_filename.pdf in $new_filename.csv completata"

      # count rows (dams) in the first extraction
      n_dighe_ai_1=$(mlr --csv --headerless-csv-output cat -n then stats1 -a max -f n ./risorse/tmp/$new_filename.csv)
      echo "   Numero di righe (dighe) prima estrazione: $n_dighe_ai_1"

      # se n_dighe_ai_1 è uguale a 0 oppure è vuoto, riprova l'estrazione
      if [ -z "$n_dighe_ai_1" ] || [ "$n_dighe_ai_1" -eq 0 ]; then
         echo "   ❌ Tentativo $attempt: L'estrazione dati ha prodotto un CSV senza righe di dati (dighe). Riprovo..."
         continue
      fi
         
      # SECOND EXTRACTION (without anagrafica)
      echo "   💬 Double check: eseguo estrazione senza anagrafica..."

      system_prompt="Il tuo compito è quello di estrarre dati da un pdf allegato. Devi fornire un output in csv senza backtics iniziali e finali."

      prompt="Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna invaso e quelli della colonne relative alla quota autorizzata, volume autorizzato, quota, volume, volume utile netto per utilizzatori (chiamale rispettivamente: quota_autorizzata, volume_autorizzato, quota, volume, volume_utile). Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. L'output deve avere questa struttura 'cod,diga,data,quota_autorizzata,volume_autorizzato,quota,volume,volume_utile' e non deve avere righe vuote finali. I separatori di decimali dei volumi devono essere i punti e non le virgole (correggi la sintassi dei numeri da formato italiano a formato internazionale). Se l'output csv contiene righe finali senza valori, rimuovile."

      check_limits $AI_RPM $AI_SLEEP
      if ! pick_ai_model; then echo "   🛑 Quota giornaliera esaurita per tutte le API key."; return 2; fi
      model="$selected_model"
      llm_response=$(llm -x \
      -m "$model" \
      -s "$system_prompt" \
      "$prompt" \
      -a "./risorse/pdf/volumi-giornalieri/$new_filename.pdf" \
      -o temperature 0.1) \
      || { echo "   ❌ Tentativo $attempt: Errore durante l'estrazione dati (seconda estrazione)"; count_ai_call; n_ai=$((n_ai+1)); continue; }
      count_ai_call; n_ai=$((n_ai+1))

      # controlla se llm_response è vuota
      if [ -z "$llm_response" ]; then
         echo "   ❌ Tentativo $attempt: L'estrazione dati ha prodotto una risposta vuota. Riprovo..."
         continue
      fi

      # controlla sintassi csv con mlr --csv check
      if ! echo "$llm_response" | mlr --csv check 2>/dev/null; then
         echo "   ❌ Tentativo $attempt: L'estrazione dati ha prodotto un CSV con sintassi errata. Riprovo..."
         continue
      fi

      # rimuovo eventuali righe vuote finali, pulisco e salvo il csv
      save_clean_csv "$llm_response" "./risorse/tmp/2_$new_filename.csv"
      echo "   🟢 Conversione da $new_filename.pdf in 2_$new_filename.csv completata"

      # count rows (dams) in the second extraction
      n_dighe_ai_2=$(mlr --csv --headerless-csv-output cat -n then stats1 -a max -f n ./risorse/tmp/2_$new_filename.csv)
      echo "   Numero di righe (dighe) seconda estrazione: $n_dighe_ai_2"

      # check 1
      # check if n_dighe_ai_1 and n_dighe_ai_2 are equal, if not, display an error message
      if [ $n_dighe_ai_1 -ne $n_dighe_ai_2 ]; then
         echo "   ⚠️ Check 1 failed: il numero di righe estratte dai due metodi non corrisponde!"
         success=false
         break
      else
         echo "   ✅ Check 1 passed: Il numero di dighe estratte dai due metodi corrisponde."
      fi
         
      # COMPARE 1st and 2nd extraction
      echo "   🔍 Confronto i due file csv e individuo eventuali errori di estrazione..."

      system_prompt="Il tuo compito è quello di confrontare due file CSV contententi dati relativi a dighe e volumi e creare un report di validazione in json. Il report deve avere valid: false se i dati dei volumi non coincidono nei due file csv. I nomi delle dighe possono essere leggermente diversi e questo non incide sulla validità del report."

      prompt="Ti inserisco di seguito due CSV. Il secondo CSV è probabile che abbia delle dighe in più che nel primo file non sono censite. Fammi un piccolo report di validazione sintetico in json con due chiavi. Il json deve contenere le key 'valid' (booleana) e 'summary'. La key 'summary' deve contenere il motivo discorsivo in italiano del perchè il confronto è fallito (se è fallito). Se tra i due file csv ci sono discrepanze nel valore dei volumi allora il report è invalido e la key 'valid' deve contenere il valore false. Nel summary del report includi pure i dettagli sulle eventuali dighe mancanti nel primo file. Includi pure una sezione dedicata alla somiglianza dei nomi delle dighe. Se due dighe presentano nomi diversi ma simili, non è un errore e questo non inficia la key 'valid'. La presenza di nomi diversi ma simili non inficia la validità ( esempio: Se non ci sono discrepanze sui valori dei volumi, ci sono alcuni nomi di dighe simili, allora il report è valid: true). Di seguito ti riporto esempi di dighe con nomi simili: 'leone' e 'piano del leone' indicano la stessa diga. Assicurati di non considerare come errore le discrepanze nei nomi delle dighe. Il primo csv (prima estrazione) è il seguente: <primo_csv> $(cat ./risorse/tmp/$new_filename.csv) <\primo_csv>. Il secondo csv (seconda estrazione) è il seguente: <secondo_csv> $(cat ./risorse/tmp/2_$new_filename.csv) <\secondo_csv>"

      check_limits $AI_RPM $AI_SLEEP
      if ! pick_ai_model; then echo "   🛑 Quota giornaliera esaurita per tutte le API key."; return 2; fi
      model="$selected_model"
      llm_response=$(llm -m "$model" \
      -s "$system_prompt" \
      "$prompt" \
      -o json_object 1) \
      || { echo "❌ Tentativo $attempt: Errore durante il confronto dati"; count_ai_call; n_ai=$((n_ai+1)); continue; }
      count_ai_call; n_ai=$((n_ai+1))

      # salvo il report di validazione
      echo "$llm_response" > $PATH_EXTRACTION_REPORT

      # add date to report
      jq '. + {"date": "'$(date +%Y-%m-%d)'"}' $PATH_EXTRACTION_REPORT > $PATH_EXTRACTION_REPORT.tmp && mv $PATH_EXTRACTION_REPORT.tmp $PATH_EXTRACTION_REPORT

      # check 2
      report_validity=$(< $PATH_EXTRACTION_REPORT jq '.valid')
      if [ "$report_validity" == "true" ]; then
         echo "   ✅ Check 2 passed: Il confronto tramite AI dei dati delle due estrazioni non ha riscontrato errori nei dati estratti (nomi dighe e valori volumi)"
         rm ./risorse/tmp/2_$new_filename.csv

         # creo messaggio da inviare su telegram
         # mkdir -p ./risorse/msgs
         # generate_telegram_message $URL_HOMEPAGE$line $PATH_MSG_TELEGRAM

         # copio il csv generato nella cartella dei volumi giornalieri
         mkdir -p ./risorse/volumi-giornalieri
         cp ./risorse/tmp/$new_filename.csv ./risorse/volumi-giornalieri/$new_filename.csv

         # aggiorno il csv latest dei volumi giornalieri SOLO se la data del PDF
         # processato è più recente di quella attualmente in _latest.csv
         # (importante quando si recupera lo storico: non vogliamo sovrascrivere
         # latest con un PDF di mesi/anni precedenti)
         pdf_date=$(< ./risorse/tmp/$new_filename.csv mlr --csv --headerless-csv-output cut -f data | head -1)
         current_latest_date=""
         if [ -f "$PATH_CSV_VOLUMI_GIORNALIERI_LATEST" ]; then
            current_latest_date=$(< $PATH_CSV_VOLUMI_GIORNALIERI_LATEST mlr --csv --headerless-csv-output cut -f data 2>/dev/null | head -1)
         fi
         if [ -z "$current_latest_date" ] || [[ "$pdf_date" > "$current_latest_date" ]]; then
            cp ./risorse/tmp/$new_filename.csv $PATH_CSV_VOLUMI_GIORNALIERI_LATEST
            echo "   🔄 Aggiornato $(basename $PATH_CSV_VOLUMI_GIORNALIERI_LATEST) (data $pdf_date)"
         else
            echo "   ⏭️  $(basename $PATH_CSV_VOLUMI_GIORNALIERI_LATEST) NON aggiornato: data PDF ($pdf_date) <= data latest ($current_latest_date)"
         fi
         
         success=true
         break
      else
         echo "   ⚠️ Tentativo $attempt: La validazione è fallita. Ci sono errori nei dati estratti."
         echo "   Dettagli: $(cat $PATH_EXTRACTION_REPORT)"
         
         if [ $attempt -eq $max_attempts ]; then
            echo "   ❌ Falliti tutti i $max_attempts tentativi di estrazione per $new_filename.pdf"
            rm $PATH_EXTRACTION_REPORT
         else
            echo "   🔄 Riprovo con un altro tentativo tra qualche secondo..."
            sleep 20
         fi
      fi
   done
   
   if [ "$success" = true ]; then
      return 0
   else
      return 1
   fi
}



#-----------------requirements-----------------#
check_required_tools curl jq xq scrape llm mlr
echo "✅ Requirements satisfied!"



#----------------- main -----------------#
echo "🔎 Cerco nuovi dati sui volumi giornalieri..."

# funzione per estrarre gli href dai blocchi h3 a (anni/mesi)
extract_h3_links() {
   local page_url=$1
   curl -skL "$page_url" \
   | scrape -e "#it-block-field-blocknodegeneric-pagefield-p-body h3 a" 2>/dev/null \
   | grep -oE 'href="[^"]+"' | sed 's/^href="//;s/"$//'
}

# 1) tutti gli anni dalla pagina principale
year_urls=$(extract_h3_links "$URL")
echo "   Trovati $(echo "$year_urls" | grep -c .) link annuali"

# 2) per ogni anno, tutti i mesi
month_urls=""
for year_url in $year_urls; do
   m=$(extract_h3_links "$year_url")
   month_urls+="$m"$'\n'
done
month_urls=$(echo "$month_urls" | awk 'NF')
echo "   Trovati $(echo "$month_urls" | grep -c .) link mensili"

# 3) per ogni mese, tutti i PDF (con cache su disco per i mesi "chiusi")
#
# Strategia di caching:
# - I mesi del passato non vengono più aggiornati: salviamo la loro lista PDF
#   in $PATH_DIR_CACHE_MONTHS/<slug>.txt e la riusiamo nelle run successive.
# - Gli ultimi 2 mesi nell'ordine di iterazione (mese corrente + precedente)
#   vengono SEMPRE rifetchati: questo copre PDF caricati in ritardo dopo il
#   rollover del mese.
# - Al primo run la cache è vuota → tutti i mesi vengono fetchati e la cache
#   viene popolata. Dalla run successiva il discovery diventa quasi istantaneo.
# - I file di cache vengono committati dal workflow (sono piccoli txt) così
#   il beneficio si propaga tra esecuzioni in CI.
mkdir -p "$PATH_DIR_CACHE_MONTHS"

# ultimi 2 mesi nell'ordine pagina (= corrente + precedente, sempre rifetchati)
fresh_months=$(echo "$month_urls" | tail -n 2)

pdfs_list=""
n_cached=0; n_fetched=0
while IFS= read -r month_url; do
   [ -z "$month_url" ] && continue
   slug=$(basename "$month_url")
   cache_file="$PATH_DIR_CACHE_MONTHS/$slug.txt"

   if grep -qFx "$month_url" <<< "$fresh_months" || [ ! -s "$cache_file" ]; then
      echo "   ⬇️  fetch $slug..."
      # grep diretto sugli href .pdf: niente scrape+xq (Python startup × N mesi)
      month_pdfs=$(curl -skL "$month_url" | grep -oE 'href="[^"]+\.pdf"' | sed 's/^href="//;s/"$//' || true)
      if [ -n "$month_pdfs" ]; then
         echo "$month_pdfs" > "$cache_file"
      fi
      n_fetched=$((n_fetched+1))
   else
      month_pdfs=$(cat "$cache_file")
      n_cached=$((n_cached+1))
   fi

   if [ -n "$month_pdfs" ]; then
      pdfs_list+="$month_pdfs"$'\n'
   fi
done <<< "$month_urls"
pdfs_list=$(echo "$pdfs_list" | awk 'NF')
echo "   📦 Mesi da cache: $n_cached, da rete: $n_fetched"
echo "   Trovati $(echo "$pdfs_list" | grep -c .) PDF totali sul sito"

# create list of new pdfs
new_pdfs=$(compare_lists "$pdfs_list" "$PATH_PDFS_LIST") \
|| { echo "   ❌ Errore durante la ricerca dei nuovi file da processare."; exit 1; }

# ordina dal più recente al più vecchio (i path contengono /YYYY-MM/YYYY-MM-DD-...)
# così, se la quota AI si esaurisce a metà run, i PDF più recenti sono già processati.
new_pdfs=$(echo "$new_pdfs" | grep -v '^$' | sort -r)

# count new pdfs
n_pdfs=$(echo "$new_pdfs" | grep -v '^$' | wc -l)

# se ci sono nuovi pdf, processali. Altrimenti esci
if [ $n_pdfs -gt 0 ]; then
   echo "🆕 Ci sono $n_pdfs nuovi PDF da processare"
else
   echo "👋 Non ci sono nuovi PDF"
   exit 0
fi

# create an array with the new pdfs
mapfile -t pdfs_array <<< "$new_pdfs"

# inizializzo contatori
n_pdf=0; n_ai=0

# extract csv from pdfs; process each pdf
for line in "${pdfs_array[@]}"; do
   n_pdf=$((n_pdf+1))
   echo ""
   echo "📄 $n_pdf/$n_pdfs... Processo $line"
   
   # estraggo la data dal nome del PDF: regex deterministica (no AI per il
   # caso comune); LLM solo come fallback per pattern futuri non previsti.
   new_filename=$(normalize_pdf_date "$line") \
   || { echo "   ❌ Impossibile estrarre la data dal nome file '$line'. Skip."; continue; }
   
   # scarico il pdf e lo chiamo $new_filename
   curl -skL "$URL_HOMEPAGE$line" -o "./risorse/pdf/volumi-giornalieri/$new_filename.pdf"
   echo "   ⬇️  File scaricato e rinominato in $new_filename.pdf"
   
   # prova l'estrazione con massimo $N_ATTEMPTS tentativi
   set +e
   try_extraction "$new_filename" "$N_ATTEMPTS"
   extraction_rc=$?
   set -e

   if [ $extraction_rc -eq 0 ]; then
      # aggiungo il pdf alla lista dei pdf scaricati
      echo "$line" >> $PATH_PDFS_LIST
      echo "   📦 Aggiornata la lista dei PDF processati"
   elif [ $extraction_rc -eq 2 ]; then
      # quota giornaliera AI esaurita su entrambi i modelli: stop pulito
      echo "   🛑 Interrompo il processing dei PDF: riprenderò domani con quota fresca."
      echo "      (chiamate $LLM_MODEL_PRIMARY: $n_ai_primary, $LLM_MODEL_FALLBACK: $n_ai_fallback)"
      break
   else
      echo "   ❌ Fallimento nell'elaborazione del PDF $n_pdf. Passo al prossimo file."
   fi
   echo ""
done

echo ""
echo "📊 Riepilogo chiamate AI (key corrente #$((current_key_idx+1))/${#api_keys[@]}):"
echo "   $LLM_MODEL_PRIMARY: $n_ai_primary/$AI_RPD_LIMIT"
echo "   $LLM_MODEL_FALLBACK: $n_ai_fallback/$AI_RPD_LIMIT"

# if temp folder exists
if [ -d "./risorse/tmp" ]; then

   # aggiorna lo storico
   # order by date
   # rimuovi righe senza volumi
   # remove duplicates
   mlr --csv cat $PATH_DIR_VOLUMI_GIORNALIERI/*.csv \
   | mlr --csv put '$date_key = strptime($data, "%Y-%m-%d")' then \
   sort -nr date_key then \
   cut -x -f date_key then \
   filter -S '$volume != ""' then \
   uniq -a  > all.csv
   mv all.csv $PATH_CSV_VOLUMI_GIORNALIERI
   echo "🔄 Aggiornato storico $(basename $PATH_CSV_VOLUMI_GIORNALIERI)"

   # check 3
   n_cod_name_concatenated=$(< $PATH_CSV_VOLUMI_GIORNALIERI mlr --csv --headerless-csv-output put '$concatenated = $cod . $diga' then cut -f concatenated then uniq -a | wc -l)
   n_cod=$(< $PATH_CSV_VOLUMI_GIORNALIERI mlr --csv --headerless-csv-output cut -f cod then uniq -a | wc -l)

   # check if n_cod_name_concatenated and n_cod are equal, if not, display an error message and exit
   if [ $n_cod_name_concatenated -ne $n_cod ]; then
      echo "❌ Check 3 failed: il numero di codici univoci non corrisponde al numero di codici concatenati con i nomi delle dighe!"
      echo "Questo vuol dire che i nomi delle dighe NON sono stati assegnati correttamente ai codici secondo l'anagrafica."
      echo "È necessaria una verifica manuale. Revisionare il file di dati."
      exit 1
   else
      echo "✅ Check 3 passed: I nomi delle dighe sono stati assegnati correttamente ai codici secondo l'anagrafica"
   fi

   # temp folder
   rm -r "./risorse/tmp"
fi

echo ""
echo "🚀 Tutto fatto, bye!"
exit 0

# multisort
# mlr --csv sort -nr volume -f cod ./risorse/sicilia_dighe_volumi_latest.csv
