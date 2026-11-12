---
id: tag-sheet-new-name-field-never-idles-in-xcuitest
status: done
priority: low
area: "transactions, tags, testing"
created: 2026-10-23
source: "lote decidido 2.2 · 02, sesión B (gate del formulario)"
updated: 2026-10-26
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

## Cerrado sin reproducir (2026-10-26, sesión «tests rojos 2.2»)

Sobre `origin/2.2` (`be99a2256`), iPhone 17 Pro, iOS 27.0: **16 corridas del caso y ni una espera de 60 s**
(«App animations complete notification not received» = 0 en todos los logs), todas en 25-30 s:

| Condición | Corridas |
|---|---|
| suelta, primera tras arrancar el simulador | 1 |
| justo después de la suite unitaria entera en el mismo arranque (la del gate del 23-oct) | 10 seguidas |
| con `HardwareKeyboardLastSeen = 1` escrito en el simulador (modo teclado físico, `.claude/rules/testing.md`) | 2 |
| dentro de su suite entera (`TransactionFormDecided02BUITests`, 6 casos × 3) | 3 |

**Qué animaba: no se sabe**, porque no se pudo reproducir; el mutante del detent no discrimina nada si la espera no
sale. No se tocó producto. Lo que cambió en el formulario desde la medición (`77f62f037`, 23-oct) es el lote 12.3
(`3076a6ce9`, accesibilidad y formularios que dicen qué falta). La prueba del teclado físico no verificó que el
simulador aplicara el modo (sin `cfprefsd` reiniciado). Si vuelve a salir, el log del gate con el caso basta para
reabrir: la espera es por gesto y deja la línea de arriba.
