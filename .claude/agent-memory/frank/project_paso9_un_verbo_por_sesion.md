---
name: paso9-un-verbo-por-sesion
description: Paso 9 del rediseño de sesiones — «Cerrar sesión» privada espera al export de iCloud y borra por archivos; device-QA NO simulable que empieza por un spike; la review cazó cinco graves MÍOS; deja 12 tickets y una decisión
metadata:
  type: project
---

**El paso 9 (`session-exits-one-verb-per-session`) está COMMITEADO y verificado (PR #138, 2026-09-11); lo único que falta es el
device-QA, y NO es simulable**: sin cuenta de iCloud en el simulador no hay espejo, así que el testigo del
export (historial de SwiftData contra el `startDate` del último export con éxito) solo se prueba en device.

**Why:** su guion empieza por un spike de tres supuestos que ningún test puede medir: (1) que el espejo firme
sus importaciones con autor `NSCloudKitMirroringDelegate…`, (2) que emita un evento de export tras cada save
y (3) que un export con éxito haya subido todo lo anterior a su inicio, también en lotes grandes. **Si falla
el (1), todo cierre privado acaba en la salida de emergencia con «1 cambio»**: fallo seguro, pero inservible.
Si falla el (3), el ancla daría por subido lo que no.

**How to apply:**
- Antes de tocar los cierres de `CloudSessionSignOut`, lee la regla de `swiftdata-cloudkit.md` («Una salida
  que borra lo local con el espejo montado…»). Tres cosas que parecen simplificables y no lo son: el ancla es
  el INICIO del export, sin ancla no hay número, y el último recuento va pegado al arm.
- Bajo `-uitest` el testigo del mount se queda en `.iCloudMirror` (el store de UITest corta antes de
  capturarlo), así que la hoja «sin copia» y su segundo gesto NO son alcanzables por XCUITest sin un seam.
- **Lo que la review adversarial cazó, y era mío**: el ancla avanzaba con exports fallidos (`as? CKError`
  filtraba el error), «Vaciar datos» en solo-grupos con espejo decía «No se tocan», F dejaba `.groupInvite`
  en el iCloud KV, la privada con sesión de grupos caducada descartaba su outbox en silencio y «Esperar»
  cancelaba el cierre. Todos arreglados; con ellos, 12 tickets.
- **Decisiones que esperan a Jürgen**: qué hacer con cambios de grupos que ya no tienen a dónde subir
  (`groups-outbox-rows-without-a-live-session-have-no-exit`), y aceptar el relanzamiento en el alta de Grupos
  para consumir este verbo desde la mitad 2 del paso 5.
- **La verificación de cierre, medida sobre el árbol final** (segunda sesión, tras el corte por tokens): unit
  6848/701 en verde, los dos builds sin warnings nuevos, XCUITest 62/62 clases con 139 casos verdes, y de los
  15 mutantes murieron 14. **El que sobrevive, M15, es un hallazgo**: el historial de SwiftData no entrega
  NINGUNA actualización por una reescritura idéntica, así que el filtro `> 0` de `PersonalExportPendingCounter`
  no es lo que produce ese cero y ningún test puede matarlo. Está escrito en la regla y en los dos docblocks.
- **El único rojo de XCUITest no era mío, y costó 90 s probarlo**: `TransactionsCrudUITests.test_createTransaction`,
  el flaky de `transaction-save-helper-flake-one-per-suite`. Ese día NO se mudó de víctima —repitió a solas dos
  veces—, así que la comprobación de «re-córrelo a ver si cambia» no valía; lo que zanjó fue correr la clase
  sola en un worktree desde `ba618216`, donde cae igual.
- **Choque anunciado**: la rama `encargo/2026-09-10-groups-entry-on-a-mirrored-store-still-blocks-the-owner`
  (sin PR) toca 23 ficheros del paso 9; su añadido a este ticket ya está incorporado.

Relacionado: [[rediseno-sesiones-dos-ejes]] · [[ramas-aparcadas-tocan-tu-ticket]] ·
[[review-adversarial-caza-lo-mio]] · [[un-gate-derivado-de-una-ausencia-falla-abierto]]
