#!/bin/bash

check_required_tools() {
   #
   # Verifica che tutti i comandi richiesti siano installati nel sistema.
   # 
   # Argomenti:
   #   $@ - Lista di comandi da verificare
   #
   # Output:
   #   Stampa un messaggio di errore se un comando non è installato
   #
   # Ritorna:
   #   0 - Tutti i comandi sono installati
   #   1 - Uno o più comandi non sono installati (ed esce dal programma)
   #

   local tools=("$@")
   local missing_tools=()

   for cmd in "${tools[@]}"; do
      if ! command -v $cmd &> /dev/null; then
         missing_tools+=("$cmd")
      fi
   done

   if [ ${#missing_tools[@]} -gt 0 ]; then
      echo "❌ Errore: i seguenti tool non sono installati: ${missing_tools[*]}"
      exit 1
   fi

   return 0
}

compare_lists() {
   # Compares two lists and returns the elements that are in the first list but not in the second.
   #
   # Args:
   #   $1 - Variable name containing the first list (space-separated strings)
   #   $2 - Path to a file containing the second list (one item per line)
   #
   # Returns:
   #   Prints the items from the first list that are not in the second list, one per line
   #   Empty output if all items from the first list are in the second list
   #
   # Example:
   #   pdf_files="file1.pdf file2.pdf file3.pdf"
   #   compare_lists "$pdf_files" "processed_files.txt"

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

check_limits() {
    # Controlla se è stato raggiunto il limite di richieste API e gestisce l'attesa.
    # Non è esattamente preciso ma serve per evitare uno sleep inutile dopo ogni chiamata.
    #
    # La funzione verifica se il numero di richieste all'API ha raggiunto il limite massimo
    # consentito al minuto. In caso affermativo, mette in pausa l'esecuzione per un periodo 
    # specificato e resetta il contatore.
    #
    # Parametri:
    #   $1: ai_max_rpm - numero massimo di richieste permesse al minuto
    #   $2: ai_wait_seconds - secondi di attesa quando il limite viene raggiunto
    #
    # Variabili globali:
    #   n_ai - contatore delle richieste (deve essere inizializzato e incrementato esternamente)
    #
    # Returns: nessun valore di ritorno
   
   local ai_max_rpm=$1
   local ai_wait_seconds=$2
   
   if [ $n_ai -ge $ai_max_rpm ]; then
      echo "🚨 Superato il limite di richieste, attendo $ai_wait_seconds secondi..."
      sleep $ai_wait_seconds
      n_ai=0
   fi
}

normalize_filename() {
    # Normalize file names according to a specified format
    #
    # Usage:
    #   normalize_filename "input_filename.pdf" "format_pattern"
    #
    # Arguments:
    #   $1 - Original filename (e.g., "Verbale del 2021-06-30.pdf")
    #   $2 - Target format pattern (e.g., "verbale_YYYY-MM-DD")
    #
    # Returns:
    #   Normalized filename without extension (on success)
    #   Error message (on failure)
    #
    # Example:
    #   normalize_filename "Verbale del 2021-06-30.pdf" "verbale_YYYY-MM-DD"
    #   # Returns: verbale_2021-06-30

   local old_name=$1
   local format=$2
   local llm_model=$3

   llm_response=$(echo "$old_name" | llm -m "$llm_model" \
   -s "Converti il nome di questo file nel formato '$format' tutto minuscolo. Restituisci in output una sola riga senza estensione") \
   || { echo "❌ Errore durante l'esecuzione di llm (normalizzazione nome file)"; return 1; }

   echo "$llm_response" | tr -d '\n'
}

remove_trailing_empty_lines() {
    # Removes trailing empty lines from text input
    # inputs:
    # $1: input string
    # output: returns cleaned string or exit with error if input is empty
    
    local input_text="$1"
    
    # Check if input_text is empty
    if [[ -z "$input_text" ]]; then
    echo "❌ Error: Empty input received for remove_trailing_empty_lines"
    return 1
    fi
    
    # Remove trailing empty lines and return the result
    echo "$input_text" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}
