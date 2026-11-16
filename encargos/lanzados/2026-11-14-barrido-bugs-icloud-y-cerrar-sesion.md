Yala
# Arreglar iCloud y cerrar sesión: iCloud vaciado, Volver a tu iCloud colgado, copia al iCloud privado y vista de cerrar sesión
---
card: tablero-icloud-recien-vaciado-yala-dice-ya-tiene-zy1d
toca: Yala/Services/CloudSync/, Yala/App/Views/SignOut/, Yala/App/Views/Profile/YalaAccountView.swift, Yala/App/Logic/YalaAccountLogic.swift, Yala/App/Logic/CloudSignOutFlowLogic.swift, Yala/App/Logic/ReverseICloudPriorDataLogic.swift, Yala/App/Logic/RestoreFoundRowsLogic.swift, Yala/App/Logic/ICloudCorpusChipsLogic.swift, Yala/App/Logic/AdoptOverCloudGuardLogic.swift, Yala/App/Logic/WelcomePrivateICloudGateLogic.swift, Yala/App/Logic/CloudWelcomeSignInFlow.swift, Yala/App/ContentView.swift, YalaTests/BarridoBugsLoteB/, docs/ux/revision-vistas-2.3/README.md, tickets/backlog/barrido-bugs-lote-b.md, tickets/done/barrido-bugs-lote-b.md
depende: Yala/barrido-bugs-entrar-y-bienvenida
esfuerzo: high
cierre: cierra-sola
---

Segundo lote de bugs que devolvió el barrido de QA en el iPhone del 14-nov (versión 2.3). Jürgen pidió encolarlos ya, delante de las mejoras. Evidencia, pasos y esperado: `docs/qa/barrido-iphone-2026-11-14/lista.md`, su carpeta `evidencia/` y cada card del tablero. Va después del lote de entrar a la cuenta y la bienvenida porque comparten archivos; parte de lo que ese lote dejó mergeado en 2.3.

Cards de este lote (en un solo PR y un cierre):
1. tablero-icloud-recien-vaciado-yala-dice-ya-tiene-zy1d: con el iCloud recién vaciado, Yala dice «Ya tienes datos en tu iCloud — 62 categorías».
2. tablero-volver-a-tu-icloud-se-queda-en-traer-tus-atde: «Volver a tu iCloud» se queda más de 6 minutos en «Traer tus datos de tu cuenta de Yala», también tras reabrir.
3. tablero-una-cuenta-en-la-nube-copia-sus-datos-al-4lld: una cuenta en la nube copia sus datos al iCloud privado del teléfono.
4. tablero-cerrar-sesion-una-vista-propia-con-spinn-p9q0: cerrar sesión con una vista propia con spinner, sin pedir reabrir Yala salvo que haya iCloud de por medio.
5. tablero-revision-por-vistas-2-3-indice-de-cobert-f8pd: poner al día el índice `docs/ux/revision-vistas-2.3/README.md` (cobertura y decisiones pendientes) con lo que ya está mergeado.

Busca la causa raíz; si varios comparten causa, arréglala una vez. La copia de una cuenta en la nube al iCloud privado es pérdida o mezcla de datos: cuida que el arreglo no borre nada del usuario. Cualquier cambio de esquema de CloudKit en Production es vital y se pregunta según el modo; en Development puedes avanzar. Tests nuevos en `YalaTests/BarridoBugsLoteB/`. Si necesitas un archivo fuera de `toca:`, que sea un cambio mínimo y anótalo en el cierre.

Pruebas: de punta a punta en el iPhone 14 conectado por DeviceMCP, repitiendo los pasos del barrido, con la cuenta test@ y capturas o video de antes y después. Puedes usar un segundo simulador si lo necesitas (en la Max el tope es 2). Una prueba que requiera a Jürgen en persona queda en la card con los pasos exactos, sin inventar acceso.

Commits y PR sin firma de IA. El resumen del cierre es un artifact visual de Claude con antes y después por card. Cada card arreglada pasa a in qa; la que no, sigue en backlog con lo encontrado. Termina con /cerrar-total si el trabajo está completo y el modo lo permite.

## Paso 0 — decisiones

> Resueltas en semi, sin consulta (ninguna es vital ni destructiva): las recomendaciones se dan por buenas. Se discuten en el PR.

**Medido antes de decidir (14-nov, 10:10–10:50):**
- El lote A (`depende:`) está abierto y en cola de auto-merge. El arreglo de «Volver a tu iCloud sin atasco» y del iCloud recién vaciado (PR del 13-nov) **sigue abierto con todo en verde desde el 13-nov**: chocaba solo en `docs/DECISIONS.md` y `docs/TICKETS.md`. El barrido probó una build sin él (493d5c53d no lo contiene): las cards de iCloud vaciado y de «Volver a tu iCloud» fallaron sobre código sin el arreglo.
- En las cuatro consolas del barrido no hay ni un `iCloudSync: event received` (un montaje con espejo emite al menos `setup` al arrancar, y la línea sale en DEBUG). «Remote CloudKit change» lo imprime el observador de `.NSPersistentStoreRemoteChange`, que salta con cualquier escritura de otro coordinador: no prueba espejo. ⇒ el cierre de sesión no se saltó el cambio en caliente por espejo (`skippedMountHasMirror`): abortó el release.
- `releaseModelContextsForSwap` no suelta `GroupSettlementReminderService` ni `GroupBudgetAlertService`, que reciben el contexto en `ensureNotificationsScheduled` (solo con notificaciones permitidas). Un contexto retiene su contenedor ⇒ sentinel vivo ⇒ aborto ⇒ «Vuelve a abrir Yala».
- «Cargar datos de prueba» usa `SeededRandom(seed: 42)`: 2.351 registros salen en cualquier modo el mismo día, así que la coincidencia con «Tu iCloud ya tiene 2351» no prueba exportación. El 13-nov la misma prueba en la cuenta encontró 554 registros en iCloud, no miles.

**D1 · Base** → rama sobre el lote A + merge del PR del 13-nov (conflictos de docs resueltos con la versión de 2.3). Por qué: son las cards 1 y 2 de este lote y su código ya pasó el CI. Alternativa descartada: rehacerlo (duplicaría trabajo verificado).

**D2 · Cerrar sesión pide reabrir (p9q0)** → soltar los dos contextos en `releaseModelContextsForSwap` + test de paridad por escaneo de fuente: todo `X.shared.setContext(<algo>)` del árbol tiene su `setContext(nil)` en el release. Por qué: es la causa leída en el código y casa con lo medido; el escaneo evita que el próximo servicio vuelva a romperlo. `AppBootstrapper.swift` queda fuera de `toca:` (cambio mínimo, anotado).

**D3 · Rastro del cambio en caliente en la consola** → los breadcrumbs del swap imprimen también en DEBUG. Por qué: el barrido no pudo ver el motivo (Logger no sale en la consola de devicectl).

**D4 · Nota «copia de antes de pasar a tu cuenta» (zy1d)** → sale solo si el faro está enlazado, la copia trae movimientos o cuentas **y** ningún movimiento de la copia es posterior a la fecha de enlace del faro (`linkedAt`). Sin `linkedAt` (faro viejo) o sin movimientos, se conserva la regla del PR del 13-nov. Por qué: el barrido creó «Prueba» en iCloud después de enlazar y la nota mentía. Alternativa descartada: borrar el faro al volver a iCloud (toca el relevo de cuentas, mucho más riesgo).

**D5 · Los 40 s de «Revisando qué hay en tu iCloud…»** → se miden en el iPhone; sin causa medida no se toca la sonda (su ticket `private-icloud-gate-takes-almost-a-minute-to-check` sigue). Por qué: el criterio de la card no incluye el tiempo y la sonda borra/decide sobre iCloud.

**D6 · Cuenta en la nube copia al iCloud privado (4lld)** → medir antes de tocar: en el iPhone 14, cuenta en la nube + datos de prueba, y comprobar (a) eventos del espejo en consola, (b) tablas del espejo en el store copiado, (c) lo que cuenta «Volver a tu iCloud» antes y después. Si no exporta, la card pasa a QA con la medición y sin código; si exporta, se arregla.

**D7 · «Volver a tu iCloud» (atde)** → lo arregla el PR del 13-nov; aquí se prueba en el iPhone.

**D8 · Índice de revisión por vistas (f8pd)** → poner al día `docs/ux/revision-vistas-2.3/README.md` con las 11 fichas mergeadas y las decisiones de `decisiones-discusion.md`; sin HTML/PDF nuevos (el hechaCuando viejo pedía HTML+PDF, pero la card del barrido solo pide el índice veraz).

**D9 · Esquema de CloudKit** → ningún cambio.

**D10 · Decisiones pendientes de Jürgen** → el lote del 14-nov ya está en `docs/DECISIONS.md`; se le añade la del 07:16 (despliegue de `CD_systemRoleRaw` hecho por Dan).
