# Widgets: suman importes guardados en otra divisa principal

## Contexto
Card del tablero `tablero-los-widgets-suman-importes-guardados-en-j3n2` (Yala 2.1, medium). Hallazgo del barrido del PR #438: el widget puede enseñar un gasto distinto del de la app cuando hay movimientos guardados con otra divisa principal (el usuario cambió la divisa principal y hay importes viejos guardados en la anterior). El PR #438 arregló la vista agregada de Tendencias y el PR #451 extendió la conversión a la divisa principal al resto de Tendencias (curvas por cuenta, históricos, saldos). Lee ambos PRs (diff y cuerpo) y REUTILIZA ese mecanismo de conversión en los widgets; no inventes otro. Si #451 aún no está en `origin/2.1`, ver regla de gate abajo. Ticket: `tickets/backlog/widgets-sum-stored-amounts-from-other-preferred-currencies.md`.

## Qué se pide
- Localizar los cálculos de importes de los widgets (y su timeline provider / snapshot compartido con la app) y normalizar a la divisa principal actual igual que la app tras #438/#451.
- Tests unitarios que fallen antes y pasen después (mezcla de importes guardados con dos divisas principales distintas).
- Capturas antes/después del widget si cambia lo que se ve (`capturas/antes.png`, `capturas/despues.png`; mira `~/Claude/referencias-ui/README.md`).

## Qué NO hay que tocar
- Tendencias (ya cubierto por #438/#451), esquema de CloudKit, delivery multi-divisa, nada de marketing/.
- No cambies el modelo de datos ni migraciones.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#451): arranca ya sobre `origin/2.1`; no partas de la rama de #451. Justo antes del gate, mira si #451 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Los widgets muestran los mismos importes que la app para datos con divisas principales mezcladas; tests nuevos en verde; PR abierto a 2.1 con antes/después en el cuerpo. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué regla de conversión usan los widgets?** → `CashFlowCalculator.resolvedAmount`, la de #434/#438/#451, con la divisa del snapshot y `CurrencyConverter.shared`.
Por qué: el encargo pide reutilizar el mecanismo de la app. Alternativa descartada: una conversión propia del widget.

**D2 · ¿Qué pasa con el «si el importe convertido es 0, usa el nativo» de `WidgetDataCache.preferredAmount`?** → Se retira con la función; manda `resolvedAmount`.
Por qué: ningún otro sitio de la app tiene ese fallback (grep), así que con él el widget seguiría pudiendo enseñar otro número que la app. Una fila guardada en otra divisa ya se reconvierte desde el nativo.

**D3 · Saldos (saldo del período y curva de tendencia del widget)** → misma regla con `adjustment: .none` (fila entera), la de `TrendDataProcessor.balanceAmount` de #451.
Por qué: el comentario del widget dice coincidir con `fillBalanceBuckets`, y tras #451 esa curva reconvierte. #451 entró antes del gate (rebase sobre `3e94b1e82`): la curva llama a `TrendDataProcessor.balanceAmount`; el saldo usa la misma regla con un envoltorio que además devuelve la magnitud dudosa, porque lleva marca «≈».

**D4 · El camino de emergencia del widget (recalcula desde `WidgetTransaction`)** → el snapshot guarda en `amountInPreferredCurrency` el importe YA resuelto, y en `isExchangeRateProvisional` si esa resolución fue aproximada. Sin campo nuevo en el DTO.
Por qué: un campo nuevo exige tocar los dos targets y arriesga apagar todos los widgets; el ticket admite «el importe ya resuelto». El widget de últimos registros pinta el importe nativo, así que nada más lee ese campo.

**D5 · La marca «≈» de los totales** → sale de `approximateMagnitude` de `resolvedAmount`.
Por qué: en la rama de la misma divisa da exactamente lo de hoy (`adjustment.approximateMagnitude`); en la de reconversión añade la calidad de esa conversión, como la app.

**D6 · ¿Capturas antes/después?** → No.
Por qué: con datos de una sola divisa no cambia nada visible y no hay semilla con filas sin recalcular (igual que #438 y #451); los tests cubren el caso.

**D7 · ¿Review adversarial?** → Sí, corta (dos lentes: corrección numérica y consumidores), porque toca cálculos financieros.

**D8 · Coste de la reconversión en el snapshot** (hallazgo de la review) → memo de conversiones local a cada `buildSnapshot` (`SnapshotMemoizedConverter`).
Por qué: la misma fila se resuelve en hasta ~20 superficies y cada conversión del converter compartido lee sus tasas del store en el hilo principal. Vive lo que el snapshot: no puede servir una tasa vieja.
