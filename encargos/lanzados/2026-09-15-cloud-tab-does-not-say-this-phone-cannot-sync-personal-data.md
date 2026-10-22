# Aviso fijo en lo personal cuando este teléfono no puede sincronizar (hermano de #176)

## Contexto
Ticket: `tickets/backlog/cloud-tab-does-not-say-this-phone-cannot-sync-personal-data.md`
Hermano de PR #176 (Grupos ya tiene aviso fijo con veredicto App Attest terminal). La mitad personal solo se entera al cerrar sesión (#175). La racha es la misma; el dato ya está.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, mover/actualizar ticket en `tickets/` y actualizar `docs/TICKETS.md` (índice = disco, conteos correctos), merge a 2.1 y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. NO sync al store/Kanban del panel ni a `kanban-inbox.json` ni a `/api/tasks`.

NOCHE (América/Lima, después de 21:00): elige lo recomendado sin AskUserQuestion. Si la decisión es demasiado importante para asumirla, aparca el ticket (ticket propio / no inventar) y cierra limpio.

Decisión de producto del ticket — asumir la recomendada:
1) Aviso fijo espejo del de Grupos, con el copy de cierre (`settings.signOutAttestTitle` + qué puede hacer, incluido exportar del #175).
2) Superficie: elige la menos intrusiva que siga siendo visible (preferir Ajustes / banner de sync de nube sobre un aviso permanente en el Panel, salvo que el código y el patrón de #176 digan otra cosa con evidencia). Documenta la elección en el PR.
3) No «dejarlo» — el ticket existe porque Grupos ya lo resolvió y lo personal no.

Molde: `GroupsAttestTabNoticeLogic`, `GroupsAttestStreakStore.didChangeNotification`, patrón #175/#176. No reabrir #176 salvo reutilizar patrón.

## Qué se pide
Implementar el aviso fijo para el canal personal cuando el veredicto Attest es terminal; tests; review; merge a 2.1; `/cerrar-total`.

## Qué NO hay que tocar
`marketing/`. No sync Kanban/centro de mando. No inventar product decisions irreversibles de datos/prod.

## Cómo se sabe que está bien
Quien usa la nube personal ve el aviso sin tener que ir a cerrar sesión; se va solo cuando deja de ser terminal; gate/CI verdes; board del repo al día (`tickets/` + `docs/TICKETS.md`); PR mergeado; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Dónde vive el aviso?** → **En dos sitios: el Panel y `syncStatusSection` de «Dónde viven tus datos».**
Por qué: el encargo pide «la menos intrusiva que siga siendo visible, prefiriendo Ajustes salvo que el código diga
otra cosa con evidencia», y el código la dio. **(a)** La superficie de Ajustes que el encargo prefiere existe
—`StorageSettingsView.syncStatusSection`, el «banner de sync de nube»— y **hoy dice lo contrario**: su rama `else`
pinta un check verde «Todo al día» para cualquier estado que no sea `.stoppedUntilSignIn`, y el attest terminal deja
el runtime en `.stoppedUntilRelaunch` (medido: `CloudMigrationController.refreshSyncBanner` líneas 653-664,
`CloudSyncRuntime.RuntimeState` línea 110). Poner el aviso en el Panel y dejar ahí el check verde sería la app
contradiciéndose a tres toques. **(b)** Pero Ajustes SOLO no cumple el criterio de éxito del encargo —«ve el aviso
sin tener que ir a cerrar sesión»—: esa sección está más lejos que el propio botón de cerrar sesión, ambos dentro de
Perfil. Quien apunta gastos que no llegan no entra ahí nunca.
Alternativas descartadas: **solo el Panel** (deja viva la mentira del check verde); **solo Ajustes** (no cierra el
hueco del ticket: cambia un sitio al que hay que ir por otro sitio al que hay que ir); **un overlay global junto a
`SyncStatusBanner`** (es el de iCloud, una píldora pequeña flotando ENCIMA del contenido en todos los tabs — más
intrusivo que un banner en el scroll, que es justo lo que el encargo pide evitar).

**D2 · ¿En qué parte del Panel?** → **En la pila de banners del scroll, el PRIMERO de todos, antes del hero.**
Por qué: el Panel ya tiene su patrón para los avisos de estado —`UpdateAvailableBanner`, `TrialBanner`,
`GroupNudgeBanner`, `ContextualGuideBanner` van dentro del `ScrollView`, no en un `safeAreaInset`— y seguirlo es
menos intrusivo que el inset fijo de Grupos, que roba altura permanente. Va el primero porque es el único que no
ofrece nada: los demás son ofertas y avisos de novedad; éste dice que los datos no están subiendo.
Alternativa descartada: `safeAreaInset(edge: .top)` como en Grupos — allí era correcto porque la pestaña Grupos no
tiene pila de banners; aquí rompería el patrón de la pantalla.

**D3 · ¿Qué dice, y lleva botón?** → **Título reusado (`settings.signOutAttestTitle`, «Este teléfono no puede
sincronizar tus datos») + cuerpo nuevo, sin X y sin botón.**
Por qué: mismo razonamiento que el hermano de Grupos — describe un estado que sigue ahí después de leerlo, así que
descartarlo solo serviría para ocultarlo, y no hay acción que lo arregle desde este teléfono (reintentar es lo que
lleva un día fallando). El cuerpo ofrece las dos salidas ciertas: usar otro teléfono, y exportar los datos, que el
#175 ya construyó. Reusar el título hace que la avería se llame igual en los tres sitios donde ya aparece.
Alternativa descartada: un botón «Exportar» en el propio aviso — superficie de acción nueva no pedida, y la
exportación ya vive en Perfil › Datos y dentro del alert de cierre del #175.

**D4 · ¿Qué condiciones lo gobiernan?** → **Tres: veredicto terminal Y `storageMode == .cloud` Y sesión viva.**
Por qué: la racha describe al TELÉFONO y la escriben los dos motores, así que el veredicto solo es falso para dos
poblaciones. `storageMode == .cloud` es el espejo del consent de Grupos y el término que más excluye: quien tiene
sus datos en su iCloud privado —la mayoría hoy— puede arrastrar una racha entera de Grupos sin mandar un movimiento
personal a nuestro servidor.
Alternativas descartadas: **`CloudRemoteFlags.cloudModeEnabled`** (fail-closed ante snapshot ausente, el bug exacto
que la review del #176 cazó: un teléfono restaurado se quedaba sin aviso); **`syncRuntimeEnabled`** (no excluye a
nadie — con el motor apagado los datos tampoco suben, sería un `&&` constante); **`AccountKind`** (habla de la
cuenta, y la pregunta del aviso es sobre este teléfono).

**D5 · ¿El «Todo al día» de Ajustes va en este cambio o a ticket propio?** → **En este cambio.**
Por qué: no es un bug ajeno que aparece de paso, es la misma avería en la superficie que el propio ticket nombra
(«¿el Panel? ¿Ajustes?»), y la incoherencia la crearía mi cambio. Es una rama más en un `if` que ya existe.
Alternativa descartada: ticket propio — dejaría la app diciendo dos cosas opuestas sobre el mismo hecho mientras el
ticket espera.

**D6 · ¿Cómo se prueba sin seam de `storageMode == .cloud`?** → **Tabla unitaria completa + un XCUITest NEGATIVO.**
Por qué: no existe seam de uitest para poner el device en `.cloud`, y el repo ya tiene ese precedente exacto
(`SessionExitsPerCellUITests`: «la E (nube completa) no tiene seam de `storageMode == .cloud` y la cubre la tabla
unitaria»). El XCUI que sí mide algo real es el negativo: con la racha terminal sembrada por el camino de producción
y sesión viva, un teléfono en `.icloud` —la población mayoritaria— NO ve el aviso. Un falso positivo ahí le diría a
todo el mundo que su teléfono no sincroniza.
Alternativa descartada: **añadir el seam de `.cloud`** — escribir ese modo cambia el montaje del store personal
(mirror off, store neutro) y arrastra el arranque entero; es un ticket propio, no una nota al pie de éste.

**D7 · ¿Device-QA o cierra en `done`?** → **Cierra en `done`, sin device-QA**, igual que el #176.
Por qué: el aviso es visual y determinista, y su decisión está cubierta por la tabla unitaria. Lo que device-QA
añadiría —ver el aviso con el motor realmente parado— exige un teléfono en modo nube con el attest roto más de un
día, que no se monta en ningún dispositivo de aquí.
