#!/bin/bash


# Questo script apre il sito della Regione Sicilia e controlla la presenza di nuovi documenti PDF contenenti
# dati sui volumi invasati dalle dighe siciliane. Se trova nuovi PDF, li scarica e li converte in CSV sfruttando un llm. 


set -e
# set -x


# requirements
# xq (yq), scrape-cli, llm, mlr frictionless
# check if required commands are installed
for cmd in curl xq scrape llm mlr frictionless; do
   if ! command -v $cmd &> /dev/null; then
      echo "❌ Errore: $cmd non è installato."
      exit 1
   fi
done
echo "✅ Requirements satisfied!"


# constants
URL="https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/siti-tematici/risorse-idriche/volumi-invasati-nelle-dighe-della-sicilia"
PATH_PDFS_LIST="./risorse/pdfs_list.txt"
URL_HOMEPAGE="https://www.regione.sicilia.it"
URL_CSV_ANAGRAFICA_DIGHE="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main/risorse/sicilia_dighe_anagrafica.csv"
AI_LIMITS=2
AI_SLEEP=60


# functions
# creo funzione "check limits" che controlla se il numero di richieste ai "n_ai" supera un certo limite e in caso mette in pausa il processo per un certo tempo. la funzione deve accettare come argomenti il numero di richieste variabile "n_ai" e e le seguenti costanti: il limite "AI_LIMITS" e il tempo di pausa "AI_SLEEP"
check_limits() {
   if [ $n_ai -ge $AI_LIMITS ]; then
      echo "🚨 Superato il limite di richieste, attendo $AI_SLEEP secondi..."
      sleep $AI_SLEEP
      n_ai=0
   fi
}


# obtain the last page with pdfs list
url_page_with_list=$(curl -skL $URL | scrape -e "#it-block-field-blocknodegeneric-pagefield-p-body li:last-of-type a:last-of-type" | xq -r '.a."@href"')

pdfs_list=$(curl -skL $url_page_with_list | scrape -be "a" | xq -r '.html.body.a[]."@href"' | grep ".pdf")

# inizializzo contatori
n_pdf=0; n_ai=0

# check pdfs_list contains pdfs that are not in file pdfs_list.txt
while read -r line; do
   if ! grep -q "$line" $PATH_PDFS_LIST; then

      echo "🆕 $line è un nuovo file PDF"
   
      # converto il nome del pdf in volumi_YYYY-MM.pdf tramite ai llm
      check_limits
      new_filename=$(echo "$line" | llm -m gemini-1.5-pro-latest -s "converti il nome di questo file pdf nel formato volumi_YYYY-MM.pdf se si tratta di una tabella, oppure grafici_YYYY-MM.pdf se invece si tratta di grafici. Restituisci in output una sola riga" | tr -d '\n')
      echo "✏️  File rinominato in $new_filename"
      n_ai=$((n_ai+1))
      

      # check if new_filename start with "volumi", in caso scarico ed estraggo csv. Se contiene "grafici" scarico e stop
      if [[ $new_filename == volumi* ]]; then

         # scarico il pdf e lo chiamo new_filename
         curl -skL "$URL_HOMEPAGE$line" -o "./risorse/pdf/Tabelle/$new_filename"
         echo "⬇️  Scaricato $new_filename"

         echo "🔄 $new_filename è un PDF di volumi. Converto in CSV..."
         
         # creo (se non esiste già) la cartella per i csv temporanei
         mkdir -p ./risorse/tmp

         # extract csv data
         check_limits
         cat risorse/sicilia_dighe_anagrafica.csv | llm -m gemini-1.5-pro-latest -s "Il tuo compito è quello di estrarre dati da un pdf allegato e di incrociarli con i dati di un'anagrafica csv passata come prompt. Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna diga (chiamala 'diga_pdf') e quelli della colonna relativa al volume registrato nel mese più recente. Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. Dal CSV, estrai la colonna 'diga' che chiamerai 'diga_anagrafica' popolata con il nome corretto (da includere esattamente nell'output). Confronta le colonne 'diga_pdf' e 'diga_anagrafica' per fare in modo di arricchire il dataset e assegnare a ogni diga il corrispondente codice identificativo presente nella colonna 'cod' del csv. Attenzione alla diga ogliastro e don sturzo che sono la stessa cosa. In ultimo, cestina la colonna 'diga_pdf' e  nell'output includi i valori di 'diga_anagrafica' sotto il nome di 'diga'. Attenzione ad attribuire correttamente il codice al nome della diga secondo l'anagrafica csv. Se l'anagrafica csv contiene più dighe della tabella pdf, l'output deve contenere solo ed esclusivamente le dighe presenti nel file pdf. Se nell'anagrafica ci sono più dighe del pdf, il volume non deve essere 0 ma deve essere vuoto. L'output deve avere questa struttura 'cod,diga,data,volume' e non deve avere righe vuote finali. Tieni presente che i valori di 'diga' devono essere esattamente coincidenti con quelli di 'diga_anagrafica'. I separatori di decimali dei volumi devono essere i punti e non le virgole. L'output non deve contenere i backtips all'inizio e alla fine ma solo il contenuto del file csv a cominciare dagli header L'output non deve contenere righe vuote alla fine. Se l'output csv contiene righe finali senza valori, rimuovile." -a "./risorse/pdf/Tabelle/$new_filename" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > ./risorse/tmp/$new_filename.csv
         echo "🟢 Conversione da $new_filename in $new_filename.csv completata"
         n_ai=$((n_ai+1))

         echo ""
         echo "Anteprima di $new_filename.csv:"
         cat ./risorse/tmp/$new_filename.csv | head -n 5
         echo "..."
         n_dighe_ai_1=$(mlr --csv --headerless-csv-output cat -n then stats1 -a max -f n ./risorse/tmp/$new_filename.csv)
         echo "Numero di righe (dighe): $n_dighe_ai_1"
         echo ""

         # check 1 (ai)
         # check estrazione senza anagrafica
         # echo "💬 Double check: verifico estrazione senza anagrafica..."
         # check_limits
         # llm -m gemini-1.5-pro-latest -s "Il tuo compito è quello di estrarre dati da un pdf allegato. Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna diga e quelli della colonna relativa al volume registrato nel mese più recente. Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. L'output deve avere questa struttura 'diga,data,volume' e non deve avere righe vuote finali. I separatori di decimali dei volumi devono essere i punti e non le virgole. L'output non deve contenere i backtips all'inizio e alla fine ma solo il contenuto del file csv a cominciare dagli header. L'output non deve contenere righe vuote alla fine. Se l'output csv contiene righe finali senza valori, rimuovile." -a "./risorse/pdf/Tabelle/$new_filename" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > ./risorse/tmp/2_$new_filename.csv
         # echo "Seconda conversione da $new_filename in 2_$new_filename.csv completata"
         # n_ai=$((n_ai+1))
 
         # echo "Anteprima di $2_$new_filename.csv:"
         # cat ./risorse/tmp/2_$new_filename.csv | head -n 5
         # echo "..."
         # n_dighe_ai_2=$(mlr --csv --headerless-csv-output cat -n then stats1 -a max -f n ./risorse/tmp/2_$new_filename.csv)
         # echo "Numero di righe (dighe): $n_dighe_ai_2"
         # echo ""

         # # check if n_dighe_ai_1 and n_dighe_ai_2 are equal, if not, display an error message and exit
         # if [ $n_dighe_ai_1 -ne $n_dighe_ai_2 ]; then
         #    echo "❌ Errore: il numero di righe estratte dai due metodi non corrisponde!"
         #    echo "È necessario una verifica manuale. Revisionare il file di anagrafica e il file di dati."
         #    exit 1
         # else
         #    echo "✅ Il numero di righe (dighe) estratte dai due metodi corrisponde."
         #    rm ./risorse/tmp/2_$new_filename.csv
         # fi
         
      elif [[ $new_filename == grafici* ]]; then

         # scarico il pdf e lo chiamo new_filename
         curl -skL "$URL_HOMEPAGE$line" -o "./risorse/pdf/Grafici/$new_filename"
         echo "⬇️ Scaricato $new_filename"
      fi

      # aggiungo il pdf alla lista dei pdf scaricati
      echo "$line" >> $PATH_PDFS_LIST

      # incremento il contatore
      n_pdf=$((n_pdf+1))
   fi
done <<< "$pdfs_list"

if [ $n_pdf -gt 0 ]; then
   echo "📄 Ci sono $n_pdf nuovi PDF"
else
   echo "👋 Non ci sono nuovi PDF"
   exit 0
fi

# if temp folder exists
if [ -d "./risorse/tmp" ]; then
   # merge csv data (se ne esistono più di uno)
   # attenzione: può capitare che il csv latest contenga i valori relativi a più date
   mlr --csv cat ./risorse/tmp/*.csv > ./risorse/sicilia_dighe_volumi_latest.csv
   echo "🔄 Aggiornato sicilia_dighe_volumi_latest.csv"

   # add to storico
   # order by date
   # rimuovi righe senza volumi
   # remove duplicates
   mlr --csv cat ./risorse/sicilia_dighe_volumi_latest.csv ./risorse/sicilia_dighe_volumi.csv \
   | mlr --csv put '$date_key = strptime($data, "%Y-%m-%d")' then \
   sort -nr date_key then \
   cut -x -f date_key then \
   filter -S '$volume != ""' then \
   uniq -a  > all.csv
   mv all.csv ./risorse/sicilia_dighe_volumi.csv
   echo "🔄 Aggiornato storico sicilia_dighe_volumi.csv"

   # check consistency
   n_cod_name_concatenated=$(< ./risorse/sicilia_dighe_volumi.csv mlr --csv --headerless-csv-output put '$concatenated = $cod . $diga' then cut -f concatenated then uniq -a | wc -l)
   n_cod=$(< ./risorse/sicilia_dighe_volumi.csv mlr --csv --headerless-csv-output cut -f cod then uniq -a | wc -l)

   # check if n_cod_name_concatenated and n_cod are equal, if not, display an error message and exit
   if [ $n_cod_name_concatenated -ne $n_cod ]; then
      echo "❌ Errore: il numero di codici univoci non corrisponde al numero di codici concatenati con i nomi delle dighe!"
      echo "Questo vuol dire che i nomi delle dighe NON sono stati assegnati correttamente ai codici secondo l'anagrafica."
      echo "È necessaria una verifica manuale. Revisionare il file di dati."
      exit 1
   else
      echo "✅ Check passed: I nomi delle dighe sono stati assegnati correttamente ai codici secondo l'anagrafica"
   fi

   # temp folder
   rm -r "./risorse/tmp"

   # data validation
   frictionless validate datapackage.yaml || exit 1
fi

echo "📍Fine, bye!"

# multisort
# mlr --csv sort -nr volume -f cod ./risorse/sicilia_dighe_volumi_latest.csv