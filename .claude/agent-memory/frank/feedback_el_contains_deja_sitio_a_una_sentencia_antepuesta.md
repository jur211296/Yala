---
name: el-contains-deja-sitio-a-una-sentencia-antepuesta
description: Un source-scan que fija un cuerpo con `contains` sueltos deja vivos los mutantes que AÑADEN una sentencia delante; el 22-sep tres reabrían el ticket con todos los literales presentes y el orden correcto.
metadata:
  type: feedback
---

**Cuando el source-scan es la única red posible, fija el CUERPO ENTERO normalizado —lista de
sentencias trimmeadas, sin comentarios— y no una colección de `contains`.**

**Why:** el 2026-09-22, en `wiped-state-reaches-the-discard-gate-with-the-window-open`, escribí un
escáner del punto único del descarte con cuatro `contains` (el verbo, el `if let`, la llamada al
callback, y el orden por rangos). Una lente de la review compiló **tres mutantes que sobrevivían a
los ocho `#expect`** y los tres reabren el ticket entero:

- un `ICloudRestoreSessionSignal.noteRestoreAbandoned(flowToken)` **antepuesto**: pone el dueño a
  `nil`, así que el descarte de la línea siguiente se cae por su propio `guard` y no apaga nada;
- un `flowToken = nil` antes del `if let`: ni entra;
- una sentencia cualquiera de más.

En los tres, **el conteo daba 1, los cuatro literales estaban y el orden era correcto**. El `contains`
comprueba que algo está; no comprueba que no haya nada más, y lo que desarma un apagado no suele ser
quitarle una línea sino **ponerle una delante**.

Está escrito en `.claude/rules/testing.md` (la regla del source-scan como única red, L167) y aun así
lo volví a hacer: la regla dice «fija el cuerpo ENTERO normalizado, paso a paso en una lista, y el
orden de lo que dependa del orden», y yo hice solo la segunda mitad.

**How to apply:**

- El molde que quedó en `ICloudRestoreSignalTests.everyPathToTheDiscardGateClosesTheSessionWindow`:
  `body(of:)` → `split("\n")` → `trimmingCharacters` → `filter { !$0.isEmpty }` → `#expect(sentencias
  == [...])`. Con el array literal, el orden viaja gratis y el `#expect` de rangos sobra.
- **El aviso cuesta una frase:** si el cuerpo que fijas tiene menos de diez sentencias, fíjalo entero.
  Por encima de eso, el `contains` es una decisión que hay que justificar y un mutante que hay que
  compilar.
- Y el corolario de conteo: **cuenta el IDENTIFICADOR, no la llamada.** `onStartFresh()` no ve
  `action: onStartFresh` (minúscula), `self.onStartFresh` ni `.onTapGesture(perform:)` — tres formas
  de **ENTREGAR** el callback en vez de llamarlo, y la segunda era la firma interna del helper de la
  propia vista. Contando `onStartFresh` a secas, las apariciones legales son la declaración y la
  llamada del punto único, y cualquier tercera cae.

Relacionado: [[el-source-scan-de-dos-literales-no-es-una-red]] (el hermano: literales sueltos cuando
el target es inalcanzable) y [[la-asercion-que-no-puede-fallar]].
