---
hide:
  - navigation
  - toc
---

# Documenti utili

| titolo | data | a cura di | file |
| --- | --- | --- | --- |
| Mappa delle riduzioni delle forniture idriche | 2024-04-05 | Regione Siciliana Presidenza Autorità di Bacino del Distretto Idrografico della Sicilia | [apri](2024-04-05_mappa-riduzioni-forniture-idriche.pdf) |
| Individuazione delle azioni e buone pratiche finalizzate al risparmio idrico potabile ed alla riduzione dei consumi | 2024-04-04 | Regione Siciliana Presidenza Autorità di Bacino del Distretto Idrografico della Sicilia | [apri](risparmio_idrico_azioni_pratiche.pdf) |
| Diminuzione del 50% dei volumi degli invasi: scatta a Palermo dal giorno 5 aprile il piano d'emergenza Amap. Riduzione della pressione in rete per garantire l’acqua sino al prossimo inverno | 2024-04-03 | AMAP s.p.a. | [apri](diminuzione_volumi_invasi_piano_emergenza_amap_palermo.pdf) |
| Proposta di dichiarazione dello stato di emergenza nazionale ai sensi dell'art. 7 c.1 lett. c) ed art. 24 del D.Lvo 2.1.2018 n°1. | 2024-04-03 | Presidenza della Regione Siciliana Dipartimento regionale della Protezione Civile | [apri](emergenza_nazionale_art7e24_dlvo2018n1.pdf) |
| II Relazione alla cabina di regia, Commissario Straordinario Nazionale per l’Adozione di Interventi Urgenti Connessi al Fenomeno della Scarsità Idrica | 2024-02-27 | Presidenza del Consiglio dei Ministri | [apri](relazione_cabina-regia_commissario-straordinario-nazionale_interventi-scarsita-idrica.pdf) |


## Nota

La tabella è generata a partire dal file [`archivio_documentale.yml`](archivio_documentale.yml) con il comando:

```bash
<archivio_documentale.yml yq -c '.[]' | \
mlr --ijsonl --omd rename a_cura_di,"a cura di" then \
put '$file="[apri](".$file.")"' then reorder -e -f file >output.md
```
