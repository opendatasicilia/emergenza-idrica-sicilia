# Dati sugli invasi delle dighe e sulle riduzioni idriche in Sicilia

## Data Dictionary
### 📄 [sicilia_dighe_volumi](risorse/sicilia_dighe_volumi.csv)
Volumi invasati nelle dighe della Sicilia. Tabella estratta dai [file PDF rilasciati dalla Regione Siciliana](https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/siti-tematici/risorse-idriche/volumi-invasati-nelle-dighe-della-sicilia).
- Path: `risorse/sicilia_dighe_volumi.csv`
- URL: https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/main/risorse/sicilia_dighe_volumi.csv
- Encoding: `utf-8`

| Field | Type | Description | Example |
| --- | --- | --- | --- |
| cod | string | codice univoco diga | dig-02 |
| diga | string | denominazione della diga | Arancio |
| data | date | data nel formato dd/mm/yyyy | 01/01/2010 |
| volume | number | volume in Mmc | 27.04 |

### 📄 [sicilia_dighe_anagrafica](risorse/sicilia_dighe_anagrafica.csv)
Anagrafica delle dighe della Sicilia. File costruito e arricchito dalla comunità Open Data Sicilia.
- Path: `risorse/sicilia_dighe_anagrafica.csv`
- URL: https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/main/risorse/sicilia_dighe_anagrafica.csv
- Encoding: `utf-8`

| Field | Type | Description | Example |
| --- | --- | --- | --- |
| coordinate | geopoint | concatenazione delle due coordinate Lat e Long (EPSG:4326) | 37.836222,14.562873 |
| lat | number | latitudine (EPSG:4326) | 37.836222 |
| long | number | longitudine (EPSG:4326) | 14.562873 |
| cod | string | codice univoco diga | dig-01 |
| diga | string | nome della diga | Àncipa |
| fiume | string | fiume lungo il quale è presente la diga | Troina |
| lago | string | lago nel quale è presente la diga | Lago Àncipa |
| comune | string | comune nel quale è presente la diga | Cesarò |
| provincia | string | provincia nella quale è presente la diga | ME |
| capacita | number | capacità: capacità della diga espressa im Mmc | 30.40 |
| utilizzazione | string | come viene utilizzata l'acqua della diga | Potabile - Irriguo - Elettrico |
| gestore | string | gestore della diga | E.N.E.L. |

### 📄 [italia_grandi_dighe_anagrafica](risorse/italia_grandi_dighe_anagrafica.csv)
Anagrafica e localizzazione delle grandi dighe di competenza della Direzione Generale per le Dighe e le Infrastrutture idriche sul territorio nazionale. Tabella estratta dal [sito della Direzione (vd. sources)](https://dgdighe.mit.gov.it/categoria/articolo/_cartografie_e_dati/_cartografie/cartografia_dighe)
- Path: `risorse/italia_grandi_dighe_anagrafica.csv`
- URL: https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/main/risorse/italia_grandi_dighe_anagrafica.csv
- Encoding: `utf-8`

| Field | Type | Description | Example |
| --- | --- | --- | --- |
| nome | string | nome della diga | Corongiu 2 |
| latitudine | number | latitudine (EPSG:4326) | 39.312806 |
| longitudine | number | longitudine (EPSG:4326) | 9.283889 |
| n_arch | string |  | 0087A |
| utd | string | ufficio tecnico dighe | Cagliari |
| regione | string | denominazione regione | Sardegna |
| provincia | string | sigla provincia | CA |
| comune | string | denominazione comune | Sinnai |
| corso_acqua | string | corso d'acqua: denominazione del corso d'acqua | Rio Bau Filixi - Rio Corr 'e Cerbu |
| tipologia | string | tipo di costruzione diga | A gravità ordinaria in muratura di pietrame con malta (a.1.1.) |
| altezza_ndt_2014_m | number |  | 19.50 |
| altezza_dm_marzo_82_m | number |  | 21.30 |
| vol_di_invaso_Mmc | number | volume dell'invaso in Mm³ | 0.37 |
| quota_max_di_reg_m_slm | number |  | 154.94 |
| uso_prevalente | string | uso prevalente della diga | Potabile |
| anno_inizio_lavori | integer | anno di inizio lavori | 1913 |
| anno_fine_lavori | integer | anno di fine lavori | 1915 |
| indirizzo_google_maps | string |  | https://goo.gl/maps/ZDY7fp76gzVqXqHD6 |

### 📄 [sicilia_dighe_competenza_utd_palermo](risorse/sicilia_dighe_competenza_utd_palermo.csv)
Elenco delle dighe di competenza dell'ufficio tecnico per le dighe di Palermo al 31/12/2023. Dati estratti da [questa pagina](https://dgdighe.mit.gov.it/categoria/articolo/_cartografie_e_dati/_dighe_di_competenza/UTDPA) del sito della Direzione Generale per le Dighe e le Infrastrutture idriche (vd. sources). La legenda dei codici è disponibile nella pagina web indicata in sources.
- Path: `risorse/sicilia_dighe_competenza_utd_palermo.csv`
- URL: https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/main/risorse/sicilia_dighe_competenza_utd_palermo.csv
- Encoding: `utf-8`

| Field | Type | Description | Example |
| --- | --- | --- | --- |
| id | integer |  | 1 |
| diga | string |  | ANCIPA |
| narch | integer |  | 527 |
| sub | string |  | _ |
| s1 | string |  | NO |
| s2 | string |  | SC |
| uso_prevalente | string |  | IDROELETTRICO |
| regione | string |  | SICILIA |
| provincia | string |  | EN |
| concessionario | string |  | ENEL PRODUZIONE S.P.A. |

### 📄 [sicilia_riduzione_idrica_20240405](risorse/sicilia_riduzione_idrica_20240405.csv)
I dati sono stati estratti da una [mappa PDF rilasciata dalla Regione Siciliana](https://www.regione.sicilia.it/sites/default/files/2024-04/Mappa%20pdf.pdf) 
- Path: `risorse/sicilia_riduzione_idrica_20240405.csv`
- URL: https://raw.githubusercontent.com/opendatasicilia/emergenza-idrica-sicilia/main/risorse/sicilia_riduzione_idrica_20240405.csv
- Encoding: `utf-8`

| Field | Type | Description | Example |
| --- | --- | --- | --- |
| pro_com_t | string | Codice stringa ISTAT | 081001 |
| comune | string | Denominazione del Comune | Alcamo |
| provincia | string | Denominazione della Provincia | Trapani |
| sigla | string | sigla della provincia | TP |
| riduzione | string | riduzione fornitura idrica in % | 10 - 20 |
| area_kmq | number | superficie Comune | 130.89 |
| pop_2024 | integer | popolazione residente ISTAT al 1° gennaio 2024 | 44683 |

## 📖 License
This work is licensed under a [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/) (CC-BY-4.0) License


---

Generated from datapackage.yaml with [`frictionless2md`](https://github.com/dennisangemi/frictionless2md)

