# Separar copy de cierre: «aún se asienta» vs «falló la subida» (sin red / 5xx)

## Contexto
Ticket: `tickets/backlog/signout-pending-copy-says-wait-seconds-when-offline.md`.
Decisión Jürgen (2026-09-15): **separar las dos causas** — un motivo/texto para «aún se asienta» y otro para «falló la subida» (sin red / 5xx / cortafuegos). No unificar todo con el texto de nube, y no dejarlo como está.

Hoy `BlockReason.transient` mezcla asentamiento real y fallo de red; sin conexión el aviso dice «espera unos segundos» y «Guardando…» aunque no se guarda nada. La nube ya tiene texto cierto para upload fallido (`.uploadRetryLater`).

Justo mergeados: #176 (aviso Grupos Attest) y #177 (aviso personal Attest). No reabrirlos salvo reutilizar patrones de copy.

## NOCHE (Lima, después de 21:00)
Elige lo recomendado sin AskUserQuestion. Si la decisión es demasiado importante para asumirla, aparca el ticket (ticket propio / no inventar) y avisa a Frank.

## Que se pide
1. Separar las causas en el copy de bloqueo de cierre / desasociar / puerta Welcome según la decisión.
2. Textos honestos: asentamiento vs fallo de subida; no culpar a la red cuando el problema es Attest (ese caso ya tiene tickets hermanos).
3. Cubrir superficies citadas en el ticket (SignOutBlockedCopy, WelcomeGroupsGate, detach, etc.) sin inventar alcance.
4. Gate, commit, `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1 si el gate pasa, `/cerrar-total`. Bugs nuevos → ticket antes de cerrar. No sync Kanban/store.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, board del repo, merge y `/cerrar-total` sin preguntar por gate/commit. Solo parar ante decisión/acceso real (de noche: aparca). UI tests CI advisory.

## Que NO hay que tocar
marketing/; no reopen #176/#177 salvo copy/pattern.

## Como se sabe que esta bien
Sin red: el aviso no dice «espera unos segundos / guardando» como si hubiera progreso. Asentamiento real: texto de «un momento más». Board al día + `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando:
  (1) decisión de producto/acceso;
  (2) PR abierto o preview listo;
  (3) vas a `/cerrar-total` — resumen corto en lenguaje de usuario;
  (4) tramo sin siguiente paso claro — una vez.
NO: test rojo a reclasificar, build a reintentar, CI advisory.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-16)

El árbol completo, con lo medido y las tablas de superficies, vive en el ticket:
`tickets/in-progress/signout-pending-copy-says-wait-seconds-when-offline.md`, sección `## Paso 0`. Resumen:

- **La premisa del ticket se queda corta, y eso abarata el arreglo.** Dice que `CadenceOutcome` no separa las
  dos causas; medido, sí las separa y es `classify` quien tira la distinción en una línea. Un ciclo que FALLÓ
  es una subida que no llegó; un ciclo que fue BIEN con filas vivas es el tope de iteraciones, o sea
  asentamiento. Y los otros dos productores de `.transient` —el timeout de quiescencia y la cancelación— ya
  son asentamiento puro y ni pasan por ahí.
- **D1 · Se reusa `.uploadRetryLater`**, no se crea un motivo nuevo: su texto ya dice lo que hay que decir,
  está en los 16 locales y ya tiene rama en dos de las cuatro superficies. Cero keys nuevas.
- **D2 · La separación nace en `classify`**: `.transient` del ciclo → `.uploadRetryLater`;
  `.completed`/`.coalesced` → `.transient`.
- **D3 · Sin testigo nuevo en el canal de sync** (el molde de `stoppedByChannelKill`). Dentro de
  `CadenceOutcome.transient` quedan fallos LOCALES además del transporte, pero son patológicos y el texto de
  `.uploadRetryLater` no miente en ellos. No se pagan 3.400 líneas del canal por eso.
- **D4 · Los 45 s de reintentos se van para el fallo de subida, y es la mitad del arreglo.** `decide` ya manda
  `.uploadRetryLater` al aviso inmediato. Misma decisión que Jürgen tomó dos veces (13-sep `.channelPaused`,
  14-sep `.uploadRetryLater` en la nube) con el mismo razonamiento. Es lo único que quita el «Guardando tus
  cambios pendientes…» de los 45 s sin red, que es el criterio de aceptación. Lo que se asienta sigue
  reintentando.
- **D5 · El cierre en la nube invierte su mapeo**: el asentamiento vuelve a `.transient`.
- **D6/D7/D8 · No se toca el texto de `.transient`, ni se añaden keys, ni se toca el caption de progreso.**
- **D9 · El camino PERSONAL queda fuera**: colapsa a `.permanent` y tiene ticket propio. Se comprueba que
  este cambio no lo altera.

**Lo que hay que tocar, contado:** `classify` y `cloudSignOutGroupsBlockReason` (una línea cada uno, más
docblocks), la rama nueva de la puerta del Welcome —donde hoy `.uploadRetryLater` caería en un catch-all que
dice «vuelve a entrar con esa cuenta», que es falso— y la separación del desasociar. Ajustes y la hoja del
cambio de Apple ID no se tocan: ya están enrutadas.
