# Cola 2.2 · lote 12.2 Nube, iCloud y migración desde 2.0.4 (10 cards cierra-sola)

## Contexto
Jürgen (24-oct): seguir la cola 2.2 por lotes 12.x hasta cerrar todas las cards de 2.2; el barrido de QA estricto es el cierre final de 2.2. Ya cerraron 12.1 Grupos (PR #623, mergeado) y el Duo cerrado opción 2 (PR #624, en cola de merge a 2.2). Esta es la sesión **12.2 · Nube, iCloud y migración desde 2.0.4**. Base: `origin/2.2`, PR contra 2.2.

Son diez cards en «lista para lanzar», todas `cierra-sola` y versión 2.2. Léelas enteras con `tablero ver <id>` antes de tocar código (traen contexto, siguiente paso y hecha-cuando):

1. `tablero-al-volver-a-icloud-el-arranque-dispara-u-jbjj` (low) — Al volver a iCloud, el arranque dispara una falsa alarma de «modo nube con espejo de iCloud»
2. `tablero-borrarlos-de-tu-icloud-no-ensena-ninguna-cchh` (medium) — «¿Borrarlos de tu iCloud?» no enseña ninguna salida: solo «Borrar y volver a iCloud»
3. `tablero-con-icloud-drive-apagado-la-pantalla-de-90yc` (low) — Con iCloud Drive apagado, la pantalla de iCloud dice que iCloud no está activo aunque sincroniza
4. `tablero-con-icloud-drive-apagado-y-el-espejo-adj-2taf` (low) — Con iCloud Drive apagado y el espejo adjunto, los borrados del Welcome no empiezan nunca
5. `tablero-con-icloud-drive-apagado-antes-de-abrir-n5zw` (medium) — Con iCloud Drive apagado antes de abrir Yala, la app arranca vacía y no avisa de nada
6. `tablero-el-destino-de-un-favorito-de-transferenc-da5d` (low) — El destino de un favorito de transferencia no viaja por el Modo Nube
7. `tablero-ajustes-favoritos-no-sabe-editar-un-favo-93ta` (low) — Ajustes › Favoritos no sabe editar un favorito de transferencia
8. `tablero-si-la-2-0-4-seguia-en-segundo-plano-al-a-y2vg` (low) — Si la 2.0.4 seguía en segundo plano al actualizar, «Mira lo nuevo en Yala» no sale en el primer arranque
9. `tablero-tras-activar-la-nube-en-un-aparato-el-ot-vbf9` (medium) — Tras activar la nube en un aparato, el otro no lo propone solo
10. `tablero-tras-actualizar-desde-la-2-0-4-activar-l-9mc6` (low) — Tras actualizar desde la 2.0.4, «Activar la nube» se bloquea por una cuenta de grupos que el iCloud recuerda de otra instalación

## Qué se pide
1. Al empezar: mueve las diez a «in progress» con `--agente frank`.
2. Arregla cada una según su «hecha cuando». Preferible tests (unit / XCUITest) que cubran la regresión. Criterio estricto de barrido: solo deja en «in qa» a jurgen (con guion corto) lo grave que el simulador no valida (dos dispositivos, iCloud real puntual); lo demás a done.
3. Dudas: toma la opción recomendada y anótala en la card. Solo lo irreversible (borrar datos reales, esquema de CloudKit en producción, cobros) queda en «espera decisión» a jurgen con la pregunta y las opciones; el resto del lote sigue.
4. Tickets nuevos de lo que encuentres, con su card.
5. Si hay cambio visible, capturas antes/después en `capturas/` del worktree y listarlas en el cierre.

## Qué NO hay que tocar
- marketing/ y Web/.
- Ningún despliegue de esquema CloudKit a producción ni cambios en Supabase de producción.
- No inventar diseño nuevo: si hace falta decisión visual, déjala en «espera decisión» con capturas.
- No desactivar tests ni saltarse protecciones de rama.

## Cómo se sabe que está bien
Las diez cards cumplen su «hecha cuando» (o quedan en in qa / espera decisión con motivo), suite unit en verde, PR a 2.2 en auto-merge, `/cerrar-total`.

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, si #624 (u otro PR de la cola) sigue en CI, espera a que entre y rebasea una sola vez con el simulador apagado. Si 2.2 no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

## Mini
Pipeline serial Yala: limpiar sims muertos / DerivedData de sesiones cerradas / cachés de XcodeBuildMCP de worktrees que ya no existen (sin preguntar); build con `xcodebuild -jobs 2` sin sim booteado; un solo simulador iPhone para tests (el Duo ya no hace falta en esta sesión); al cerrar apagar y borrar ese sim y el DerivedData de esta sesión. Disco: hay ~25 GB libres, por debajo del umbral APRETADO de 32 GB: limpia sin preguntar antes del build.

/cerrar-total

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · jbjj — ¿callar el canario o cambiar lo que decide el candado sin journal?** → Solo el canario: no suena sin
journal conectado (`MigrationPhaseStore.isJournalConnected`). Por qué: con `.cloud` + espejo el motor ya queda parado,
que es lo correcto; lo único falso era la alarma. Alternativa descartada: que `canRunDomain` devuelva `false` sin
journal — cambiaría la decisión piggyback de Grupos en el primer `.active` del arranque (doble loop).

**D2 · cchh — ¿cómo se ve la salida?** → `Button(L10n.Common.cancel)` sin rol, con id, como «Ahora no» y la regla B6;
fuera el `.cancel` redundante del diálogo previo. XCUITest con el seam `found`.

**D3 · n5zw — ¿qué señal distingue «Drive apagado» para avisar?** → Ninguna: el aviso no es el arreglo. Con Drive
apagado el store se montaba con `.automatic`, que toma el primer contenedor de los entitlements — en `Yala Dev` el de
PRODUCCIÓN — y el espejo vaciaba la copia y reimportaba de otro contenedor (las dos mediciones del QA fueron en Yala
Dev, y al encender Drive volvía todo). Se nombra el contenedor (`.private(cloudKitContainerIdentifier)`), igual que
`.iCloudMirror`: con Drive apagado no cae nada. En `Yala` es el mismo contenedor que ya usaba. El «hecha cuando» de la
card (que salga «iCloud no está disponible») partía de esa premisa falsa; el criterio pasa a «con Drive apagado los
datos siguen ahí y no sale ningún aviso». Va a QA en el iPhone (no se mide en simulador).
Alternativa descartada: explicitar `.none` (cambia el comportamiento del parque sin iCloud) o perseguir otra señal.

**D4 · 90yc y 2taf — ¿qué testigo de cuenta?** → `iCloudSyncService.hasICloudAccount` = token de Drive **o**
`CKContainer.accountStatus() == .available`, refrescado al observar y al cambiar la cuenta. Lo usan el estado
`.noAccount` (pantalla de iCloud), `forceSync`, `forceFetchAndWait` y `waitForImportQuiescence` (borrados del Welcome), y
el «iCloud no disponible» de la gracia/arranque. Por qué: es la API de la cuenta de CloudKit, no puede discrepar del
canal; sin respuesta decide el token, como antes. Los gates de arranque (`BootSaveGateLogic`, `MigrationGateLogic`) y
la puerta de cierre de grupos (`groups-sign-out-quiescence-gate-fails-open-with-drive-off`) no se tocan: son otro ticket.
2taf no se mide en device: el testigo hace irrelevante si la población existe.

**D5 · da5d — ¿se despliega backend?** → No (fuera de alcance: nada en Supabase de producción). Se deja en el repo lo
que hace falta (DDL, manifest con `since`, emisión/aplicación de la ref con dangler) y el cliente solo emite la columna
cuando el Worker anuncia esa versión. El despliegue DDL → Worker queda como paso de Jürgen en la card.

**D6 · 93ta — ¿el editor gana el modo transferencia?** → Sí, con lo que ya hay: un favorito de transferencia se edita
con origen, destino (≠ origen), monto y descripción; sin categoría ni etiquetas y sin convertirlo a gasto/ingreso. Por
qué: el usuario no puede completar un favorito viejo sin destino de otra forma. Alternativa descartada: «bórralo y
vuélvelo a guardar», que deja la fila de Ajustes abriendo un editor que miente.

**D7 · y2vg, vbf9, 9mc6** → se arreglan según su «hecha cuando» con la opción que la card recomienda; lo que pida dos
dispositivos o iCloud real va a «in qa» con guion corto. Si vbf9 pide un diseño que no existe, queda en «espera
decisión» con capturas.

**D8 · vbf9 — ¿diseño nuevo?** → No: un aviso más del carrusel de avisos del Panel (`PanelNoticeCarousel`), con el molde
de `UpdateAvailableBanner`. «Activar» abre «Dónde viven tus datos» y arranca la activación del adopt, la misma que su
botón (confirmar + entrar con la cuenta: la sesión es por dispositivo). Cerrarlo vale para este arranque. Va a QA en dos
dispositivos, donde Jürgen da también el visto bueno visual.

**D9 · 9mc6 — ¿comprobar en el servidor que la cuenta asociada existe?** → No se puede: `/account/exists` pide el JWT
de ESA cuenta. Se toma la segunda opción de la card: si la asociación solo está en el iCloud-KV (otra instalación), la
hoja del bloqueo ofrece «Desasociarla y seguir» —el mismo `clear()` que «Desasociar» en «Grupos»— y vuelve a pedir la
cuenta. Con la asociación de ESTE dispositivo no cambia nada.

**D10 · y2vg — ¿reproducir en simulador?** → No es reproducible (pide una actualización desde la App Store con la app en
el selector). Arreglo defensivo de la hipótesis: un arranque en segundo plano no decide la hoja de Novedades; la decide la
primera activación. Va a done con la nota de que la confirma el QA de la próxima versión.
