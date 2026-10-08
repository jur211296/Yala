---
esfuerzo: high
---
# Un importe NaN o infinito que llegue de la nube ya no entra en el teléfono: el decoder del wire rechaza lo no finito con el mismo criterio que el emisor

## Contexto
Card del tablero `tablero-un-importe-nan-que-llegue-de-la-nube-se-j2gn` (lista para lanzar, vence 2026-10-10). Ticket: `tickets/backlog/wire-decoder-accepts-non-finite-money.md` (sale de la review adversarial de `repair-queue-has-no-exit-for-partial-rate-rows`, 2026-09-08). El triage de Frank del 2026-10-07 lo confirmó vivo en el código de 2.1.

Lo que le pasa al usuario: si por el canal de la nube llega un importe `NaN` (o infinito), se guarda en el teléfono, no sale nunca y descuadra cualquier total que lo sume.

Según el ticket (son pistas, verifícalas en este árbol antes de tocar nada):
- `WireValueDecoder.double` (`Yala/Services/CloudSync/WireValueDecoder.swift`) convierte el valor del wire sin comprobar que sea finito: `Double("nan")` devuelve `NaN`, y entra por `Apply.moneyReq(\.amount)` (`EntityApplyMap.swift`) directo a `TransactionItem.amount`.
- En la otra dirección, `Canonc1Codec` rechaza los no finitos al EMITIR, con canario. Así que un `NaN` que entra ya no puede salir: se queda en el dispositivo.
- Un `amount` no finito rompe todo guard de igualdad sobre las columnas derivadas (`NaN != NaN` es `true`). `TransactionItem.recalculatePreferredCurrency` volvería a escribir esa fila en cada arranque: justo el bucle que `repair-queue-has-no-exit-for-partial-rate-rows` cerró para el resto.
- No es una regresión del guard de igualdad: el agujero del decoder es anterior.

Antes de esta sesión va en la cola `notification-dedup-deletes-all-custom-reminders-but-one`; no depende de ella.

Para orientarte: `CLAUDE.md`, `.claude/rules/swiftdata-cloudkit.md`, `.claude/rules/currency-fx.md`, `.claude/rules/testing.md` y el ticket.

## Que se pide
1. Reproducir con test: `"nan"`, `"inf"`, `"-inf"` (y sus variantes de mayúsculas o `"Infinity"`, y un número que desborde como `1e400`) entrando por el wire hasta `TransactionItem.amount`.
2. Arreglar con la opción más robusta: `WireValueDecoder.double` rechaza o pone en cuarentena los valores no finitos con el mismo criterio que `Canonc1Codec` usa al emitir, de modo que las dos direcciones coincidan. Elige entre rechazar y cuarentena mirando qué hace hoy el apply con un valor de dinero obligatorio malformado: no puede descartar la fila en silencio ni atascar el drenado para siempre. Sigue el patrón que ya existe para valores malformados (canario, breadcrumb).
3. Revisa las demás columnas de dinero y tasas que pasan por el mismo decoder (presupuestos, pagos programados, grupos, tasas de cambio) y cúbrelas igual.
4. Producción: comprueba si ya hay filas así antes de decidir si hace falta una cura. Solo lectura; si no tienes acceso de lectura, déjalo pedido en el ticket. Si hace falta cura en los teléfonos, déjala propuesta (A/B/C con recomendación) en el ticket: no reescribas importes de la persona en esta sesión.
5. Test en las dos direcciones con un control que salga rojo con el código viejo.
6. Anota lo medido en el ticket y muévelo según las convenciones del repo.
7. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-un-importe-nan-que-llegue-de-la-nube-se-j2gn` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- El criterio de `Canonc1Codec` al emitir: se reutiliza, no se cambia.
- Las migraciones de `qa/cloud/`, los `.ddl` ni nada del servidor. Nada de escribir en Supabase.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion. Lo que toque datos de la persona (borrar o reescribir importes sin respuesta suya) es de alto riesgo: no se hace sin decisión.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~32 GB libres el 2026-10-08, justo en el umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `notification-dedup-deletes-all-custom-reminders-but-one` sigue en CI (si el orden de lanzamiento cambió, el del encargo lanzado justo antes que este). Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Un `NaN` o infinito en el wire no llega a ninguna columna de dinero del teléfono, con el mismo criterio que al emitir.
- Tests en las dos direcciones con `nan`, `inf` y `-inf`, y control rojo con el código viejo.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, ticket con lo medido en producción (o lo que falta para medirlo) y la cura propuesta si hace falta, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Decisiones resueltas antes de tocar código (sesión autónoma, 2026-10-08 de día, Lima):

1. **Qué llega por el wire, medido.** `Double(String)` acepta `nan`/`NaN`/`inf`/`-inf`/`Infinity` en cualquier caja y
   convierte `1e400` en `inf`. Un número JSON no finito no llega nunca: `JSONDecoder` rechaza `1e400` y `NaN` sin
   comillas. ⇒ el agujero es solo la rama `.string`. Postgres sirve `NaN` de un `NUMERIC(18,4)` como el string `"NaN"`,
   y el gateway no valida valores al subir (`validateUpsertShape` mira la forma, no el número).
2. **Rechazar en el decoder, siempre**: `WireValueDecoder.double` devuelve `nil` para un no finito, con el criterio de
   `Canonc1Codec.decimalFixed` (`isFinite`). El rango (10¹⁴ / 10¹⁰) no se copia: las columnas del servidor son
   `NUMERIC(18,4)`/`(18,8)` y no pueden excederlo; un test ata las dos direcciones.
3. **Qué hace la fila (canal personal): cuarentena del delta entero**, no aplicar la columna a medias. Hoy un dinero
   obligatorio malformado se deja sin tocar en silencio: el born-remote nace con 0 USD y una fila existente mezcla el
   grupo `money`. La invariante D-5 del apply dice «o se aplica o va a `SyncQuarantine`»; la cuarentena avanza el
   cursor (no atasca), guarda el delta (no descarta) y el Merkle ya salta la tabla. Se retira sola cuando llega una
   versión posterior de esa fila. El drenaje del arranque no la vuelve a aplicar mientras siga no finita.
4. **Grupos: saltar el delta con rastro**, que es su patrón (`groupsApplySkippedDelta`): no tiene cuarentena. Gasto,
   reparto y liquidación no se aplican; en la meta del grupo solo se deja sin tocar `budget_limit_amount`.
5. **Canario y rastro**: `cloudSyncPullNonFiniteMoney` (detalle = tabla y canal, sin valores) y breadcrumbs.
6. **`WireValueDecoder.int` también**: `Int(Double)` con `nan`/`inf` o fuera de rango CRASHEA. Misma familia, mismo
   decoder: entra en el arreglo.
7. **`confidence_*`** (TEXT, `doubleTextOpt`): con el decoder nuevo un no finito queda `nil`. No es dinero ni cuarentena.
8. **Producción**: sin lectura. El PAT de gestión (`~/Secrets/yala-supabase-mgmt/pat`) da «Invalid access token» y
   estaba autorizado solo para staging; el conector de Supabase pide autenticación. ⇒ queda pedido en el ticket, con la
   consulta lista. Ninguna cura de importes en esta sesión.
9. **Device-QA**: no hay UI ni comportamiento visible que probar en un iPhone ⇒ ticket a `done`, card a «done» (frank).
