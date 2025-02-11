#!/bin/bash

# ------------------------------------------------------------------------------------------#
# Questo script apre il sito della Regione Sicilia e controlla la presenza di nuovi 
# documenti PDF contenenti # dati sui volumi invasati dalle dighe siciliane con aggiornamento 
# mensile. Se trova nuovi PDF, li scarica e li converte in CSV sfruttando un LLM. 
#
# Istruzioni: Si consiglia di lanciare questo script tramite il launcher.sh
#
# To do:
# - [ ] implementare la scelta del modello llm in fase di lancio (far scegliere 2 modelli)
# - [ ] cambiare nome di compare_lists() in find_new_pdfs()
# - [ ] rimuovere verifica requirements e lasciarla gestire al launcher
# - [ ] migliorare il main creando funzioni
# - [ ] staccare le funzioni in un file a parte
# ------------------------------------------------------------------------------------------#


set -e
#set -x


#-----------------requirements-----------------#
# check if required commands are installed: jq xq (yq), scrape-cli, llm, mlr
for cmd in curl jq xq scrape llm mlr; do
   if ! command -v $cmd &> /dev/null; then
      echo "❌ Errore: $cmd non è installato."
      exit 1
   fi
done
echo "✅ Requirements satisfied!"


#-----------------constants-----------------#
URL="https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/monitoraggio-giornaliero-invasi-ad-uso-potabile"
PATH_PDFS_LIST="./risorse/processed-urls/pdfs_list_volumi_giornalieri.txt"
PATH_DIR_VOLUMI_GIORNALIERI="./risorse/volumi-giornalieri"
PATH_CSV_VOLUMI_GIORNALIERI="./risorse/sicilia_dighe_volumi_giornalieri.csv"
PATH_CSV_VOLUMI_GIORNALIERI_LATEST="./risorse/sicilia_dighe_volumi_giornalieri_latest.csv"
PATH_MSG_TELEGRAM="./risorse/msgs/new_volumi_giornalieri.md"
PATH_EXTRACTION_REPORT="./risorse/report/extraction_giornalieri_latest.json"
URL_HOMEPAGE="https://www.regione.sicilia.it"
URL_CSV_ANAGRAFICA_DIGHE="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main/risorse/sicilia_dighe_anagrafica.csv"
AI_LIMITS=15
AI_SLEEP=60


#----------------- functions -----------------#
check_limits() {
   # check if the number of requests to the AI has reached the limit
   # if so, wait AI_SLEEP seconds
   # inputs: none (uses global variables n_ai, AI_LIMITS, AI_SLEEP)
   # outputs: none
   if [ $n_ai -ge $AI_LIMITS ]; then
      echo "🚨 Superato il limite di richieste, attendo $AI_SLEEP secondi..."
      sleep $AI_SLEEP
      n_ai=0
   fi
}

generate_telegram_message() {
   # inputs:
   # $1 url_pdf
   # $2 path message will be saved

   local url_pdf=$1
   local path_msg=$2

   # crea messaggio da inviare su telegram
   echo "🔎 Ho trovato ed estratto *nuovi dati* sui *volumi* (giornalieri) invasati dalle dighe siciliane!

   🔄 In particolare ho convertito [questo file PDF]($url_pdf) in [questo file CSV](https://github.com/opendatasicilia/emergenza-idrica-sicilia/blob/main/risorse/sicilia_dighe_volumi_giornalieri_latest.csv) tramite [✨ Gemini AI](https://gemini.google.com/). 

   ✅ L'estrazione automatica ha superato alcuni sanity check, ma se trovi un errore [apri una issue](https://github.com/opendatasicilia/emergenza-idrica-sicilia/issues/new?template=Blank+issue). Grazie!

   Se vuoi saperne di più sui dati estratti da ODS nell'ambito di questo progetto, puoi visitare [questa pagina](https://github.com/opendatasicilia/emergenza-idrica-sicilia/tree/main/risorse#dati-sugli-invasi-delle-dighe-e-sulle-riduzioni-idriche-in-sicilia).

   _Questo è un messaggio automatico gestito da un_ [workflow di GitHub](https://github.com/opendatasicilia/emergenza-idrica-sicilia/blob/main/.github/workflows/new_pdfs.yaml)" > $path_msg
}

compare_lists() {
   # inputs:
   # $1: variable name of the first list
   # $2: path of the second list (file)

   # output: string (stdout)

   local list1=$1
   local list2=$2
   local new_pdfs=""

   for file in $list1; do
      if ! grep -q "$file" "$list2"; then
         # Aggiungi il file alla lista dei nuovi PDF (con una nuova riga)
         new_pdfs+="$file"$'\n'
      fi
   done

   # Rimuovi eventuali righe vuote
   echo -e "$new_pdfs" | awk 'NF' 
}

normalize_filename() {
   # inputs
   # $1: old_name (e.g. "Verbale del 2021-06-30.pdf")
   # $2: format   (e.g. "verbale_YYYY-MM-DD")
   # output: string
   # description:
   #    normalizza il nome di un file pdf in base a un formato specificato.

   local old_name=$1
   local format=$2

   llm_response=$(echo "$old_name" | llm -m gemini-1.5-flash-latest \
   -s "Converti il nome di questo file nel formato '$format' tutto minuscolo. Restituisci in output una sola riga senza estensione") \
   || { echo "❌ Errore durante l'esecuzione di llm (normalizzazione nome file)"; return 1; }

   echo "$llm_response" | tr -d '\n'
}


#----------------- main -----------------#
echo "🔎 Cerco nuovi dati sui volumi giornalieri..."

# dalla pagina con l'elenco degli anni seleziono il link all'ultimo anno
url_page_with_list_1=$(curl -skL $URL | scrape -e "#it-block-field-blocknodegeneric-pagefield-p-body h3:last-of-type a:last-of-type" | xq -r '.a."@href"')

# dalla pagina con l'elenco dei mesi seleziono il link all'ultimo mese
url_page_with_list_2=$(curl -skL $url_page_with_list_1 | scrape -be "#it-block-field-blocknodegeneric-pagefield-p-body a:last-of-type" | xq -r '.html.body.a[-1]."@href"')

# dalla pagina con l'elenco dei pdf dell'ultimo mese seleziono i link ai pdf
pdfs_list=$(curl -skL "$url_page_with_list_2" | scrape -be "a" | xq -r '.html.body.a[]."@href"' | grep ".pdf")

# list of new pdfs
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

# check pdfs_list contains pdfs that are not in file pdfs_list_volumi.txt
for line in "${pdfs_array[@]}"; do
   n_pdf=$((n_pdf+1))
   echo ""
   echo "📄 $n_pdf/$n_pdfs... Processo $line"

   # converto il nome del pdf YYYY-MM-DD.pdf tramite ai llm
   check_limits
   new_filename=$(normalize_filename "$line" "YYYY-MM-DD") \
   || { echo "   ❌ Errore durante la normalizzazione del nome del file $n_pdf."; exit 1; }
   n_ai=$((n_ai+1))

   # scarico il pdf e lo chiamo new_filename
   curl -skL "$URL_HOMEPAGE$line" -o "./risorse/pdf/volumi-giornalieri/$new_filename.pdf"
   echo "   ⬇️  File scaricato e rinominato in $new_filename.pdf"

   echo "   🔄 Converto in CSV..."
   
   # creo (se non esiste già) la cartella per i csv temporanei
   mkdir -p ./risorse/tmp

   # FIRST EXTRACTION (with anagrafica)
   system_prompt="Il tuo compito è quello di estrarre dati da un pdf allegato e di incrociarli con i dati di un'anagrafica csv passata come prompt. Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna invaso (chiamala 'diga_pdf') e quelli della colonne relative alla quota autorizzata, volume autorizzato, quota, volume, volume utile netto per utilizzatori (chiamale rispettivamente: quota_autorizzata, volume_autorizzato, quota, volume, volume_utile). Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. Dal CSV, estrai la colonna 'diga' che chiamerai 'diga_anagrafica' popolata con il nome corretto (da includere esattamente nell'output). Confronta le colonne 'diga_pdf' e 'diga_anagrafica' per fare in modo di arricchire il dataset e assegnare a ogni diga il corrispondente codice identificativo presente nella colonna 'cod' del csv. Talvolta è presente una diga chiamata ogliastro che coincide don sturzo; se questa diga non è presente nel pdf, non la includere nel tuo output. In ultimo, cestina la colonna 'diga_pdf' e  nell'output includi i valori di 'diga_anagrafica' sotto il nome di 'diga'. Attenzione ad attribuire correttamente il codice al nome della diga secondo l'anagrafica csv. Se l'anagrafica csv contiene più dighe della tabella pdf, l'output deve contenere solo ed esclusivamente le dighe presenti nel file pdf. L'output deve avere questa struttura 'cod,diga,data,quota_autorizzata,volume_autorizzato,quota,volume,volume_utile' e non deve avere righe vuote finali. Tieni presente che i valori di 'diga' devono essere esattamente coincidenti con quelli di 'diga_anagrafica'. I separatori di decimali dei volumi devono essere i punti e non le virgole (correggi la sintassi dei numeri da formato italiano a formato internazionale). Se l'output csv contiene righe finali senza valori, rimuovile."

   check_limits
   llm_response=$(cat risorse/sicilia_dighe_anagrafica.csv | llm -x \
   -m gemini-2.0-flash-exp \
   -s "$system_prompt" \
   -a "./risorse/pdf/volumi-giornalieri/$new_filename.pdf" \
   -o temperature 0.1) \
   || { echo "   ❌ Errore durante l'esecuzione di llm (operazione di estrazione dati)"; exit 1; }
   n_ai=$((n_ai+1))

   # rimuovo eventuali righe vuote finali e salvo il csv
   echo "$llm_response" \
   | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' \
   | mlr --csv filter '$volume != ""' then clean-whitespace then skip-trivial-records > ./risorse/tmp/$new_filename.csv
   echo "   🟢 Prima conversione da $new_filename.pdf in $new_filename.csv completata"

   # count rows (dams) in the first extraction
   n_dighe_ai_1=$(mlr --csv --headerless-csv-output cat -n then stats1 -a max -f n ./risorse/tmp/$new_filename.csv)
   echo "   Numero di righe (dighe) prima estrazione: $n_dighe_ai_1"
      
   # SECOND EXTRACTION (without anagrafica)
   echo "   💬 Double check: eseguo estrazione senza anagrafica..."

   system_prompt="Il tuo compito è quello di estrarre dati da un pdf allegato. Devi fornire un output in csv senza backtics iniziali e finali."

   prompt="Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna invaso e quelli della colonne relative alla quota autorizzata, volume autorizzato, quota, volume, volume utile netto per utilizzatori (chiamale rispettivamente: quota_autorizzata, volume_autorizzato, quota, volume, volume_utile). Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. L'output deve avere questa struttura 'cod,diga,data,quota_autorizzata,volume_autorizzato,quota,volume,volume_utile' e non deve avere righe vuote finali. I separatori di decimali dei volumi devono essere i punti e non le virgole (correggi la sintassi dei numeri da formato italiano a formato internazionale). Se l'output csv contiene righe finali senza valori, rimuovile."

   check_limits
   llm_response=$(llm -x \
   -m gemini-2.0-flash \
   -s "$system_prompt" \
   "$prompt" \
   -a "./risorse/pdf/volumi-giornalieri/$new_filename.pdf" \
   -o temperature 0.1) \
   || { echo "   ❌ Errore durante l'esecuzione di llm (operazione di estrazione dati)"; exit 1; }
   n_ai=$((n_ai+1))

   # rimuovo eventuali righe vuote finali, pulisco e salvo il csv
   echo "$llm_response" \
   | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' \
   | mlr --csv filter '$volume != ""' then clean-whitespace then skip-trivial-records > ./risorse/tmp/2_$new_filename.csv
   echo "   🟢 Conversione da $new_filename.pdf in 2_$new_filename.csv completata"

   # count rows (dams) in the second extraction
   n_dighe_ai_2=$(mlr --csv --headerless-csv-output cat -n then stats1 -a max -f n ./risorse/tmp/2_$new_filename.csv)
   echo "   Numero di righe (dighe) seconda estrazione: $n_dighe_ai_2"

   # check 1
   # check if n_dighe_ai_1 and n_dighe_ai_2 are equal, if not, display an error message
   if [ $n_dighe_ai_1 -ne $n_dighe_ai_2 ]; then
      echo "   ⚠️ Check 1 failed: il numero di righe estratte dai due metodi non corrisponde!"
      echo "   Sarebbe necessaria una verifica manuale: revisionare il file di anagrafica e il file di dati. Provo a condurre una verifica automatica tramite AI."
   else
      echo "   ✅ Check 1 passed: Il numero di dighe estratte dai due metodi corrisponde."
   fi
      
   # COMPARE 1st and 2nd extraction
   echo "   🔍 Confronto i due file csv e individuo errori di estrazione..."

   system_prompt="Il tuo compito è quello di confrontare due file csv e comprenderne le differenze"

   prompt="Ti inserisco di seguito due csv. Forse uno di questi (il secondo) è probabile che abbia delle dighe in più che nell'altro (primo) non sono censite. Fammi un piccolo report di validazione sintetico in json. Il json deve contenere la key 'valid' che può contenere il valore true o false. Se tra i due file csv ci sono discrepanze nel numero di righe o discrepanze nel valore dei volumi allora il report è invalido e la key valid deve contenere il valore false. Nel report includi pure i dettagli sulle dighe mancanti nel primo file e sulle discrepanze dei valori dei volumi. Includi pure una sezione dedicata alla somiglianza dei nomi delle dighe: questo non inficia la validità ( esempio: Se non ci sono discrepanze nel numero di dighe, non ci sono discrepanze sui valori dei volumi, ci sono alcuni nomi di dighe simili, allora il report è valido). Fai attenzione alle dighe che hanno nomi simili: ad esempio 'leone' e 'piano del leone' indicano la stessa diga. Il file json deve avere le key: valid, missing_dams, different_volms, similar_dams. Il primo csv (prima estrazione) è il seguente: $(cat ./risorse/tmp/$new_filename.csv). Il secondo csv (seconda estrazione) è il seguente: $(cat ./risorse/tmp/2_$new_filename.csv)"

   check_limits
   llm_response=$(llm -m gemini-2.0-flash \
   -s "$system_prompt" \
   "$prompt" \
   -o json_object 1) \
   || { echo "❌ Errore durante l'esecuzione di llm (operazione di confronto dati)"; exit 1; }
   n_ai=$((n_ai+1))

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
      mkdir -p ./risorse/msgs
      generate_telegram_message $URL_HOMEPAGE$line $PATH_MSG_TELEGRAM

      # copio il csv generato nella cartella dei volumi giornalieri
      mkdir -p ./risorse/volumi-giornalieri
      #date_filename=$(echo $new_filename | sed 's/^volumi_giornalieri_//')
      cp ./risorse/tmp/$new_filename.csv ./risorse/volumi-giornalieri/$new_filename.csv

      # aggiorno il csv latest dei volumi giornalieri 
      cp ./risorse/tmp/$new_filename.csv $PATH_CSV_VOLUMI_GIORNALIERI_LATEST
      echo "   🔄 Aggiornato $(basename $PATH_CSV_VOLUMI_GIORNALIERI_LATEST)"
   else
      echo "   ❌ Check 2 failed: la validazione è fallita. Ci sono errori nei dati estratti: potrebbero esserci errori nei nomi delle dighe o nei valori dei volumi."
      echo "Consulta il report per maggiori dettagli: $PATH_EXTRACTION_REPORT"
      < $PATH_EXTRACTION_REPORT jq '.'
      # qui si potrebbe aggiungere un ulteriore tentativo di correzione tramite AI #
      exit 1
   fi

   # aggiungo il pdf alla lista dei pdf scaricati
   echo "$line" >> $PATH_PDFS_LIST
   echo "   📦 Aggiornata la lista dei PDF processati"
   echo ""
done

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