---
esfuerzo: medium
---
# El tipo de cambio se lee en cualquier divisa (nada de «0,0000» con el dong) y el widget de tasas escribe con el separador del idioma

## Contexto
Card del tablero `tablero-el-tipo-de-cambio-sale-0-0000-en-divisas-8amy` (lista para lanzar, vence 2026-10-10). Tickets: `tickets/backlog/exchange-rate-detail-shows-zero-for-low-denomination-currencies.md` (principal) y `tickets/backlog/widget-de-tc-no-localiza-separadores.md`. El triage de Frank del 2026-10-07 los confirmó vivos en el código de 2.1.

Lo que ve el usuario: registra un gasto de 500.000 dongs con la moneda preferida en dólares y el detalle de la transacción dice que el tipo de cambio es «0,0000». Y el widget «Tipos de cambio» del Panel escribe «1 USD = 3.8000 PEN» con punto a quien lee «3,8», mientras la hoja de ganancia cambiaria de la misma pantalla escribe «3,8».

Según los tickets y un grep de hoy sobre `origin/2.1` (verifícalo antes de tocar nada), el formato fijo `String(format: "%.4f"…)` sobre tasas aparece en:
- `Yala/App/Views/Records/TransactionDetailSheet.swift` (~L532), el detalle de la transacción.
- `Yala/App/Views/Panel/ExchangeRateWidget.swift` (~L390 y ~L496), el widget del Panel.
- `Yala/App/Views/Settings/CurrencySettingsView.swift` (~L286) y `Yala/App/Views/Settings/ExchangeRatesSheet.swift` (~L101).
- `Yala/App/Views/Transactions/Components/TransferAmountInputView.swift` (~L152, ~L204, ~L212): ahí la tasa es un texto editable que luego se parsea; cambiar su formato puede romper la entrada.

La tasa se guarda como «preferida por unidad de divisa nativa»: VND→USD 0,0000408 sale «0,0000»; IDR→USD 0,0000633 sale «0,0001»; KRW→USD 0,00074 sale «0,0007». El ticket propone decimales significativos en vez de cuatro fijos, o invertir la presentación («1 USD = 24.500 VND»), comprobando que no se rompe el caso normal (PEN→USD).

CADENA tras cerrar `panel-recalculates-on-new-rates` (PR #419 en cola de auto-merge a 2.1; card t72p en in qa → jurgen). No depende de ella: trabaja sin esperarla; si toca el mismo `ExchangeRateWidget`/`PanelViewModel`, lo resuelves en el rebase final. Las cards high que quedan necesitan backend/deploy o están en manos de Jürgen; esta es la mejor medium sin decisión pendiente, sin deploy, sin secretos y sin gasto de API. Para no abrir una decisión de UI: por defecto usa decimales significativos con el formateador localizado, sin invertir la presentación; si con las capturas delante la inversión se lee claramente mejor en algún par, déjala propuesta en el ticket (A/B con recomendación) en vez de aplicarla.

Para orientarte: `CLAUDE.md`, `.claude/rules/currency-fx.md`, `.claude/rules/l10n.md`, `.claude/rules/swiftui-ds.md`, `.claude/rules/testing.md` y los dos tickets.

Antes de tocar UI, mira `~/Claude/referencias-ui/README.md` (referencias de patrones de la flota: inspiración, no copiar pantallas ni marcas) y respeta `.claude/rules/swiftui-ds.md`.

## Que se pide
1. Reproducir con test: VND→USD, IDR→USD y KRW→USD con el formato de hoy, y el widget en un locale con coma decimal.
2. Un solo formateador de tasas localizado (`NumberFormatter` o el formateador que ya use la app), legible para cualquier par de la tabla de divisas: decimales significativos, o la presentación invertida donde se lea mejor. Elige con capturas delante y sin romper PEN→USD; si la elección es dudosa, aplica la regla día/noche.
3. Usarlo en el detalle de la transacción, en el widget del Panel y en las dos pantallas de Ajustes. En `TransferAmountInputView` solo si un test fija que la entrada se sigue parseando bien en es y en en; si no, anótalo en el ticket y déjalo.
4. Tests: VND, IDR, KRW, JPY, KWD y PEN contra USD, en es y en en, con un control rojo con el código viejo.
5. Si el cambio se ve en el simulador, deja `capturas/antes.png` y `capturas/despues.png` en el worktree, con rutas absolutas en el cierre. Si no se puede ver sin inventar datos, no hagas capturas y deja un guion de device-QA en `tickets/qa/`. Aquí: el detalle de un gasto en dongs y el widget en español, antes y después.
6. Anota lo hecho en los dos tickets y muévelos según las convenciones del repo.
7. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-el-tipo-de-cambio-sale-0-0000-en-divisas-8amy` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.
8. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --fecha <AAAA-MM-DD> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre.

## Que NO hay que tocar
- El valor y la dirección con que se guarda `exchangeRate`: solo cambia cómo se muestra.
- El monto convertido de al lado, que ya sale bien.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~28 GB libres el 2026-10-09, por debajo del umbral de 32: limpia primero y, si baja de ~20 GB, para, limpia y sigue).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Rebase al final, sin esperar a nadie: la sesión arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR. Justo antes de abrir su PR, hace `git fetch` y rebasa sobre `origin/2.1`, y resuelve ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados sobre el árbol rebasado, con un solo simulador.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- El tipo de cambio se lee para cualquier par de la app, incluidas las divisas de denominación baja, y PEN→USD sigue leyéndose bien.
- El widget escribe «3,8» en español y «3.8» en inglés, igual que la hoja de ganancia cambiaria.
- Tests con control rojo con el código viejo; builds `Yala` y `Yala Dev` verdes; capturas antes y después.
- PR a 2.1 en auto-merge, tickets movidos, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Forma de presentar la tasa** → decimales significativos, sin invertir. Tasa ≥ 1: de 2 a 4 decimales (como la hoja de ganancia cambiaria). Tasa < 1: los decimales que den 4 cifras significativas (VND→USD «0,00004082»; PEN→USD «0,2667», igual que hoy). Invertir lo deja como propuesta en el ticket si las capturas lo piden; no se aplica.
2. **Locale** → el mismo que los importes (`NumberFormatter` con `Locale.current`, como `CurrencyFormattingHelper` y la hoja de ganancia cambiaria). Usar `AppLocale` podría separar la tasa del importe de al lado si idioma de app y sistema difieren.
3. **Un solo formateador** → `ExchangeRateDisplayFormatter` en `Yala/App/Logic/`. La hoja de ganancia cambiaria delega en él (misma salida para tasas ≥ 1).
4. **Sitios** → detalle de transacción, widget del Panel (chips, tooltip, eje y etiquetas de la gráfica), las dos pantallas de Ajustes y el chip «TC:» del formulario de nueva transacción (mismo patrón, el ticket lo nombra como candidato; solo cambia la tasa, no el monto).
5. **`TransferAmountInputView`** → no se toca: allí la tasa ya se invierte cuando es < 1 (nunca sale «0,0000») y es un campo editable que se re-parsea; meter separador de miles podría romper la entrada. Se anota en el ticket.
6. **Control rojo** → mutante: el formateador con el `%.4f` viejo debe poner rojos los tests.
