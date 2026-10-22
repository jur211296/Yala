# En el adopt, lo que un líder desplazado exporta tarde no debe duplicar movimientos

## Contexto
Tras #245 (el líder desplazado tras el cutover: premisa falsa → ticket a discarded; queda un test que fija la restauración de identidades antes de la primera petición de red) y #243/#244 (identidad del relevo / tombstone en la ventana del relevo), queda abierto el residual del Paso 0 de #243: `tickets/backlog/adopt-window-late-leader-identity-export-can-duplicate-after-the-remount.md`.

Cola A autónoma (mediums del callejón nube: migración / adopt / claim / restore / sign-out / wipe / detach / attest…). Hora Lima nocturna (antes de 06:00): eliges la opción robusta / good-practice sin AskUserQuestion; solo aparcas si hace falta device/secrets de Jürgen o una decisión demasiado grave para asumir.

Arrancas en contexto limpio: no viste el chat ni el cierre de #245. Lee el ticket y el código actual en `2.1`.

## Que se pide
Cierra el ticket `adopt-window-late-leader-identity-export-can-duplicate-after-the-remount`:
- Mide si la ventana del adopt es alcanzable en la práctica cuando un líder desplazado exporta tarde a iCloud mientras el segundo teléfono adopta.
- Si es alcanzable y duplica: arréglalo de forma robusta (no la opción más simple). La ida ya restaura identidades (`MigrationWorkExecutor.restoreRelayIdentities`); el adopt no pasa por ahí — el espejo sigue vivo y el pull tras el remonte puede crear born-remote con la copia del backend si la identidad cambió.
- Si la premisa no se sostiene (como en #245): documenta la medida, deja el test/contrato que fije lo medido, mueve el ticket a discarded (o done según corresponda) y no inventes un arreglo que abra un hueco peor.
- Criterios del ticket: medido si la ventana es alcanzable; si lo es, que no duplique.
- Gate verde; review/mutantes según el playbook del repo; PR a `2.1`; merge; board del repo + `docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en este encargo: implementa hasta cerrar. Bugs o decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo para ante device/acceso real de Jürgen o decisión demasiado grave para asumir de noche.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Que NO hay que tocar
- `marketing/` y Web/ (Lola).
- No relanzar `displaced-leader-after-the-cutover-restores-its-own-identity-over-the-relays` (ya discarded en #245).
- No paralelizar otro encargo Yala: cupo serial 1.
- No pedir a Jürgen QA de iPhone salvo que el ticket lo exija de verdad para cerrar.

## Como se sabe que esta bien
- Ticket movido (done / discarded / qa según el caso) con `docs/TICKETS.md` coherente.
- PR mergeado a `2.1` o cierre documentado si se descarta con medida.
- Gate en verde en el destino que sí resuelve en esta Mac (ver ESTADO: id del simulador iPhone 17 Pro 26.5 si `name=` sin OS= falla).
- Aviso de cierre al webhook con resumen en lenguaje de usuario.

## Paso 0

Decisiones de la sesión nocturna, sin Jürgen delante: auto-contestadas.

1. **Qué gana CloudKit sigue sin medir** (pide dos teléfonos y un corte de red). Se diseña para el peor caso, como en
   #243: la decisión del repo es esa y el canario `cloudRelayIdentityRestored` es quien lo mide en la flota.
2. **La ventana del ticket es la pequeña.** Medido en el código, no una sino dos:
   - **antes del reconcile** (la grande): del remonte del relevo al adopt pueden pasar días. Con el marcador del líder,
     la guarda de linaje se salta el casado (`adoptLineageGate` sale en `adoptLineageProven`), así que la fila que llegó
     re-identificada sube como huérfana y el duplicado queda EN EL BACKEND, para todos los teléfonos. Le pasa también al
     líder desplazado cuando entra en la cuenta: la regla decía que el linaje del adopt le re-identificaba sus filas, y
     con el marcador no lo hace;
   - **del reconcile al remonte** (la del ticket): el runtime arranca tras el remonte, drena y hace pull sin mirar nada.
3. **Arreglo, por ventanas:**
   - antes del reconcile: con el marcador, las filas sin identidad del backend se casan por clave de linaje ÚNICA con las
     que faltan, la misma función del camino sin marcador. (Primera versión: solo las que traían identidad. La review
     mostró que en un reintento el backfill anterior ya se la había dado, así que el resultado dependía de si el push
     falló: se incluyen todas.) **Sin bloquear** lo que no casa: bloquear dejaba fuera para siempre las filas nuevas que el líder
     desplazado creó sin red (que no están en el backend), y con ellas a todo teléfono que adopte. Lo que no casa sube
     como antes: residual con ticket;
   - del reconcile al remonte: el adopt siembra el registro fila → identidad (`RelayIdentityLedger`) y captura las
     coordenadas de sus testigos, y deja una marca. El runtime, al arrancar tras el remonte y antes de su primer drain,
     devuelve a su identidad las filas que el espejo cambió (por `Z_PK`, sin leer los metadatos de CloudKit, cuya
     lectura tras el remonte no está medida) y marca el registro para retirarlo. Los borrados de la ventana los traduce
     el drain con ese mismo registro (#244), sin cambios;
   - en un reintento del adopt, la misma restauración por registro al empezar, solo hacia identidades que el backend
     conoce o que ya esperan en el outbox (la review cazó que, sin el outbox, una huérfana encolada con el push fallido
     subía con las dos identidades).
4. **Solo hacia identidades del backend.** En el líder desplazado el testigo huérfano es SU identidad, que el backend no
   tiene: la restauración por coordenadas de la ida la pondría. Por eso el adopt no llama a `restoreRelayIdentities`.
5. **Alcance:** la ida no cambia (su reconcile de `done` sigue marcando el registro). Casar las filas sin identidad con
   marcador cierra de paso parte del residual (c) del adopt (import lento con clave única): se incluye por coherencia
   entre pasadas, no por alcance.
7. **Review adversarial** (tres lentes): sin regresión del adopt legítimo ni camino que ponga a una fila la identidad de
   otra. Corregido: el outbox en `onlyTo`, las filas sin identidad en el casado, un test que no discriminaba tres
   negativos, rastro en el fallo. Anotado en el residual: gemela borrada en el backend y tipos de cambio.
6. **Device-QA:** no. Se prueba entero en unit; lo que queda del dispositivo es qué gana CloudKit, y lo mide el canario.
