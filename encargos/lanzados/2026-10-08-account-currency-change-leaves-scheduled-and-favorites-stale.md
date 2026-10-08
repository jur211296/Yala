---
esfuerzo: high
---
# Al cambiar la divisa de una cuenta, Yala avisa antes de qué va a convertir y pasa pagos programados y favoritos a la tasa de hoy; el historial queda como está

## Contexto
Card del tablero `tablero-cambiar-la-divisa-de-una-cuenta-deja-mal-v5k7` (lista para lanzar, vence 2026-10-11). Tickets: `tickets/backlog/account-currency-change-leaves-scheduled-and-favorites-stale.md` (principal) y `tickets/backlog/saving-a-mismatched-transaction-relabels-it-without-converting.md` (los movimientos desemparejados que Guardar reetiqueta).

Lo que le pasa al usuario: cambia su cuenta de soles a dólares y acepta convertir el histórico; los movimientos pasados quedan bien, pero el alquiler programado por 3.500 nace cada mes como 3.500 dólares en vez de ~930, y los favoritos precargan el número viejo con la divisa nueva. Además, un movimiento de 50 USD dentro de una cuenta en soles, abierto y guardado sin tocar nada, sale como 50 PEN: se reetiqueta sin convertir.

**Decisión de Jürgen (2026-10-07), opción 2A, tal cual en los tickets:** «antes de cambiar la moneda de una cuenta, Yala avisa y muestra qué se va a convertir; los pagos programados y los favoritos se convierten a la tasa de hoy; el historial no se toca.»
**Confirmada por Jürgen el 2026-10-08 (04:00 Lima):** el historial se queda como está: Guardar sigue ofreciendo convertir cada movimiento a la tasa de su fecha (lo que ya hace `changing-an-account-currency-orphans-its-whole-history`, en `qa`). El aviso y la conversión solo suman pagos programados y favoritos. La «lectura por confirmar» que dejan escrita los dos tickets queda confirmada: no hace falta volver a preguntarla.

Según los tickets (son pistas, verifícalas en este árbol antes de tocar nada):
- `Yala/App/Services/ScheduledPaymentDraftService.swift` crea el borrador con `payment.amount` crudo y `account: payment.account`; al aprobarlo, `Yala/Services/DraftService.swift` estampa `currencyCode: account.currencyCode`.
- `Yala/App/Views/Transactions/NewTransactionView.swift` precarga `favorite.amount` y acto seguido pone `viewModel.currencyCode = account.currencyCode`.
- El veredicto del cambio de divisa (`AccountFormViewModel.currencyChangeVerdict`, `Yala/App/ViewModels/Accounts/AccountFormViewModel.swift`) solo mira `TransactionItem`: `ScheduledPayment`, `FavoritePayment` e `InboxDraft` pendientes no entran ni en el bloqueo ni en la conversión.
- `NewTransactionViewModel` guarda siempre con la divisa de la cuenta (al editar y al crear) y el importe viaja intacto; la vista ya sabe que el caso existe (comentario «This handles cases where transaction is in USD but account is in PEN») y carga la divisa y la tasa de la transacción al editar.

Lo que la decisión no nombra y hay que resolver sin cambiarla: los `InboxDraft` pendientes de esa cuenta (los lista el ticket principal) y qué pasa si hoy no hay tasa para el par.

Relacionados que NO entran aquí: `cloudsync-account-currency-orphans-receiver-history` (el receptor en otro teléfono; misma decisión, con AC de medir la ventana por orden de llegada), `account-currency-conversion-overlay-has-no-ceiling` y `currency-change-asks-rates-for-the-old-currency` (divisa preferida, no de cuenta).

Antes de esta sesión va en la cola `wire-decoder-accepts-non-finite-money`; no depende de ella.

Para orientarte: `CLAUDE.md`, `.claude/rules/currency-fx.md`, `.claude/rules/swiftdata-cloudkit.md`, `.claude/rules/l10n.md`, `.claude/rules/swiftui-ds.md`, `.claude/rules/testing.md`, los dos tickets y `tickets/qa/changing-an-account-currency-orphans-its-whole-history.md`.

Antes de tocar UI, mira `~/Claude/referencias-ui/README.md` (referencias de patrones de la flota: inspiración, no copiar pantallas ni marcas) y respeta `.claude/rules/swiftui-ds.md`.

## Que se pide
1. Reproducir los dos casos: cuenta en PEN con un pago programado de 3.500 y un favorito → cambiar a USD → el pago nace como 3.500 USD y el favorito precarga 3.500 USD; y un movimiento de 50 USD en una cuenta PEN → Guardar sin tocar → 50 PEN.
2. Aviso previo: al guardar el cambio de divisa, el aviso que ya existe muestra además qué se va a convertir (cuántos pagos programados y favoritos, con sus importes antes y después, o lo que quepa con claridad). Si no hay nada que convertir, el aviso no cambia. Textos nuevos en los 16 idiomas con `qa/scripts/add-l10n-key.sh`, en español neutro latinoamericano.
3. Al confirmar, convertir `ScheduledPayment` y `FavoritePayment` de esa cuenta a la tasa de hoy (divisa vieja → nueva), en el mismo guardado que el cambio de la cuenta, redondeando a los decimales de la divisa nueva (JPY sin decimales). Si hoy no hay tasa para el par, sigue lo que dice `.claude/rules/currency-fx.md` sobre el escalón del converter y dilo en el aviso; si eso obliga a una decisión de producto, aplica la regla día/noche.
4. El historial no cambia de comportamiento: Guardar sigue ofreciendo convertir cada movimiento pasado a la tasa de su fecha.
5. Guardar sobre un movimiento desemparejado (divisa distinta de la de su cuenta) sin cambiar nada conserva su importe y su divisa; no lo reetiqueta. Si la persona cambia el importe, se guarda en la divisa que la pantalla le está enseñando.
6. `InboxDraft` pendientes de esa cuenta: propón qué hacer (convertirlos con los programados, o que conserven su divisa y se traten como un movimiento al aprobarlos) y decide con la regla día/noche. Anótalo en el ticket.
7. Tests: un pago programado sobre la cuenta convertida nace con el importe convertido; un favorito precarga el importe convertido; el aviso enumera lo que se convierte; Guardar sin cambios sobre una fila desemparejada la deja igual. Controles rojos con el código viejo.
8. Si el cambio se ve en el simulador, deja `capturas/antes.png` y `capturas/despues.png` en el worktree, con rutas absolutas en el cierre. Si no se puede ver sin inventar datos, no hagas capturas y deja un guion de device-QA en `tickets/qa/`. Aquí lo que se ve es el aviso del cambio de divisa (antes sin programados ni favoritos, después con ellos).
9. Anota en los dos tickets la decisión 2A y la confirmación del 2026-10-08, y muévelos según las convenciones del repo. Deja `cloudsync-account-currency-orphans-receiver-history` en backlog con una línea de qué parte quedó hecha en el emisor.
10. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-cambiar-la-divisa-de-una-cuenta-deja-mal-v5k7` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- La conversión del histórico que ya hace `changing-an-account-currency-orphans-its-whole-history`: sigue igual.
- El applier de `accounts` en `Yala/Services/CloudSync/EntityApplyMap.swift` (el receptor, ticket aparte).
- El cambio de divisa PREFERIDA (`CurrencyChangeService`, `CurrencySettingsView`).
- Nada del servidor ni de Supabase.
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

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `wire-decoder-accepts-non-finite-money` sigue en CI (si el orden de lanzamiento cambió, el del encargo lanzado justo antes que este). Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Tras cambiar la divisa de una cuenta, pagos programados y favoritos quedan convertidos a la tasa de hoy y el aviso lo dijo antes; el historial se comporta como hoy.
- Guardar sin cambios sobre una fila desemparejada ya no la reetiqueta.
- Tests con controles rojos con el código viejo; paridad de l10n en verde con los textos nuevos en los 16 idiomas.
- Builds `Yala` y `Yala Dev` verdes; capturas antes y después del aviso, o guion de device-QA.
- PR a 2.1 en auto-merge, tickets con la decisión anotada, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones

> D1 la contestó Jürgen (2026-10-08, 10:45 Lima, AskUserQuestion). El resto, resueltas por Frank con la recomendación; se discuten en el PR.

**D1 · Borradores pendientes de la Bandeja de esa cuenta** → se convierten junto al historial, cada uno con el tipo de cambio de **su** fecha (`date ?? createdAt`), y el aviso los cuenta. Los de grupos no se tocan.
Por qué: un borrador no guarda divisa (la toma de la cuenta), así que sin convertirlo se aprobaría con el número viejo en la divisa nueva; es un movimiento por aprobar y lo coherente es tratarlo como historial. Alternativas descartadas: tasa de hoy (una compra de Apple Pay de la semana pasada con la tasa de hoy) y «conservar su divisa» (exige un campo nuevo en el borrador: despliegue de esquema en CloudKit y en el backend).

**D2 · Hoy no hay tasa para el par** → no se convierte nada —ni historial, ni programados, ni favoritos, ni borradores— y se dice con el aviso «No se pudo convertir» que ya existe. Si en el momento del aviso la tasa de hoy aún no es la exacta, el importe «después» sale con «≈» (el glifo que ya usa la app; `currency-fx.md` prohíbe un rótulo paralelo), y la conversión real espera a traer la de hoy.
Por qué: es lo que Jürgen ya decidió el 2026-09-09 para el historial (`prepareRates` exige la fila de hoy y todo-o-nada); el importe de un pago programado tampoco tiene reparador, y sellarlo con la tabla estática es la forma del bug de `currency-fx.md`. Alternativa descartada: arrastrar la tasa de días anteriores para programados (partiría el guardado en dos criterios).

**D3 · Qué pagos programados** → los de la cuenta **sin** `groupZoneID`. Se convierten desde su `currencyCode` (no desde la divisa vieja de la cuenta) y pasan a la divisa nueva; los de importe variable también (es una estimación igual). Los de grupo no se tocan: su importe es en la divisa del grupo y lo manda el grupo.

**D4 · Qué favoritos** → los de la cuenta. Con importe: se convierte desde `currencyCode ?? divisa vieja de la cuenta`. Sin importe: solo pasan a la divisa nueva.

**D5 · Redondeo** → a los decimales ISO de la divisa nueva (`NumberFormatter` con `currencyCode`: JPY 0, USD 2), con redondeo `.plain`. Solo en programados y favoritos (son números que la persona teclea y ve); el historial sigue como hoy.

**D6 · Cuándo sale el aviso** → siempre que haya algo que convertir (movimientos, borradores, programados o favoritos), también en una cuenta sin movimientos que hoy cambiaba sin preguntar. Sin nada que convertir, no sale, como hoy. El bloqueo por transferencias/grupos no cambia y los programados no bloquean.

**D7 · Qué enseña el aviso** → el texto de siempre si hay movimientos; una línea con los borradores; y «pagos programados y favoritos a la tasa de hoy» con hasta 3 importes `antes → después` y «y N más». Sin movimientos, título propio («¿Cambiar la divisa a USD?»).

**D8 · Guardar una fila desemparejada** → el formulario lleva una «divisa del importe» (`amountCurrencyCode`): al editar sin cambiar de cuenta es la de la transacción; si cambias de cuenta o creas, la de la cuenta (como hoy). El importe se pinta, se guarda y se convierte a la preferida en esa divisa. Los atajos «guardar como favorito/programado» siguen con la divisa de la cuenta (no se toca lo adyacente).

**D9 · Capturas** → no se hacen: el selector de divisa del formulario de cuenta no responde a taps sintéticos (medido cinco veces en `changing-an-account-currency-orphans-its-whole-history`) y montar el aviso exigiría un seam que invente el cambio. Queda guion de device-QA en `tickets/qa/`.
