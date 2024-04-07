// Funzione per aprire in una nuova scheda tutti i link esterni e i link ai file PDF
function targetBlankForPDFs() {
  // Rimuovi il sottodominio del sito corrente dall'URL e imposta un'espressione regolare per il confronto
  var internal = location.host.replace("www.", "");
  internal = new RegExp(internal, "i");

  // Prendi tutti i link presenti nella pagina
  var a = document.getElementsByTagName('a');
  for (var i = 0; i < a.length; i++) {
    var href = a[i].href; // Ottieni l'URL di ogni link

    // Controlla se il link punta a un file PDF interno o se è esterno (o punta a un PDF)
    if (internal.test(href) && href.endsWith('.pdf')) {
      // Se il link è interno e punta a un PDF, imposta l'attributo target a _blank
      a[i].setAttribute('target', '_blank');
    } else if (!internal.test(a[i].hostname) || href.endsWith('.pdf')) {
      // Se il link è esterno o punta a un PDF, imposta l'attributo target a _blank
      a[i].setAttribute('target', '_blank');
    }
  }
};

// Esegui la funzione per applicare la regola ai link
targetBlankForPDFs();
