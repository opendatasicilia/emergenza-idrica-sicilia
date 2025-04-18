#!/bin/bash

# ------------------------------------------------------------------------------------------#
# Questo script apre il sito della Regione Sicilia e controlla la presenza di 
# nuovi documenti PDF contenenti dati sui volumi invasati dalle dighe siciliane
# con aggiornamento mensile. Se trova nuovi PDF, li scarica e li converte in CSV 
# sfruttando un LLM. 
#
# To do:
# - [x] implementare gestione array (vd. estrazione giornaliera)
# - [ ] gestire merging (aggiornamento storico) e aggiornamento latest
# - [ ] testare esecuzione su multipli pdf
# - [ ] pulire i csv dopo ogni singola estrazione (vd. estrazione giornaliera)
# - [ ] migliorare la gestione degli errori (vd. estrazione giornaliera)
# ------------------------------------------------------------------------------------------#



set -e
set -u
# set -x



#-----------------constants-----------------#
# PATH_DIR_VOLUMI_MENSILI="./risorse/volumi-mensili" non esiste. Bisogna crearla?
readonly URL="https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/siti-tematici/risorse-idriche/volumi-invasati-nelle-dighe-della-sicilia"
readonly PATH_PDFS_LIST="./risorse/processed-urls/pdfs_list_volumi_mensili.txt"
readonly URL_HOMEPAGE="https://www.regione.sicilia.it"
readonly URL_CSV_ANAGRAFICA_DIGHE="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main/risorse/sicilia_dighe_anagrafica.csv"
readonly PATH_CSV_VOLUMI_MENSILI="./risorse/sicilia_dighe_volumi.csv"
readonly PATH_CSV_VOLUMI_MENSILI_LATEST="./risorse/sicilia_dighe_volumi_latest.csv"
readonly PATH_MSG_TELEGRAM="./risorse/msgs/new_volumi_mensili.md"
readonly PATH_EXTRACTION_REPORT="./risorse/report/extraction_mensili_latest.json"
readonly AI_RPM=10
readonly AI_SLEEP=60
readonly LLM_MODEL_LITE="gemini-2.0-flash-lite"
readonly LLM_MODEL_EXTRACTION="gemini-2.0-flash"
readonly LLM_MODEL_COMPARISON="gemini-2.0-flash"
readonly N_ATTEMPTS=3



#----------------- functions -----------------#
source ./scripts/functions.sh

generate_telegram_message() {
   # inputs:
   # $1 url_pdf
   # $2 path message will be saved

   local url_pdf=$1
   local path_msg=$2

   # crea messaggio da inviare su telegram
   echo "🔎 Ho trovato ed estratto *nuovi dati* sui *volumi* (mensili) invasati dalle dighe siciliane!

🔄 In particolare ho convertito [questo file PDF]($url_pdf) in [questo file CSV](https://github.com/opendatasicilia/emergenza-idrica-sicilia/blob/main/risorse/sicilia_dighe_volumi_latest.csv) tramite [✨ Gemini AI](https://gemini.google.com/). 

✅ L'estrazione automatica ha superato alcuni sanity check, ma se trovi un errore [apri una issue](https://github.com/opendatasicilia/emergenza-idrica-sicilia/issues). Grazie!

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
      system_prompt="Il tuo compito è quello di estrarre dati da un pdf allegato e di incrociarli con i dati di un'anagrafica csv passata come prompt. Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna diga (chiamala 'diga_pdf') e quelli della colonna relativa al volume registrato nel mese più recente. Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. Dal CSV, estrai la colonna 'diga' che chiamerai 'diga_anagrafica' popolata con il nome corretto (da includere esattamente nell'output). Confronta le colonne 'diga_pdf' e 'diga_anagrafica' per fare in modo di arricchire il dataset e assegnare a ogni diga il corrispondente codice identificativo presente nella colonna 'cod' del csv. Talvolta è presente una diga chiamata ogliastro che coincide don sturzo; se questa diga non è presente nel pdf, non la includere nel tuo output. Assicurati di estrarre correttamente i dati relativi a tutte le dighe presenti nel pdf. Se il PDF contiene la diga castello, assicurati di estrarre i dati anche di questa diga. In ultimo, cestina la colonna 'diga_pdf' e  nell'output includi i valori di 'diga_anagrafica' sotto il nome di 'diga'. Attenzione ad attribuire correttamente il codice al nome della diga secondo l'anagrafica csv. Se l'anagrafica csv contiene più dighe della tabella pdf, l'output deve contenere solo ed esclusivamente le dighe presenti nel file pdf. L'output deve avere questa struttura 'cod,diga,data,volume' e non deve avere righe vuote finali. Tieni presente che i valori di 'diga' devono essere esattamente coincidenti con quelli di 'diga_anagrafica'. I separatori di decimali dei volumi devono essere i punti e non le virgole. Se l'output csv contiene righe finali senza valori, rimuovile."

      check_limits $AI_RPM $AI_SLEEP
      llm_response=$(cat risorse/sicilia_dighe_anagrafica.csv | \
      llm -x \
      -m "$LLM_MODEL_EXTRACTION" \
      -s "$system_prompt" \
      -a "./risorse/pdf/volumi-mensili/$new_filename.pdf" \
      -o temperature 0.1) \
      || { echo "   ❌ Errore durante l'esecuzione di llm (operazione di estrazione dati pdf)"; exit 1; }
      n_ai=$((n_ai+1))

      # rimuovo righe vuote finali e salvo il csv
      remove_trailing_empty_lines "$llm_response" > "./risorse/tmp/$new_filename.csv" \
      || { echo "   ❌ Failed to process LLM response"; exit 1; }

      echo "   🟢 Prima conversione da $new_filename.pdf in $new_filename.csv completata"
      
      # count rows (dams) in the first extraction
      n_dighe_ai_1=$(mlr --csv --headerless-csv-output cat -n then stats1 -a max -f n ./risorse/tmp/$new_filename.csv)
      echo "   Numero di righe (dighe) prima estrazione: $n_dighe_ai_1"
      
      # SECOND EXTRACTION (without anagrafica)
      echo "   💬 Double check: eseguo estrazione senza anagrafica..."

      system_prompt="Il tuo compito è quello di estrarre dati da un pdf allegato."
      prompt="Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna diga e quelli della colonna relativa al volume registrato nel mese più recente. Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. L'output deve avere questa struttura 'diga,data,volume' e non deve avere righe vuote finali. I separatori di decimali dei volumi devono essere i punti e non le virgole (correggi la sintassi dei numeri da formato italiano a formato internazionale). L'output non deve contenere righe vuote alla fine. Se l'output csv contiene righe finali senza valori, rimuovile."

      check_limits $AI_RPM $AI_SLEEP
      llm_response=$(llm -x \
      -m "$LLM_MODEL_EXTRACTION" \
      -s "$system_prompt" \
      "$prompt" \
      -a "./risorse/pdf/volumi-mensili/$new_filename.pdf" \
      -o temperature 0.1) \
      || { echo "   ❌ Errore durante l'esecuzione di llm (operazione di seconda estrazione dati pdf)"; exit 1; }
      n_ai=$((n_ai+1))
      
      # rimuovo righe vuote finali e salvo il csv
      remove_trailing_empty_lines "$llm_response" > ./risorse/tmp/2_$new_filename.csv
      echo "   🟢 Conversione da $new_filename.pdf in 2_$new_filename.csv completata"

      # count rows (dams) in the second extraction
      n_dighe_ai_2=$(mlr --csv --headerless-csv-output cat -n then stats1 -a max -f n ./risorse/tmp/2_$new_filename.csv)
      echo "   Numero di righe (dighe) seconda estrazione: $n_dighe_ai_2"

      # check 1
      # check if n_dighe_ai_1 and n_dighe_ai_2 are equal, if not, display an error message
      if [ $n_dighe_ai_1 -ne $n_dighe_ai_2 ]; then
         echo "   ❌ Check 1 failed: il numero di righe estratte dai due metodi non corrisponde!"
         echo "   Provo a verificare l'errore tramite un confronto dei dati sfruttando l'AI..."
      else
         echo "   ✅ Check 1 passed: Il numero di dighe estratte dai due metodi corrisponde."
      fi
      
      # COMPARE 1st and 2nd extraction
      echo "   🔍 Confronto i due file csv e individuo errori di estrazione..."

      system_prompt="Il tuo compito è quello di confrontare due file CSV contententi dati relativi a dighe e volumi. Devi comprenderne le differenze. Se due dighe hanno nomi simili ma diversi, non è un problema. Concentrati sul confronto dei valori numerici."
      
      prompt="Ti inserisco di seguito due CSV. Il secondo CSV è probabile che abbia delle dighe in più che nel primo file non sono censite. Fammi un piccolo report di validazione sintetico in json con due chiavi. Il json deve contenere le key 'valid' (booleana) e 'summary'. La key 'summary' deve contenere il motivo discorsivo del perchè il confronto è fallito (se è fallito). Se tra i due file csv ci sono discrepanze nel numero di righe o discrepanze nel valore dei volumi allora il report è invalido e la key 'valid' deve contenere il valore false. Nel report includi pure i dettagli sulle eventuali dighe mancanti nel primo file e sulle discrepanze dei valori dei volumi. Includi pure una sezione dedicata alla somiglianza dei nomi delle dighe. Se due dighe presentano nomi diversi ma simili, non è un errore. La presenza di nomi diversi ma simili non inficia la validità ( esempio: Se non ci sono discrepanze nel numero di dighe, non ci sono discrepanze sui valori dei volumi, ci sono alcuni nomi di dighe simili, allora il report è valido). Di seguito ti riporto esempi di dighe con nomi simili: 'leone' e 'piano del leone' indicano la stessa diga e non è un errore il fatto che abbiano nomi diversi ma simili. Assicurati di non considerare come errore le discrepanze nei nomi delle dighe. Il primo csv (prima estrazione) è il seguente: <primo_csv> $(cat ./risorse/tmp/$new_filename.csv) <\primo_csv>. Il secondo csv (seconda estrazione) è il seguente: <secondo_csv> $(cat ./risorse/tmp/2_$new_filename.csv) <\secondo_csv>"

      check_limits $AI_RPM $AI_SLEEP
      llm_response=$(llm -x \
      -m "$LLM_MODEL_COMPARISON" \
      -s "$system_prompt" \
      "$prompt" \
      -o json_object 1 \
      -o temperature 0.11) \
      || { echo "   ❌ Errore durante l'esecuzione di llm (operazione di confronto csv)"; exit 1; }
      n_ai=$((n_ai+1))
      
      # save report
      echo "$llm_response" > $PATH_EXTRACTION_REPORT

      # add date to report
      jq '. + {"date": "'$(date +%Y-%m-%d)'"}' $PATH_EXTRACTION_REPORT > $PATH_EXTRACTION_REPORT.tmp && mv $PATH_EXTRACTION_REPORT.tmp $PATH_EXTRACTION_REPORT

      # check 2
      report_validity=$(< $PATH_EXTRACTION_REPORT jq '.valid')
      if [ "$report_validity" == "true" ]; then
         echo "   ✅ Check 2 passed: La validazione non ha riscontrato errori nei dati estratti (nomi dighe e valori volumi)"
         rm ./risorse/tmp/2_$new_filename.csv

         # creo messaggio da inviare su telegram
         mkdir -p ./risorse/msgs
         generate_telegram_message $URL_HOMEPAGE$line $PATH_MSG_TELEGRAM

         success=true
         break
      else
         echo "   ❌ Tentativo $attempt: La validazione è fallita. Ci sono errori nei dati estratti."
         echo "   Dettagli: $(< $PATH_EXTRACTION_REPORT jq -r '.summary')"
         
         if [ $attempt -eq $max_attempts ]; then
            echo "   ⚠️ Falliti tutti i $max_attempts tentativi di estrazione per $new_filename.pdf"
            echo "   Consulta il report completo per maggiori dettagli: $PATH_EXTRACTION_REPORT"
            < $PATH_EXTRACTION_REPORT jq '.'
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
# obtain the last page with pdfs list
url_page_with_list=$(curl -skL $URL | scrape -e "#it-block-field-blocknodegeneric-pagefield-p-body li:last-of-type a:last-of-type" | xq -r '.a."@href"')

# dalla pagina con l'elenco dei pdf dell'ultimo mese seleziono i link ai pdf
pdfs_list=$(curl -skL $url_page_with_list | scrape -be "a" | xq -r '.html.body.a[]."@href"' | grep ".pdf")

# check if pdfs_list is empty
if [ -z "$pdfs_list" ]; then
   echo "❌ Errore: non sono stati trovati PDF nella pagina web."
   exit 1
fi

# list of new pdfs if pdfs_list is not empty
new_pdfs=$(compare_lists "$pdfs_list" "$PATH_PDFS_LIST") \
|| { echo "   ❌ Errore durante la ricerca dei nuovi file da processare."; exit 1; }

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

   # converto il nome del pdf in volumi_YYYY-MM (privo di estensione) tramite ai llm
   # non posso usare funzione normalize_filename perchè è necessaria distinzione tra tabella e grafici
   system_prompt="converti il nome di questo file pdf nel formato volumi_YYYY-MM (senza estensione) se si tratta di una tabella, oppure grafici_YYYY-MM (senza estensione) se invece si tratta di grafici. Restituisci in output una sola riga"

   new_filename=$(echo "$line" | llm -m "$LLM_MODEL_LITE" -s "$system_prompt") \
   || { echo "❌ Errore durante la normalizzazione del nome del file)"; exit 1; }
   echo "✏️  Filename normalizzato: $new_filename"
   
   # check if new_filename start with "volumi", in caso scarico ed estraggo csv. Se contiene "grafici" scarico e stop
   if [[ $new_filename == volumi* ]]; then

      # scarico il pdf e lo chiamo new_filename
      curl -skL "$URL_HOMEPAGE$line" -o "./risorse/pdf/volumi-mensili/$new_filename.pdf"
      echo "⬇️  Scaricato $new_filename.pdf"

      echo "🔄 $new_filename.pdf è un PDF di volumi. Converto in CSV..."
      
      # creo (se non esiste già) la cartella per i csv temporanei
      mkdir -p ./risorse/tmp

      # prova l'estrazione con massimo $N_ATTEMPTS tentativi
      if ! try_extraction "$new_filename" "$N_ATTEMPTS"; then
         echo "   ❌ Fallimento nell'elaborazione del PDF $n_pdf. Passo al prossimo file."
      else
         # aggiungo il pdf alla lista dei pdf scaricati
         echo "$line" >> $PATH_PDFS_LIST
         echo "   📦 Aggiornata la lista dei PDF processati"
      fi
      echo ""
      

   elif [[ $new_filename == grafici* ]]; then

      # scarico il pdf e lo chiamo new_filename
      curl -skL "$URL_HOMEPAGE$line" -o "./risorse/pdf/grafici-mensili/$new_filename.pdf"
      echo "⬇️  Scaricato $new_filename.pdf"
   fi

   # aggiungo il pdf alla lista dei pdf scaricati
   echo "$line" >> $PATH_PDFS_LIST
done

# if temp folder exists
if [ -d "./risorse/tmp" ]; then
   # merge csv data (se ne esistono più di uno)
   # attenzione: può capitare che il csv latest contenga i valori relativi a più date

   # controllo se ci sono csv
   if compgen -G "./risorse/tmp/*.csv" > /dev/null; then
      mlr --csv cat ./risorse/tmp/*.csv > $PATH_CSV_VOLUMI_MENSILI_LATEST
      echo ""
      echo "🔄 Aggiornato $(basename $PATH_CSV_VOLUMI_MENSILI_LATEST)"

      # add to storico
      # order by date
      # rimuovi righe senza volumi
      # remove duplicates
      mlr --csv cat $PATH_CSV_VOLUMI_MENSILI_LATEST $PATH_CSV_VOLUMI_MENSILI \
      | mlr --csv put '$date_key = strptime($data, "%Y-%m-%d")' then \
      sort -nr date_key then \
      cut -x -f date_key then \
      filter -S '$volume != ""' then \
      uniq -a  > all.csv
      mv all.csv $PATH_CSV_VOLUMI_MENSILI
      echo "🔄 Aggiornato storico $(basename $PATH_CSV_VOLUMI_MENSILI)"

      # check 3
      n_cod_name_concatenated=$(< $PATH_CSV_VOLUMI_MENSILI mlr --csv --headerless-csv-output put '$concatenated = $cod . $diga' then cut -f concatenated then uniq -a | wc -l)
      n_cod=$(< $PATH_CSV_VOLUMI_MENSILI mlr --csv --headerless-csv-output cut -f cod then uniq -a | wc -l)

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
fi

echo "📍 Fine, bye!"

# multisort
# mlr --csv sort -nr volume -f cod $PATH_CSV_VOLUMI_MENSILI_LATEST