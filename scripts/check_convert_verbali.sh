#!/bin/bash


# Questo script apre il sito della Regione Sicilia e controlla la presenza di nuovi verbali PDF
# dell'Osservatorio Distrettuale Permanente sugli Utilizzi Idrici, li riassume e pubblica blog post qui
# https://opendatasicilia.github.io/emergenza-idrica-sicilia/aggiornamenti/


set -e
# set -x


# requirements
# xq (yq), scrape-cli, llm
# check if required commands are installed
for cmd in curl xq scrape llm; do
   if ! command -v $cmd &> /dev/null; then
      echo "❌ Errore: $cmd non è installato."
      exit 1
   fi
done
echo "✅ Requirements satisfied!"


# constants
URL="https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/verbali"
PATH_PDFS_LIST="./risorse/pdfs_list_verbali.txt"
PATH_VERBALI="./risorse/pdf/Verbali"
PATH_BLOG_POSTS="./docs/aggiornamenti/articoli/annuncio"
URL_HOMEPAGE="https://www.regione.sicilia.it"
URL_CSV_ANAGRAFICA_DIGHE="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main/risorse/sicilia_dighe_anagrafica.csv"
URL_RAW_GITHUB_WD="https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/refs/heads/main"
AI_LIMITS=2
AI_SLEEP=60


# functions
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
   # $2: verbale_pdf
   # $3: output_filename
   # output: string
   # description:
   #    genera un blog post a partire da un template in markdown e un pdf. Il blog post è composto da un frontmatter yaml
   #    e il contenuto del blog post. Il frontmatter yaml deve contenere la data del verbale e una breve descrizione del contenuto.
   #    Il contenuto del blog post deve rispettare la struttura markdown del template. Alla fine del blog post viene aggiunto un
   #    messaggio di avviso che il contenuto è stato generato automaticamente da un'Intelligenza Artificiale.

   local template_md=$1
   local verbale_pdf=$2
   local output_filename=$3

   # Generate the blog post using the template and the PDF
   cat "$template_md" | llm -m gemini-1.5-pro-latest -s "Hai il compito di generare un blog post a partire da un verbale in pdf allegato. Nel prompt trovi la struttura del blog post in markdown e frontmatter yaml che devi rispettare e compilare. Inserisci la data del verbale e una brevissima descrizione del contenuto e poi una descrizione più esaustiva. Se nel verbale vengono citati nomi di invasi, dighe o comuni, riportali nei tuoi riassunti. Se necessario, includi una struttura markdown nel blog post per titoli, sottotitoli ed elenchi puntati. Effettua lo styling del testo con grassetto o corsivo in sintassi markdown se necessario. Ricorda di aggiungere il tag 'osservatorio' e la categoria 'generale' al frontmatter yaml. La tua risposta deve cominciare con il frontmatter in yaml e il contenuto del blog post, non voglio messaggi introduttivi da parte tua." -a "$verbale_pdf" > "$output_filename"

   # add download button to pdf
   echo "" >> $output_filename
   echo "---" >> $output_filename
   echo "[:fontawesome-solid-file-pdf: Leggi il verbale]($URL_RAW_GITHUB_WD/$PATH_VERBALI/$new_filename.pdf){ .md-button }" >> $output_filename
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

   echo "$old_name" | llm -m gemini-1.5-pro-latest -s "Converti il nome di questo file nel formato '$format' tutto minuscolo. Restituisci in output una sola riga senza estensione" | tr -d '\n'
}


# main
# obtain the last page with pdfs list
url_page_with_list=$(curl -skL $URL | scrape -be "#it-block-field-blocknodegeneric-pagefield-p-body a:last-of-type" | xq -r '.html.body.a[-1]."@href"')

pdfs_list=$(curl -skL $url_page_with_list | scrape -be "a" | xq -r '.html.body.a[]."@href"' | grep ".pdf")

# inizializzo contatori
n_pdf=0; n_ai=0

# check pdfs_list contains pdfs that are not in file pdfs_list_verbali.txt
while read -r line; do
   if ! grep -q "$line" $PATH_PDFS_LIST; then

      echo "🆕 $line è un nuovo file PDF"

      # incremento il contatore
      n_pdf=$((n_pdf+1))

      # crea cartella verbali se non esiste
      mkdir -p $PATH_VERBALI
      
      # normalizzo il nome del file pdf
      check_limits
      new_filename=$(normalize_filename "$line" "verbale_YYYY-MM-DD")
      n_ai=$((n_ai+1))

      # se new_filename non è una variabile vuota
      if [ -n "$new_filename" ]; then
         echo "✏️  File rinominato in $new_filename"

         # scarica il pdf
         curl -skL "$URL_HOMEPAGE$line" -o "$PATH_VERBALI/$new_filename.pdf"
         echo "⬇️  Scaricato $new_filename.pdf"

         # genera un riassunto del pdf
         check_limits
         echo "📝 Sto generando $new_filename.md"
         generate_summary ./risorse/blog_post_verbale_template.md $PATH_VERBALI/$new_filename.pdf $PATH_BLOG_POSTS/$new_filename.md
         n_ai=$((n_ai+1))

         # aggiungo il pdf alla lista dei pdf scaricati
         echo "$line" >> $PATH_PDFS_LIST
      fi
   fi
done <<< "$pdfs_list"

if [ $n_pdf -gt 0 ]; then
   echo "📄 Ci sono $n_pdf nuovi PDF"
else
   echo "👋 Non ci sono nuovi PDF"
   exit 0
fi

echo "📍Fine, bye!"