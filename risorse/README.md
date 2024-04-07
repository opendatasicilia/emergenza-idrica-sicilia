# LEGGIMI

## Dighe_Sicilia

È un file csv estratto dal [PDF](https://www.regione.sicilia.it/sites/default/files/2024-01/2024.01.01_A_Tabella_volumi_invasi.pdf)

dove:

| attributo     | descrizione                                                | esempio                               |
| ------------- | ---------------------------------------------------------- | ------------------------------------- |
| coordinate    | concatenazione delle due coordinate Lat e Long (EPSG:4326) | 37.836222, 14.5628727                 |
| lat           | latitudine (EPSG:4326)                                     | 37.836222                             |
| long          | longitudine (EPSG:4326)                                    | 14.562872                             |
| diga          | nome della diga                                            | Àncipa                                |
| fiume         | fiume lungo il quale è presente la diga                    | Troina                                |
| lago          | lago nel quale è presente la diga                          | Lago Àncipa                           |
| comune        | Comune nel quale è presente òa diga                        | Cesarò                                |
| provincia     | Provincia nel quale è presente la diga                     | ME                                    |
| capacita      | capacità della diga espressa im Mm³                        | 30.40                                 |
| utilizzazione | come viene utilizzata l'acqua della diga                   | Potabile - Irriguo - Elettrico        |
| gestore       | gestore della diga                                         | Dipartimento dell'acqua e dei rifiuti |

## Riduzione_idrica_datawrapper

È un file csv estratto dal [PDF](https://www.regione.sicilia.it/sites/default/files/2024-04/Mappa%20pdf.pdf)

| attributo | descrizione                               | esempio |
| --------- | ----------------------------------------- | ------- |
| pro_com_t | codice stringa ISTAT                      | 081001  |
| comune    | denominazione del Comune                  | Alcamo  |
| provincia | Denominazione della Provincia             | Trapani |
| sigla     | sigla provincia                           | TP      |
| riduzione | riduzione fornitura idrica in %           | 10 - 20 |
| area_kmq  | superficie Comune                         | 130,89  |
| pop_2024  | popolazione residente ISTAT al 01/01/2024 | 44683   |
