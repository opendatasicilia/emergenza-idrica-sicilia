#!/bin/bash

# Launcher script per eseguire script di estrazione dati tramite LLM
# con un numero massimo di tentativi.
# Sript supportati:
# - check_convert_volumi_giornalieri.sh
# - check_convert_volumi_mensili.sh

# Esempio di utilizzo:
# ./launcher.sh scripts/check_convert_volumi_giornalieri.sh 10

# To do:
# - [ ] Aggiungere verifica requirements (rimuoverla dai singoli script)

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
n=1

echo "🚀 Eseguo lo script $script..."

# esegui script max_attempts finchè non restituisce 0
while [ $n -le $max_attempts ]; do
   # stampa il numero del tentativo
   echo "🔁 Tentativo $n/$max_attempts"
   echo ""

   # esegui lo script
   ./$script

   # se lo script è andato a buon fine, esci
   if [ $? -eq 0 ]; then
      echo ""
      echo "✅ Lo script è stato eseguito con successo all'iterazione n. $n."
      exit 0
   else
      if [ $n -eq $max_attempts ]; then
         echo ""
         echo "❌ Numero massimo di tentativi raggiunto."
         exit 1
      else
         echo "⚠️ L'esecuzione n. $n non è andata a buon fine."
         echo "⏳ Riprovo tra 10 secondi..."
         sleep 10
      fi
   fi

   # incrementa il contatore
   n=$((n+1))
done
