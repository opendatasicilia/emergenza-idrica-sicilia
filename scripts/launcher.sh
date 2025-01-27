#!/bin/bash

# accetta 2 argomenti: il nome dello script da lanciare e il numero di tentativi massimi
if [ $# -ne 2 ]; then
   echo "❌ Errore: questo launcher accetta 2 argomenti."
   echo "Usage: $0 <script> <max_attempts>"
   echo "Esempio: $0 scripts/check_convert_volumi_giornalieri.sh 10"
   exit 1
fi

# assegna i due argomenti alle variabili script e max_attempts
script=$1
max_attempts=$2

# crea contatore tentativi
n=0

# esegui script max_attempts finchè non restituisce 0
while [ $n -lt $max_attempts ]; do
   # stampa il numero del tentativo
   echo "🔁 Tentativo $n"

   # esegui lo script ma non mostrare output
   ./$script #> /dev/null

   # se lo script è andato a buon fine, esci
   if [ $? -eq 0 ]; then
      echo "✅ Lo script $script è stato eseguito con successo all'iterazione n. $n."
      exit 0
   fi

   echo "❌ Lo script n. $n non è andato a buon fine."

   # incrementa il contatore
   n=$((n+1))
done
