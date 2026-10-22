# Carril adaptativo, paso 2 de 13: que las pantallas principales del iPhone aguanten el texto muy grande

## Contexto
Yala tiene dos carriles en paralelo por orden de Jürgen: Cola A (sync, otra sesión trabajando ahora mismo en `wipe-division-exclusion-trusts-the-origin-to-converge`) y el carril adaptativo iPad/iPhone Duo, fase a fase y en serie. El plan está en `docs/exploracion/adaptativo-ipad-duo.md` (PR #285); la fase 0 (PR #286) ya está en 2.1. Este es el siguiente paso: `tickets/backlog/iphone-large-text-sizes-break-layouts.md`. Léelo entero: trae la medición (41 topes en `accessibility1`, 0 `ViewThatFits` / `AnyLayout`), los pasos y las reglas del carril. Jürgen no quiere ser cuello de botella en esto: decide tú los detalles con la práctica nativa que recomienda Apple (Dynamic Type, `isAccessibilitySize`, `AnyLayout`/`ViewThatFits`), sin preguntarle.

## Que se pide
Lo que dice el ticket en «Qué hacer»: medir primero con capturas a tamaño por defecto y AX5 en las diez pantallas y los dos iPhone; arreglar lo que corte un importe o tape un botón; revisar los 41 topes uno por uno (se quedan solo los que tengan motivo escrito al lado); lo caro o lo que toque navegación, a ticket aparte.

## Que NO hay que tocar
- A tamaño de texto por defecto, cero cambios visibles en el iPhone.
- Nada de sync, datos ni lógica de Cola A.
- Simuladores: SOLO los `YalaLane-Adapt-*`, siempre por UDID (`-destination id=<UDID>`); receta en el plan §6.2. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar cualquier simulador sin ese prefijo (los usa Cola A). DerivedData propio del worktree (`-derivedDataPath .ddp`).
- Navegación, sidebar y list-detail son fase 1: no aquí.

## Como se sabe que esta bien
El «Hecho cuando» del ticket: capturas antes/después en `qa/evidencia-adaptativo-AAAAMMDD/iphone-large-text-sizes-break-layouts/`, sin diferencias a tamaño por defecto, ningún importe cortado ni botón tapado a AX5, XCUITest de las áreas tocadas en verde en `YalaLane-Adapt-iPhone-ProMax` por UDID, gate verde. PR contra 2.1 mergeado, ticket a qa o done, `docs/TICKETS.md` al día, tickets nuevos para lo que salga.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. Es horario diurno: puedes usar AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR o dejaste preview/artifact listo; (3) terminaste el ticket y vas a /cerrar-total, con un resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo y no tienes siguiente paso claro, una vez y no en bucle. NO avises por un test rojo que vas a reclasificar, un build que vas a reintentar ni ruido de CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Runtime de los simuladores del carril** → iOS 27.0. `YalaLane-Adapt-iPhone-SE` (AF88C006) y
`YalaLane-Adapt-iPhone-ProMax` (A918242C) se crean aquí, en la Mini, con el único runtime instalado.
Por qué: la receta del §6.2 pide 26.5 y esta Mac no lo tiene (medido: `simctl list runtimes` → solo 27.0).
Alternativa descartada: descargar 26.5 — varios GB para nada; el deployment target es 26.0 y 27.0 lo cumple.

**D2 · Cómo se sacan las capturas** → un XCUITest temporal (`ZZLargeTextCaptureUITests`) con `seed grupos` +
Pro que recorre las diez pantallas y guarda PNG en el host; el tamaño de texto se pone con
`simctl ui <UDID> content_size`. El test se borra antes del commit.
Por qué: reproducible, las mismas cifras en cada pasada (semilla determinista), y el antes/después sale del
mismo guion. Alternativa descartada: tocar a mano con XcodeBuildMCP — 160 capturas no se hacen a mano igual dos veces.

**D3 · Qué hacer con los topes que no hacen nada** → fuera. Medido: **33** de los 41 van sobre una `Image`, un
`TextField` o un `HStack` cuyas fuentes son todas `.font(.system(size: X))` con `X` un `@ScaledMetric`. El
`@ScaledMetric` se resuelve con el entorno de FUERA del `body`, así que un `.dynamicTypeSize(...)` dentro del
`body` no le llega, y una fuente de tamaño fijo no mira el entorno. Quitarlos no cambia ni un píxel a ningún tamaño.
Alternativa descartada: dejarlos «con motivo» — el motivo sería falso, el tope no actúa. (La primera cuenta, 29,
estaba mal: se corrigió al recorrerlos uno a uno.)

**D4 · Los 8 topes que sí actúan** → uno a uno, con la captura de AX5 delante:
- Fuera: Siri y Atajos (pantalla entera) y el recuento de la aprobación en lote. Se ven bien sin tope.
- Sustituidos: los importes grandes del detalle de presupuesto y de pago planificado. En vez de topar el texto en
  AX1 crecen con el sistema y, si un importe no cabe, se encogen (`lineLimit(1)` + `minimumScaleFactor(0.5)`).
- Se quedan con motivo escrito al lado: el widget pequeño de pagos del Panel (tarjeta de alto fijo, 192 pt,
  medido), el tutorial (páginas de un `TabView` sin scroll), el icono de `YalaEmptyState` en estilo `.widget`
  (decorativo, en las mismas tarjetas pequeñas) y la fila del tipo de cambio de la transferencia. Ésta se quitó y
  volvió: sin tope, a AX5 en el SE el tipo de cambio se cortaba («1 U… 3.6600 PEN»). Ahora el tope cubre solo esa
  fila, no el bloque entero.

**D5 · Patrón para una fila concepto + importe que no cabe** → `AnyLayout(HStack)` → `AnyLayout(VStack)` cuando
`dynamicTypeSize.isAccessibilitySize`, alineado a `.leading`. Es lo que recomienda Apple para tamaños de
accesibilidad y a tamaño por defecto deja la fila idéntica.
Alternativa descartada: `ViewThatFits` — mide dos veces dentro de listas largas y cambia de forma según el
contenido de cada fila, así que dos filas vecinas podrían salir distintas.

**D6 · Formato de la evidencia** → JPG a 500 px de ancho en `qa/evidencia-adaptativo-20260928/iphone-large-text-sizes-break-layouts/`,
como las carpetas de evidencia anteriores (JPG, 1–10 MB por carpeta). Por qué: 160 PNG a resolución nativa
pesarían cientos de MB en git.

**D7 · Estado final del ticket** → `done` si los cuatro «Hecho cuando» se cumplen en simulador. Por qué: es
maquetación; el simulador pinta Dynamic Type igual que el iPhone y no hay nada que solo se vea en dispositivo.
Si queda algo que no se pueda medir aquí, `qa` con su guion.

**D9 · Alcance del arreglo de filas** → las diez pantallas del ticket, más los componentes que ellas usan
(Registros, «Últimos registros» del Panel, cabeceras de ingresos/gastos de Panel y Registros, presupuestos, grupos
y su detalle, Bandeja, filas etiqueta–valor del detalle de registro y de presupuesto). Las otras copias del mismo
patrón fuera de esas pantallas (pantallas de éxito, detalle de gasto de grupo, Estadísticas) van a un ticket
aparte con su lista. Por qué: cada cambio visible pide su captura antes/después, y esas pantallas no están en el
guion de este ticket.

**D10 · Mis corridas de simulador van por la cola (`sim-lock.sh`)** aunque usen los simuladores del carril.
Por qué: el centinela `sim-libre.sh` de Cola A cuenta cualquier runner de XCUITest de la máquina, sin mirar el
simulador; una corrida mía fuera de la cola le invalidaría el veredicto. Las dos primeras pasadas de capturas
corrieron sin cola, con Cola A sin tests en marcha (medido con `ps`).

**D8 · Destino del gate** → `-destination id=A918242C…` (ProMax del carril) y `-derivedDataPath .ddp`.
Por qué: lo manda el carril; el `name=iPhone 17 Pro` del gate no resuelve en esta Mac.
