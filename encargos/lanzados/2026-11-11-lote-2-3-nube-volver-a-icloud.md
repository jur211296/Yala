Yala
# Decidido 9-nov 2.3 · Nube: volver a iCloud y «Activar sin borrar», en una hoja
card: tablero-2-3-nube-volver-a-icloud-y-activar-sin-b-anfw
toca: Yala/App/Views/Settings/, Yala/Services/CloudSync/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 53 y 57. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/41-nube-almacenamiento/ficha.md. V4 («Poder volver a la nube con la misma cuenta») queda fuera: está en espera de decisión y no se implementa aquí.

## Encargo y criterio de terminado
Implementar SOLO estos 2 puntos:
1. Volver a iCloud deja de prometer «en pausa por si vuelves». Opción V2: hoja con fases (qué pasa con cada cosa, incluido «volver a la nube con esta cuenta: hoy no se puede»), la elección con cifra en tarjetas si iCloud ya tiene datos («Sumarlos» / «Empezar sin ellos (los borra de tu iCloud)» / «Ahora no») y la confirmación; sustituye los tres globos; el botón de volver deja de ser naranja.
2. «Activar sin borrar» deja de cancelar un borrado pedido desde un globo. Opción A, mismo molde de hoja: dice que el borrado pedido no terminó y que, si se activa la nube, los datos de iCloud se quedan; opciones «Activar y conservar mis datos de iCloud» / «Terminar de borrarlos primero» / «Ahora no».

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Review adversarial: estas hojas mueven o conservan datos. No implementes V4 (volver a la nube con la misma cuenta).
- Usa los nombres de la decisión 51 («En tu iCloud» / «En tu cuenta de Yala») si ese lote aún no entró; no inventes un tercer nombre.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones

> Resueltas por Frank en modo semi (sesión lanzada, sin Jürgen delante). Las recomendaciones se dan por buenas y se discuten en el PR. D7 está consultada a Jürgen y espera su respuesta.

**D0 · ¿2.3 tiene lo de 2.2?** → Sí, para este lote. `origin/2.3..origin/2.2` = 16 commits, todos del arreglo de Grupos (borradores duplicados), del QA físico y de las subidas a TestFlight. Ninguno toca `Yala/App/Views/Settings/` ni `Yala/Services/CloudSync/` (`git log` vacío), y el merge corto de 2.2 en 2.3 ya entró. Se sigue sin `BLOQUEANTE`.
Por qué: el criterio «0 o casi 0» existe para no trabajar sobre una pantalla a la que le faltan arreglos de 2.2; esta no tiene ninguno pendiente.

**D1 · ¿Dónde se pregunta a iCloud si ya tiene datos?** → Al tocar «Volver a tu iCloud», como hoy, antes de abrir la hoja (el botón dice «Revisando tu iCloud…»). La hoja recibe la respuesta y abre en «qué pasa».
Por qué: conserva sin tocar la pregunta, su reintento y sus tres textos de fallo, que ya tienen tests. Alternativa descartada: preguntar dentro de la hoja al pulsar «Seguir», que obliga a rehacer los avisos de fallo como fases nuevas.

**D2 · ¿Qué dicen las cuatro filas de «qué pasa»?** → Tus datos: bajan a este dispositivo y suben a tu iCloud. Tu cuenta de Yala: sigue abierta para tus grupos. Lo que hay en ella: se queda guardado, sin usarse. Volver a la nube con ella: hoy no se puede.
Por qué: las cuatro están medidas en código (la vuelta no cierra la sesión, `reverse_complete` congela los datos en el servidor sin borrarlos, y el claim de esa cuenta vuelve con `existing_stable` → «Esta cuenta volvió a iCloud»). «Dispositivo» y no «iPhone» porque la vuelta existe también en el iPad.

**D3 · ¿Qué pasa con la tarjeta?** → Se quitan «sin perder nada» y la nota «queda en pausa por si vuelves». La tarjeta dice que tus datos vuelven a este dispositivo y a tu iCloud y que antes se cuenta qué pasa con cada cosa. El botón deja el naranja: queda como botón secundario con el color de la app.
Por qué: es lo que la decisión 53 pide retirar; el detalle va en la hoja.

**D4 · Nombres** → «tu iCloud» y «tu cuenta de Yala», con el verbo «Volver a» (decisión 51). El lote de nombres (T1) no ha entrado en 2.3, así que solo se renombra lo que toca este lote: título y botón de la tarjeta, y la hoja. «Volviendo a iCloud» del progreso y el resto de la pantalla se quedan para T1.

**D5 · ¿Cuándo empieza la vuelta?** → En el `onDismiss` de la hoja, con la elección que la hoja devuelve (molde de la hoja de activar, regla 4 de presentaciones). «Ahora no», «Cancelar» y deslizar no empiezan nada.

**D6 · Textos que quedan muertos** → Se borran del catálogo y de `L10n` los que solo usaban los tres globos (`storage.confirm.revertTitle`, `revertBody`, `revert2Confirm`, `storage.revert.desenlaceNote`, `storage.revert.prior.body`, `bodyNoCount`, `discardConfirmTitle`, `discardConfirmBody`, `discardConfirm`). Los que ya estaban muertos antes (`revertContinue`, `revert2Title`, `revert2Body`) no se tocan: no son de este lote.

**D7 · Punto 2: qué es «Terminar de borrarlos primero»** → **Jürgen eligió la opción 1 (respuesta del 11-nov por la tarde).** Medido: el borrado pendiente es el «empezar de cero». Terminarlo se lleva también todo lo de este dispositivo y vuelve al onboarding. Hay dos estados: sin empezar (iCloud intacto) y a medias (iCloud ya vacío). Recomendación enviada: la hoja dice la verdad en cada estado. «Terminar de borrar y empezar de cero» cierra Ajustes y abre la hoja que ya existe para terminar ese borrado. En el estado «a medias» no se dice «tus datos de iCloud se quedan».

**D8 · Tests de regresión** → Punto 1: XCUITest `ReverseICloudPriorDataUITests` (el área es determinista en `qa/coverage-index.json`): la hoja enseña «Volver a la nube con ella · Hoy no se puede» y la elección con cifra sustituye a los globos. Unit de la lógica de fases (`ReturnToICloudSheetLogicTests`). Punto 2: `PendingICloudWipeMigrationUITests`.
