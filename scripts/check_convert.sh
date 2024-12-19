#!/bin/bash

# Questo script apre il sito della Regione Sicilia e controlla la presenza di nuovi documenti PDF contenenti
# dati sui volumi invasati dalle dighe siciliane. Se trova nuovi PDF, li scarica e li converte in CSV sfruttando un llm. 

# requirements
# xq, scrape-cli, llm (con api key), mlr

# constants
URL="https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/siti-tematici/risorse-idriche/volumi-invasati-nelle-dighe-della-sicilia"
PATH_PDFS_LIST="./risorse/pdfs_list.txt"
URL_HOMEPAGE="https://www.regione.sicilia.it"
URL_CSV_ANAGRAFICA_DIGHE="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main/risorse/sicilia_dighe_anagrafica.csv"

# obtain the last page with pdfs list
url_page_with_list=$(curl -skL $URL | scrape -e "#it-block-field-blocknodegeneric-pagefield-p-body li:last-of-type a:last-of-type" | xq -r '.a."@href"')

pdfs_list=$(curl -skL $url_page_with_list | scrape -be "a" | xq -r '.html.body.a[]."@href"' | grep ".pdf")

i=0
# check pdfs_list contains pdfs that are not in file pdfs_list.txt
while read -r line; do
   if ! grep -q "$line" $PATH_PDFS_LIST; then

      echo "$line è un nuovo pdf"
   
      # converto il nome del pdf in volumi_YYYY-MM.pdf tramite ai llm
      new_filename=$(echo "$line" | llm -m gemini-1.5-pro-latest -s "converti il nome di questo file pdf nel formato volumi_YYYY-MM.pdf se si tratta di una tabella, oppure grafici_YYYY-MM.pdf se invece si tratta di grafici. Restituisci in output una sola riga" | tr -d '\n')
      echo "il nuovo nome è $new_filename"

      # check if new_filename start with "volumi", in caso scarico ed estraggo csv. Se contiene "grafici" scarico e stop
      if [[ $new_filename == volumi* ]]; then

         # scarico il pdf e lo chiamo new_filename
         curl -skL "$URL_HOMEPAGE$line" -o "./risorse/pdf/Tabelle/$new_filename"
         echo "ho scaricato $new_filename"

         echo "$new_filename è un pdf di volumi quindi provo a convertirlo in csv"
         
         # creo (se non esiste già) la cartella per i csv temporanei
         mkdir -p ./risorse/tmp

         # extract csv data
         curl -skL "$URL_CSV_ANAGRAFICA_DIGHE" | llm -m gemini-1.5-pro-latest -s "Il tuo compito è quello di estrarre dati da un pdf allegato e di incrociarli con i dati di un'anagrafica csv passata come prompt. Dalla tabella pdf, individua la data di rilevazione e poi estrai tutti i dati della colonna diga (chiamala 'diga_pdf') e quelli della colonna relativa al volume registrato nel mese più recente. Arricchisci la tabella aggiungendo una colonna chiamata 'data' che abbia in ogni riga la data della rilevazione più recente a cui si riferiscono i dati nel formato yyyy-mm-dd. Dal CSV, estrai la colonna 'diga' che chiamerai 'diga_anagrafica' popolata con il nome corretto (da includere esattamente nell'output). Confronta le colonne 'diga_pdf' e 'diga_anagrafica' per fare in modo di arricchire il dataset e assegnare a ogni diga il corrispondente codice identificativo presente nella colonna 'cod' del csv. Attenzione alla diga ogliastro e don sturzo che sono la stessa cosa. In ultimo, cestina la colonna 'diga_pdf' e  nell'output includi i valori di 'diga_anagrafica' sotto il nome di 'diga'. Attenzione ad attribuire correttamente il codice al nome della diga secondo l'anagrafica csv. Se l'anagrafica csv contiene più dighe della tabella pdf, l'output deve contenere solo ed esclusivamente le dighe presenti nel file pdf. Se nell'anagrafica ci sono più dighe del pdf, il volume non deve essere 0 ma deve essere vuoto. L'output deve avere questa struttura 'cod,diga,data,volume' e non deve avere righe vuote finali. Tieni presente che i valori di 'diga' devono essere esattamente coincidenti con quelli di 'diga_anagrafica'. I separatori di decimali dei volumi devono essere i punti e non le virgole. L'output non deve contenere i backtips all'inizio e alla fine ma solo il contenuto del file csv a cominciare dagli header L'output non deve contenere righe vuote alla fine. Se l'output csv contiene righe finali senza valori, rimuovile." -a "./risorse/pdf/Tabelle/$new_filename" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > ./risorse/tmp/$new_filename.csv
         echo "ho convertito $new_filename in $new_filename.csv"

         # attendo per eventuali limiti di api
         sleep 60
      elif [[ $new_filename == grafici* ]]; then

         # scarico il pdf e lo chiamo new_filename
         curl -skL "$URL_HOMEPAGE$line" -o "./risorse/pdf/Grafici/$new_filename"
         echo "ho scaricato $new_filename"
      fi

      # aggiungo il pdf alla lista dei pdf scaricati
      echo "$line" >> $PATH_PDFS_LIST

      # incremento il contatore
      i=$((i+1))
   fi
done <<< "$pdfs_list"

if [ $i -gt 0 ]; then
   echo "Ci sono $i nuovi pdf"
else
   echo "Non ci sono nuovi pdf"
   exit 0
fi

# if temp folder exists
if [ -d "./risorse/tmp" ]; then
   # merge csv data (se ne esistono più di uno)
   # attenzione: può capitare che il csv latest contenga i valori relativi a più date
   mlr --csv cat ./risorse/tmp/*.csv > ./risorse/sicilia_dighe_volumi_latest.csv
   
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

   # temp folder
   rm -r "./risorse/tmp"
fi

echo "Fine, bye!"
