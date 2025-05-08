// Funzione per aprire in una nuova scheda tutti i link esterni e i link ai file PDF
function targetBlankForPDFs() {
  // Ottieni l'host del sito corrente senza sottodomini
  var internal = location.hostname.replace("www.", "");
  var internalRegex = new RegExp(internal, "i");

  // Aggiungi un'espressione regolare per riconoscere anche gli indirizzi IP locali
  var localHost = /localhost|127\.0\.0\.1/;

  // Prendi tutti i link presenti nella pagina
  var links = document.getElementsByTagName('a');
  for (var i = 0; i < links.length; i++) {
    var href = links[i].href; // Ottieni l'URL di ogni link

    // Controlla se l'URL è considerato interno o esterno, e se punta a un file PDF
    if ((internalRegex.test(links[i].hostname) || localHost.test(links[i].hostname)) && href.endsWith('.pdf')) {
      // Se il link è interno (incluso localhost o IP locale) e punta a un PDF, apri in una nuova scheda
      links[i].setAttribute('target', '_blank');
    } else if (!internalRegex.test(links[i].hostname) && !localHost.test(links[i].hostname) || href.endsWith('.pdf')) {
      // Se il link è esterno o punta a un PDF, apri in una nuova scheda
      links[i].setAttribute('target', '_blank');
    }
  }
};

// Esegui la funzione per applicare la regola ai link
targetBlankForPDFs();
