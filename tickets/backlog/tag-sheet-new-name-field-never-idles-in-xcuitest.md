---
id: tag-sheet-new-name-field-never-idles-in-xcuitest
status: backlog
priority: low
area: "transactions, tags, testing"
created: 2026-10-23
source: "lote decidido 2.2 · 02, sesión B (gate del formulario)"
updated: 2026-10-23
---

# Al escribir en «Nueva etiqueta», XCUITest a veces no ve la app en reposo

## Lo medido (2026-10-23, iPhone 17 Pro, iOS 27.0)

- `TransactionFormDecided02BUITests#test_newTag_withOnlyAName_isCreatedAndPut` escribe en el campo nuevo de la hoja de
  etiquetas (L2-10) y, en 2 de 5 corridas, XCTest espera 60 s por gesto con «App animations complete notification not
  received, will attempt to continue». El caso pasa igual (266 s en vez de 26 s). En las otras 3 corridas, ninguna espera.
- Las dos veces fue en la corrida del gate, tras la suite unitaria entera en el mismo arranque del simulador.
- La hoja abre a media altura (`SelectorSheetSizing.mediumFirst`) con un campo de texto dentro: al salir el teclado iOS
  la sube, y su fondo (`.transparent`/`.subtle`) depende del detent elegido. Hipótesis sin medir: un ir y venir entre
  detents mientras el teclado entra.

## Hecho cuando

- Se sabe qué anima sin parar (Instruments o un mutante que fije el detent a `.large` al enfocar el campo).
- Diez corridas seguidas del caso sin una sola espera de 60 s.
