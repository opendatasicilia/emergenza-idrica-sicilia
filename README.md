# Emergenza Idrica in Sicilia

La Sicilia sta affrontando una **grave crisi idrica**, che mette a rischio non solo l'approvvigionamento di acqua per la popolazione ma anche le attività agricole e zootecniche, vitali per l'economia regionale. Questa emergenza è causata da una combinazione di fattori: precipitazioni notevolmente inferiori alla media, temperature più elevate del solito e una gestione delle risorse idriche che stenta a soddisfare le crescenti esigenze.

Il Governo Regionale Siciliano ha avanzato una [richiesta formale per la dichiarazione dello stato di emergenza nazionale](docs/documenti-utili/emergenza_nazionale_art7e24_dlvo2018n1.pdf). L'obiettivo è di poter attivare risorse supplementari e misure straordinarie per combattere questa emergenza.

## Informazione e Trasparenza

Un elemento cruciale per affrontare efficacemente questa crisi è l'informazione. La **trasparenza e la condivisione di dati aggiornati sulla situazione idrica sono fondamentali** per sensibilizzare la popolazione sull'urgenza del problema e sull'importanza di un uso responsabile dell'acqua. La pubblicazione regolare di questi dati, accessibili a tutti, può giocare un ruolo determinante nell'incrementare la consapevolezza collettiva e nel promuovere comportamenti virtuosi da parte dei cittadini.

## Struttura del Repository

- **risorse/**: Contiene i dati estratti da report PDF ufficiali.
- **scripts/**: Contiene gli script utilizzati per l'estrazione dei dati tramite LLM.
- **docs/**: Contiene i file per il sito statico costruito con Material for MkDocs.


### Dati

Questo repository contiene dati sui **volumi** idrici delle **dighe siciliane**, sulle **riduzioni idriche** e altre informazioni rilevanti. I dati sono **aggiornati** ed estratti automaticamente dai **documenti pubblicati dalla Regione Siciliana**. La frequenza di aggiornamento varia in base al tipo di dataset (alcuni hanno **frequenza giornaliera**, altri **mensile**)

Trovi tutti i dati estratti, metadatati e documentati dalla community di Open Data Sicilia in [`risorse/`](risorse/). I dettagli relativi ai dataset e alla loro struttura sono disponibili in [`risorse/README.md`](risorse/README.md)

### Scripts

Nella cartella [`scripts/`](scripts/) sono presenti gli script per:
- l'automazione del processo di **raccolta e conversione dei dati** sui volumi idrici delle dighe siciliane;
- l'automazione del processo di **scrittura di riassunti di nuovi verbali** relativi dell'Osservatorio Distrettuale Permanente sugli Utilizzi Idrici del distretto Sicilia.

I dettagli sugli script adoperati sono disponibili in [`scripts/README.md`](scripts/README.md).


### Sito [Emergenza Idrica in Sicilia](https://opendatasicilia.github.io/emergenza-idrica-sicilia/)
Abbiamo sviluppato un sito tematico powered by [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) per rendere le informazioni più leggibili e accessibili. Il sito contiene **mappe, tabelle, documenti utili** sulla crisi idrica in Sicilia. Inoltre, nella sezione [aggiornamenti](https://opendatasicilia.github.io/emergenza-idrica-sicilia/aggiornamenti/) di questo sito, troverai i riassunti dei verbali dell'Osservatorio Distrettuale Permanente sugli Utilizzi Idrici del distretto Sicilia generati da un sistema di Intelligenza Artificiale.

Visita il sito tematico: [Emergenza Idrica in Sicilia](https://opendatasicilia.github.io/emergenza-idrica-sicilia/)

## Contributi
Siamo aperti a contributi! Se desideri contribuire, sentiti libero di aprire una pull request o di segnalare un problema tramite le issue del repository.

## Licenza
Questo lavoro è concesso in licenza sotto una Creative Commons Attribution 4.0 (CC-BY-4.0) License.

Usa liberamente i dati e le informazioni che trovi in questo repo, citaci e avvisaci!

```
Dati estratti dalla community Open Data Sicilia e rilasciati in https://github.com/opendatasicilia/emergenza-idrica-sicilia
```