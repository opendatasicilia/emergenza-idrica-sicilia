#!/bin/bash

# -------------------------------------------------------------------------------------------#
# Questo script apre il sito della Regione Sicilia e controlla la presenza di nuovi verbali 
# PDF dell'Osservatorio Distrettuale Permanente sugli Utilizzi Idrici, li riassume e pubblica
# blog post qui https://opendatasicilia.github.io/emergenza-idrica-sicilia/aggiornamenti/
#
# To do:
# - [ ] implementare la scelta del modello llm in fase di lancio (far scegliere 2 modelli)
# - [ ] cambiare nome di compare_lists() in find_new_pdfs()
# - [ ] Verificare che sia effettivamente questo script a gestire il testo del messaggio
#       altrimenti, rimuovere la funzione generate_telegram_message()
# - [ ] Capire se ha senso lanciare questo script con il launcher, in caso adeguare tutto.
# -------------------------------------------------------------------------------------------#


set -e
# set -x


#-----------------requirements-----------------#
# check if required commands are installed: xq (yq), scrape-cli, llm
for cmd in curl xq scrape llm; do
   if ! command -v "$cmd" &> /dev/null; then
      echo "❌ Errore: $cmd non è installato."
      exit 1
   fi
done
echo "✅ Requirements satisfied!"


#-----------------constants-----------------#
URL="https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/verbali"
PATH_PDFS_LIST="./risorse/processed-urls/pdfs_list_verbali.txt"
PATH_VERBALI="./risorse/pdf/verbali"
PATH_BLOG_POSTS="./docs/aggiornamenti/articoli/annuncio"
URL_HOMEPAGE="https://www.regione.sicilia.it"
URL_CSV_ANAGRAFICA_DIGHE="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main/risorse/sicilia_dighe_anagrafica.csv"
URL_RAW_GITHUB_WD="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main"
AI_LIMITS=10
AI_SLEEP=60


#----------------- functions -----------------#
check_limits() {
   # inputs: none
   # output: none
   # description:
   #    controlla se il numero di richieste ai (n_ai) supera un certo limite (AI_LIMITS) e in caso mette in pausa
   #    il processo per un certo tempo (AI_SLEEP).

   if [ $n_ai -ge $AI_LIMITS ]; then
      echo "🚨 Superato il limite di richieste, attendo $AI_SLEEP secondi..."
      sleep $AI_SLEEP
      n_ai=0
   fi
}

generate_summary() {
   # inputs: 
   # $1: template_md
   # $2: local_path_pdf
   # $3: output_filename
   # output: string
   # description:
   #    genera un blog post a partire da un template in markdown e un pdf. Il blog post è composto da un frontmatter yaml
   #    e il contenuto del blog post. Il frontmatter yaml deve contenere la data del verbale e una breve descrizione del contenuto.
   #    Il contenuto del blog post deve rispettare la struttura markdown del template. Alla fine del blog post viene aggiunto un
   #    messaggio di avviso che il contenuto è stato generato automaticamente da un'Intelligenza Artificiale.

   local template_md=$1
   local local_path_pdf=$2
   local output_filename=$3

   # Generate the blog post using the template and the PDF
   system_prompt="Hai il compito di generare un blog post a partire da un verbale in pdf allegato. Nel prompt trovi la struttura del blog post in markdown e frontmatter yaml che devi rispettare e compilare. Inserisci la data del verbale e una brevissima descrizione del contenuto e poi una descrizione più esaustiva. Usa uno stile di scrittura che produca un copy molto leggibile, scorrevole e piacevole. Assicurati di usare uno stile di scrittura discorsivo e non troppo schematico. Assicurati di aggiungere le adeguate intestazioni con la sintassi markdown per strutturare il contenuto del post. Se nel verbale vengono citati nomi di invasi, dighe o comuni, riportali nei tuoi riassunti. Se nel verbale sono presenti dettagli relativi ai prelievi o agli scenari futuri, includili nel tuo riassunto. Se nel verbale sono presenti punti all'ordine del giorno, includili nel tuo riassunto. Includi una struttura markdown nel blog post per formattare titoli, sottotitoli, sezioni, elenchi puntati. Effettua lo styling del testo con grassetto o corsivo in sintassi markdown ove necessario. Evidenzia in grassetto le date o altri dati importanti (riduzioni, volumi, quote, ecc). Assicurati di aggiungere il tag 'osservatorio' e la categoria 'generale' al frontmatter yaml. Assicurati di inserire il frontmatter in yaml come indicato nel prompt. Per favore assicurati di includere il tuo output dentro un code block che io posso estrarre. Grazie!"

   llm_response=$(cat "$template_md" | llm -x -m gemini-2.0-flash-thinking-exp-01-21 \
   -s "$system_prompt" \
   -a "$local_path_pdf") \
   || { echo "❌ Errore durante l'esecuzione di llm (generazione blog post)"; exit 1; }
   
   echo "$llm_response" > "$output_filename"
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

   llm_response=$(echo "$old_name" | llm -m gemini-2.0-flash-lite \
   -s "Converti il nome di questo file nel formato '$format' tutto minuscolo. Restituisci in output una sola riga senza estensione") \
   || { echo "❌ Errore durante l'esecuzione di llm (normalizzazione nome file)"; exit 1; }

   echo "$llm_response" | tr -d '\n'
}

generate_telegram_message() {
   # inputs:
   # $1 url_pdf
   # $2 path message will be saved

   local url_pdf=$1
   local path_msg=$2

   # crea messaggio da inviare su telegram
   echo "🆕 Ho trovato un [nuovo verbale]($url_pdf) dell'Osservatorio sugli utilizzi idrici della Regione Siciliana! Mi sono permesso di preparare per voi un *riassunto* che verrà pubblicato a momenti in [questo blog](https://opendatasicilia.github.io/emergenza-idrica-sicilia/aggiornamenti/) usando [✨ Gemini AI](https://gemini.google.com/).

   Se trovi degli errori, per favore correggili tramite l'icona di modifica in alto a destra o [apri una issue](https://github.com/opendatasicilia/emergenza-idrica-sicilia/issues). Grazie!

   _Questo è un messaggio automatico fatto da quello strafigo di Dennis Angemis e gestito da un_ [workflow di GitHub](https://github.com/opendatasicilia/emergenza-idrica-sicilia/blob/main/.github/workflows/new_pdfs.yaml)" > $path_msg
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


#------------------- main -------------------#

# obtain the last page with pdfs list
url_page_with_list=$(curl -skL $URL | scrape -be "#it-block-field-blocknodegeneric-pagefield-p-body a:last-of-type" | xq -r '.html.body.a[-1]."@href"')

# list of pdfs in the webpage
pdfs_list=$(curl -skL $url_page_with_list | scrape -be "a" | xq -r '.html.body.a[]."@href"' | grep ".pdf")

# list of new pdfs
new_pdfs=$(compare_lists "$pdfs_list" "$PATH_PDFS_LIST") \
|| { echo "❌ Errore durante la ricerca dei nuovi file da processare."; exit 1; }

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

for line in "${pdfs_array[@]}"; do
   n_pdf=$((n_pdf+1))
   echo ""
   echo "📄 $n_pdf/$n_pdfs: Processo $line"
   
   mkdir -p $PATH_VERBALI
   
   # normalize filename 
   check_limits
   new_filename=$(normalize_filename "$line" "verbale_YYYY-MM-DD") \
   || { echo "❌ Errore durante la normalizzazione del nome del file $n_pdf. Vado col prossimo..."; continue; }
   n_ai=$((n_ai+1))

   if [ -n "$new_filename" ]; then
      echo "✏️  File rinominato in $new_filename"

      # download pdf
      if ! curl -skL "$URL_HOMEPAGE$line" -o "$PATH_VERBALI/$new_filename.pdf"; then
         echo "❌ Errore nel download del PDF $line, continuo con il prossimo..."
         continue
      fi
      echo "⬇️  Scaricato $new_filename.pdf"

      # build blog post filename
      blog_post="$PATH_BLOG_POSTS/$new_filename.md"
      
      # generate blog post
      echo "📝 Sto generando $new_filename.md"

      check_limits
      generate_summary ./risorse/blog_post_verbale_template.md "$PATH_VERBALI/$new_filename.pdf" "$blog_post" \
      || { echo "❌ Errore durante la generazione del blog post $n_pdf. Vado col prossimo..."; continue; }
      n_ai=$((n_ai+1))

      # add download button to pdf
      echo "" >> $blog_post
      echo "---" >> $blog_post
      echo "[:fontawesome-solid-file-pdf: Leggi il verbale]($URL_HOMEPAGE$line){ .md-button }" >> $blog_post

      # creo messaggio da inviare su telegram
      mkdir -p ./risorse/msgs
      generate_telegram_message "$URL_HOMEPAGE$line" ./risorse/msgs/new_verbale.md

      # aggiungo il pdf alla lista dei pdf scaricati
      echo "$line" >> $PATH_PDFS_LIST
      echo "📦 Aggiornata la lista dei PDF processati"
   fi
done

echo ""
echo "🚀 Fine, bye!"
