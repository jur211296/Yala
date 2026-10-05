# Cerrar sesión en la nube con una subida que nunca termina: un texto que no prometa segundos y una salida en teléfonos sin App Attest

## Contexto
Ticket: `tickets/backlog/personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy.md` (léelo entero, incluida la nota del 2026-09-28 sobre la sesión caducada).
Si el drain del outbox aborta en TODAS las vueltas (un `save` que falla siempre, un reloj por unidad, un testigo ilegible), cerrar sesión en la nube responde «Un momento más… espera unos segundos» para siempre, y en un teléfono sin App Attest desaparece la salida de cerrar perdiendo esos cambios. Con la sesión caducada pasa igual: sale «un momento más» en vez de «vuelve a entrar».

Decisión de Jürgen (2026-10-04, tarjeta del tablero «Decidir: una subida que siempre aborta…»): **A. Texto que no prometa segundos, y una salida en teléfonos sin App Attest.** En Yala quiere siempre lo más robusto y la mejor práctica, aunque tarde más; sin apuro.

La sesión anterior (PR #357, borrado de iCloud pendiente al pasar a la nube) está en cola de merge a 2.1 con el CI corriendo. No depende de esta, pero tocó el hook de cierre de sesión de `CloudSyncFlags`.

## Qué se pide
- Un testigo del ciclo «el drain no terminó» (como sugiere el ticket: bajado al entrar en cada ciclo y leído con el outcome, igual que los otros testigos), y con él un motivo propio y un texto propio que no prometa segundos, en los 16 locales.
- Una salida para el teléfono sin App Attest en ese estado: que pueda cerrar sesión sabiendo con claridad qué se pierde (contado, no a ciegas). Diseña la salida más segura y honesta.
- El caso de la sesión caducada con drain que aborta siempre: que recupere su puerta de «Iniciar sesión» y la salida de perder lo contado.
- Mira si el gemelo de Grupos tiene el mismo hueco; si es el mismo arreglo, hazlo; si es otro trabajo, déjalo como ticket.
- Son las 00:15 en Lima: si aparece una decisión de copy o de UX reversible, elige tú la opción recomendada y sigue; deja anotado qué elegiste y por qué. Si algo es de riesgo alto (pérdida de datos), para y pregunta.

## Qué NO hay que tocar
- No cambies la política de que lo que el aviso no enseña no se pierde en silencio.
- No toques el borrado de iCloud pendiente de PR #357 ni rehagas lo que ese PR cambió.
- Nada de marketing/.

## Cómo se sabe que está bien
- Los criterios del ticket: con un drain que aborta en todas las vueltas, el aviso no dice «espera unos segundos»; el caso pasajero (algo escrito tras el drain) sigue curándose solo con otra vuelta.
- El teléfono sin App Attest y la sesión caducada tienen salida en ese estado, con tests unitarios que lo fijen y XCUITest de lo visible si hay seam.
- Gate verde (build `Yala` y `Yala Dev`, unit completa, XCUITest de las áreas tocadas), review adversarial y PR a 2.1 en auto-merge.
- Si el cambio se ve, capturas `antes.png` y `despues.png` en `~/Claude/worktrees/_capturas/<slug>/`, con las rutas en el resumen.
- Ticket a `tickets/qa/` con guion de device-QA si hace falta un iPhone real; la tarjeta del tablero a «in qa» con nota de lo entregado.

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. No esperes a que PR #357 entre ni partas de su rama. Justo antes del gate, mira si #357 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez. El simulador puede usarse antes solo para capturas, y se apaga antes del rebase.

## Pipeline en la Mini (serial, 1 simulador)
Limpiar → build con `xcodebuild -jobs 2` sin simulador booteado → bootear 1 simulador → tests → apagar y borrar ese simulador. No solapar compilación, SpringBoard, app y UITests.

## DerivedData y cachés
Al lanzar y al cerrar, borra tú sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen o cuyo PR ya se mergeó. No toques DerivedData ni cachés de un worktree que sigue vivo. Si el borrado falla, dilo en el cierre.

## Cierre
Esta tarea puede cerrar sola. Al terminar, con el PR en auto-merge, corre `/cerrar-total`: apaga y borra el simulador que usaste, limpia DerivedData y cachés como arriba, y deja la Mini limpia. Si creaste alguna clave en el Llavero, dilo en el resumen.

/cerrar-total

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 00:30 Lima): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué es «el drain no terminó»?** → Un testigo por ciclo en `CloudSyncRuntime` (`lastCycleCaptureUnfinished`), bajado al entrar en `performCycle` y encendido si el drain del paso 1 devuelve `false` **o** si terminó con la traducción cortada (nuevo `CloudSyncEngine.lastDrainCutTranslation`). Se lee con el outcome (`stoppedWithUnfinishedCapture(for:)`, fuera con `.coalesced`).
Por qué: la traducción cortada devuelve `true` a propósito y es el otro camino del ticket que deja ediciones solo en el History para siempre. Alternativa descartada: cambiar el `Bool` de `drainOnce`, que leen la migración y el pull con otro contrato.

**D2 · Motivo y texto propios.** → `BlockReason.personalCaptureUnfinished`, título genérico «No pudimos cerrar tu sesión», mensaje: no se pudieron preparar para subir, siguen en el teléfono y no se pierden, cierra y abre Yala, y si sigue, actualízala. Sin salida de pérdida en un teléfono normal.
Por qué: es lo que de verdad puede curarlo (estado en memoria, o un arreglo del drain), y no promete segundos. Alternativa descartada: reutilizar `.personalUploadRetryLater` («no llegaron a la nube»), que culpa a la subida y no a este teléfono.

**D3 · ¿Cuándo sale?** → Solo con el testigo encendido en el ÚLTIMO ciclo y la sonda del History diciendo «sí» (o «no se sabe»). Se relee `.drained` y, nuevo, `.blocked(.transient)`; el resto pasa igual. El bucle sigue dando vueltas hasta el tope, como hoy.
Por qué: el caso pasajero (algo escrito tras un drain que sí terminó) sigue en «un momento más» y se cura con otra vuelta; un drain que aborta de forma intermitente también tiene sus vueltas.

**D4 · Teléfono sin App Attest y sesión caducada con el drain atascado.** → Conservan su motivo (`.attestUnavailable` / `.sessionExpired`) en vez de caer a `.transient`, también cuando el outbox está vacío (el `.drained` se relee con el motivo del ciclo). Así vuelven la puerta de «Iniciar sesión» y la salida de pérdida.
Por qué: es la decisión A de Jürgen (2026-10-04).

**D5 · «Contado, no a ciegas»: qué se cuenta y qué se acepta.** → El aviso cuenta filas vivas del outbox + cambios del History sin capturar (una clave por cambio: store, transacción, cambio). Lo aceptado guarda las dos mitades; retomar solo sigue si lo de ahora está dentro de lo aceptado en cada mitad. Una edición posterior es una transacción nueva y hace volver el aviso. Un recuento que falla = aviso sin cifra, como hoy.
Por qué: mantiene «lo que el aviso no enseña no se pierde en silencio». La sonda puede contar de más en la frontera del respaldo del token (ya consumido): es la dirección segura. Alternativa descartada: contar solo el outbox (perdería ediciones que no se enseñaron).

**D6 · Gemelo de Grupos.** → Su texto ya no promete segundos (`groupsCaptureVerdict` da `.uploadRetryLater`), pero el teléfono sin attest y la sesión caducada pierden su salida igual (`lossBlockAfterRecapture`). Arreglarlo pide contar el History de grupos en tres cierres, «Empezar de cero» y la puerta del Welcome: otro trabajo → ticket nuevo.

**D7 · XCUITest.** → Si no hay seam que lleve el cierre en la nube a un bloqueo sin backend, lo visible se fija con tests unitarios del copy (`SignOutBlockedCopy`) y el ticket va a `qa` con guion de device-QA.
