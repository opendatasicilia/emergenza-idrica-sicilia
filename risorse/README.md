# LEGGIMI

## dighe_anagrafica

È un file csv estratto dal [PDF](https://www.regione.sicilia.it/sites/default/files/2024-01/2024.01.01_A_Tabella_volumi_invasi.pdf)

| attributo     | descrizione                                                | esempio                               |
| ------------- | ---------------------------------------------------------- | ------------------------------------- |
| coordinate    | concatenazione delle due coordinate Lat e Long (EPSG:4326) | 37.836222, 14.5628727                 |
| lat           | latitudine (EPSG:4326)                                     | 37.836222                             |
| long          | longitudine (EPSG:4326)                                    | 14.562872                             |
| cod           | codice univoco                                             | dig-01                                |
| diga          | nome della diga                                            | Àncipa                                |
| fiume         | fiume lungo il quale è presente la diga                    | Troina                                |
| lago          | lago nel quale è presente la diga                          | Lago Àncipa                           |
| comune        | Comune nel quale è presente òa diga                        | Cesarò                                |
| provincia     | Provincia nel quale è presente la diga                     | ME                                    |
| capacita      | capacità della diga espressa im Mm³                        | 30.40                                 |
| utilizzazione | come viene utilizzata l'acqua della diga                   | Potabile - Irriguo - Elettrico        |
| gestore       | gestore della diga                                         | Dipartimento dell'acqua e dei rifiuti |

## dighe_serie_storica_melted

Dati scrapati dai [PDF](https://www.regione.sicilia.it/sites/default/files/2024-01/2024.01.01_A_Tabella_volumi_invasi.pdf)

| attributo | descrizione              | esempio    |
| --------- | ------------------------ | ---------- |
| cod       | codice univoco diga      | dig-26     |
| diga      | denominazione della diga | Scanzano   |
| data      | data (giorno-mese-anno)  | 01/01/2010 |
| volume    | volume in Mm³            | 9.78       |

## grandi_dighe_italiane

È un file csv elaborato a partire dal [sito](https://dgdighe.mit.gov.it/categoria/articolo/_cartografie_e_dati/_cartografie/cartografia_dighe)

| attributo                 | descrizione                             | esempio                                                        |
| ------------------------- | --------------------------------------- | -------------------------------------------------------------- |
| nome                      | nome della diga                         | Santa Vittoria                                                 |
| latitudine                | latitudine (EPSG:4326)                  | 39.315861                                                      |
| longitudine               | longitudine (EPSG:4326)                 | 9.288667                                                       |
| n__arch_                  |                                         | 0087B                                                          |
| utd                       | ufficio tecnico dighe                   | Cagliari                                                       |
| regione                   | denominazione regione                   | Sardegna                                                       |
| provincia                 | sigla provincia                         | CA                                                             |
| comune                    | denominazione comune                    | Sinnai                                                         |
| corso_d_acqua             | denominazione corso d'acqua             | Rio Bau Filixi                                                 |
| tipologia                 | tipo di costruzione diga                | A gravità ordinaria in muratura di pietrame con malta (a.1.1.) |
| altezza_ndt_2014__m_      |                                         | 41.00                                                          |
| altezza_dm_marzo_82__m_   |                                         | 44.75                                                          |
| vol__di_invaso__Mmc_      | volume dell'invaso in Mm³               | 4.30                                                           |
| quota_max_di_reg___m_slm_ |                                         | 201.00                                                         |
| uso_prevalente            | uso prevalente della diga               | Potabile                                                       |
| anno_inizio_lavori        | anno inizio lavori                      | 1931                                                           |
| anno_fine_lavori          | anno fine lavori                        | 1937                                                           |
| indirizzo_google_maps     | indirizzo web della diga in Goolge Maps | https://goo.gl/maps/ZbgCAjdc6RLExSyx8                          |

## riduzione_idrica_datawrapper

È un file csv estratto dal [PDF](https://www.regione.sicilia.it/sites/default/files/2024-04/Mappa%20pdf.pdf)

| attributo | descrizione                                    | esempio |
| --------- | ---------------------------------------------- | ------- |
| pro_com_t | codice stringa ISTAT                           | 081001  |
| comune    | denominazione del Comune                       | Alcamo  |
| provincia | Denominazione della Provincia                  | Trapani |
| sigla     | sigla provincia                                | TP      |
| riduzione | riduzione fornitura idrica in %                | 10 - 20 |
| area_kmq  | superficie Comune                              | 130,89  |
| pop_2024  | popolazione residente ISTAT al 01/gennaio/2024 | 44683   |

## UTD_Palermo

È un file csv scaricato da [qui](https://dgdighe.mit.gov.it/categoria/articolo/_cartografie_e_dati/_dighe_di_competenza/UTDPA/)


| attributo      | descrizione              | esempio                |
| -------------- | ------------------------ | ---------------------- |
| id             | identificativo univoco   | 1                      |
| diga           | denominazione della diga | ANCIPA                 |
| narch          |                          | 527                    |
| sub            |                          | A                      |
| s1             |                          | NO                     |
| s2             |                          | SC                     |
| uso_prevalente |                          | IDROELETTRICO          |
| regione        | denominazione regione    | SICILIA                |
| provincia      | sigla della provincia    | EN                     |
| concessionario |                          | ENEL PRODUZIONE S.P.A. |

## cartella pdf

Contiene tutti i pdf delle tabelle e grafici degli invasi dal 2011 al 2024 scaricabili da [qui](https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/presidenza-regione/autorita-bacino-distretto-idrografico-sicilia/siti-tematici/risorse-idriche/volumi-invasati-nelle-dighe-della-sicilia)
