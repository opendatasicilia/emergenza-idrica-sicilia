# Scripts di automazione

Questa cartella contiene gli script per l'automazione del processo di raccolta e conversione dei dati sui volumi idrici delle dighe siciliane.

## Contenuti

- `check_convert_verbali.sh`: Script per il download e la conversione dei verbali dell'Osservatorio Distrettuale Permanente sugli Utilizzi Idrici. Scarica i PDF dal sito della Regione Sicilia, li analizza tramite AI (Gemini) e genera automaticamente post per il blog con i contenuti principali.

- `check_convert_volumi_mensili.sh`: Script per il download e la conversione dei dati mensili sui volumi invasati dalle dighe siciliane. Scarica i PDF dal sito della Regione, estrae i dati tramite AI e li converte in formato CSV, effettuando vari controlli di qualità.

- `check_convert_volumi_giornalieri.sh`: Script analogo al precedente ma per i dati giornalieri sui volumi invasati. Include controlli aggiuntivi sulla coerenza dei dati estratti.

- `launcher.sh`: Script wrapper che gestisce l'esecuzione degli altri script con un numero massimo di tentativi in caso di errori. Utile per gestire eventuali fallimenti nell'estrazione dei dati.

## Requisiti

Gli script richiedono i seguenti tool:
- curl 
- jq
- xq (yq)
- scrape-cli
- llm
- mlr (Miller)

## Utilizzo

Per eseguire uno script tramite il launcher:

```bash
./launcher.sh scripts/check_convert_volumi_giornalieri.sh 10
```

Dove 10 è il numero massimo di tentativi in caso di errore.
