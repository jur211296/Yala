# Arreglar el falso «tus datos fueron eliminados de iCloud» al apagar iCloud Drive (card i1o5)

## Contexto
Card `tablero-apagar-icloud-drive-hace-que-yala-diga-t-i1o5` (high, 2.1). QA guiado 15-oct, A2 en iPhone de QA: con iCloud Drive apagado, sin cambiar de cuenta, a los 5 s sale «Datos no disponibles · Tus datos fueron eliminados de iCloud» con «Empezar de cero». Los datos siguen en iCloud. Segunda cara: con Drive encendido, el aviso salió otra vez mientras corría la importación. Productor: gracia de 5 s en ContentView que mira filas a 0 y no mira `noAccount` ni importación en curso.

Cola: ahora, antes de 4nt6 y lote 17. Base origin/2.1. Si PR #514 sigue en auto-merge: fetch + rebase antes de abrir PR; no esperes su CI.

## Que se pide
1. La gracia de 5 s no pide el aviso en `noAccount` (remeir qué estado da Drive apagado).
2. Tampoco con importación de iCloud en curso.
3. Copy específico «iCloud no está disponible en este dispositivo» cuando toque, sin ofrecer wipe falso.
4. Tests de la decisión + evidencia simulador; anotar device-QA iPhone solo si hace falta Drive real.
5. Card al cerrar: done, o in qa solo si Jürgen debe probar en iPhone. Ticket/docs al día.

## Que NO hay que tocar
4nt6, lote 17, rediseño del wipe remoto legítimo. No pedir OK a Jürgen.
Pipeline serial: 1 sim; xcodebuild -jobs 2 sin sim; al cerrar apagar/erase y limpiar DerivedData de este worktree.

## Como se sabe que esta bien
Con Drive apagado no dice eliminados ni ofrece empezar de cero; al encenderlo vuelven. Con importación en curso no dispara. Tests verdes; PR a 2.1; cierra-sola con /cerrar-total sin esperar a Jürgen salvo validación URGENTE.

## Paso 0

Medido en el árbol (`8cd693cb6`):

- **Qué estado da Drive apagado.** `iCloudSyncService.isAccountAvailable` es `ubiquityIdentityToken != nil`, que mide iCloud Drive (regla L1674 de `swiftdata-cloudkit.md`): con Drive apagado da `false` y `checkAccountStatus()` pone `.noAccount`. La otra puerta de `.noAccount` es el `CKError.notAuthenticated` del espejo (`mirrorReportedNotAuthenticated`). La card lo confirma en el iPhone: `noAccount` + `tx=0`.
- **El productor.** `ContentView`, `onChange(of: hasPersonalData)` → `.startGrace` → tarea de 5 s → eje → `submit(.presentRemoteWipeNotice)`. Ni ahí ni en el drenaje (`presentRemoteWipeNoticeIfStillTrue`) se mira la cuenta ni la importación.

Decisiones (asumidas, sin preguntar: son técnicas o las fija el encargo):

1. **iCloud no disponible ⇒ otro aviso, no el de borrado.** Lo decide el DRENAJE, que es donde el aviso se enciende y donde ya se re-mide todo (el intent espera en cola). Señal: `!isAccountAvailable || mirrorReportedNotAuthenticated` (las dos fuentes de `.noAccount`, leídas directo; `status` puede quedar viejo bajo test). Lógica pura en `RemoteWipeGraceLogic.notice(…)`.
2. **El aviso nuevo** va por la MISMA cola, la misma condición viva (`remoteWipeNoticePending`, blocker de la matriz) y la misma red de presentación; solo cambia qué `.alert` monta (`showICloudUnavailableAlert`, segundo `.alert` en `ShellDataAlertsModifier`, botón literal «Entendido» → `dismissRemoteWipeNotice`). Sin «Empezar de cero». Avisar sin confirmar: no mueve datos.
3. **Importación en curso ⇒ se espera.** El vaciado remoto real también llega como importación (los borrados bajan por el espejo), así que no basta con callar: la gracia espera a que la importación se asiente (primer import del proceso sin terminar, `isImporting`, o actividad de import en los últimos 5 s; el primer término cubre el hueco medido de ~3 s entre que caen las filas y empieza la importación) y entonces decide. En el productor, bucle de 1 s tras los 5 s; en el drenaje, si hay importación, se re-arma la gracia. Sin techo: esperar solo retrasa un aviso informativo, y el sesgo del aviso es callar.
4. **Copy (es):** título «iCloud no está disponible en este dispositivo»; mensaje sin afirmar «tus datos siguen…» (vetado en la hermana) ni prometer que vuelve todo: «Yala guarda tus datos en tu iCloud y ahora no puede leerlos. Cuando iCloud vuelva a estar disponible, lo que tengas ahí volverá a aparecer. Puedes revisarlo en Ajustes, en iCloud.» «Dispositivo» y no «iPhone»: la app corre también en iPad (review). 16 locales con `add-l10n-key.sh`.
5. **Tests:** unit de la lógica pura + scans del cableado actualizados conscientemente (`RemoteWipeSignalWiringTests`, `RemoteWipeGraceLogicTests`). XCUITest: los 4 casos existentes pasan a `fakeICloud: true` (el simulador no tiene token = Drive apagado) y uno nuevo SIN él comprueba el aviso nuevo, sin «Empezar de cero». Es también la evidencia de simulador.
6. **Device-QA:** el simulador no puede apagar Drive con datos espejados ni lanzar una importación real ⇒ card a `qa` con guion para el iPhone (apagar Drive, ver aviso nuevo, encender, ver que vuelven y que no sale el de borrado durante la importación).

Fuera: 4nt6, lote 17, el rediseño del wipe remoto legítimo.

### Tras la review adversarial (una pasada, 4 lentes, refutación por hallazgo)

- **Arreglado:** la espera al primer import no tenía techo y un vaciado real (zona borrada desde Ajustes › iCloud, import con error) se quedaba sin aviso para siempre → techo de 60 s desde la caída (`firstImportCeilingSeconds`, `remoteWipeDropAt`).
- **Arreglado:** `hasPersonalData` no se recalcula con un import de CloudKit hasta un bump de `dataVersion`; con la persona quieta en el Panel, la gracia pedía el aviso sobre filas que ya habían vuelto → re-medido en vivo en cada vuelta de la espera y en el drenaje (`remeasurePersonalData`).
- **Arreglado:** sin red para el cableado de las señales → scans por igualdad de `currentRemoteWipeNoticeDecision()` y de la espera.
- **Arreglado:** copy con «iPhone» (la app corre en iPad) y con «aparecerán solos» (falso si el borrado fue real) → «dispositivo» y «lo que tengas ahí volverá a aparecer».
- **Residual aceptado:** encender Drive con la app viva (sin relanzar) solo protege el término `isImporting` y la ventana de 5 s; el primer import ya está hecho en ese proceso. Margen medido 2 s. Lo cubre el device-QA.
- **Residual aceptado:** el XCUITest nuevo da por hecho un simulador sin sesión de iCloud (la misma premisa que `-uitest-fake-icloud`).
