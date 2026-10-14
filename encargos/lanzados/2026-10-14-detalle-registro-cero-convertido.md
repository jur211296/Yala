# El detalle de un registro deja de pintar «≈ 0,00» cuando la conversión a la moneda principal no se escribió

## Contexto
Card del tablero: «El detalle de un registro pinta «≈ 0,00» cuando la conversión a la divisa principal no se escribió» (kab4), versión 2.2.
La fila «Tipo de cambio» de `TransactionDetailSheet` (`conversionRow`) muestra `amountInPreferredCurrency` tal cual. Si la conversión no se escribió (vale 0 con importe nativo distinto de 0; ver `CashFlowCalculator.storedConversionIsMissing`), pinta «≈ S/ 0,00», que parece un importe real. Pasa en filas que llegaron incompletas por sync o que se crearon sin tasas.
Decisión ya tomada: mostrar el importe reconvertido con la tasa del día del registro si existe; si no hay tasa, la fila muestra un texto llano traducido («Sin tipo de cambio para ese día») en vez de un importe. Nunca 0 como importe convertido. Tonos suaves como los del Panel.
La rama nace de origin/2.1, pero este trabajo va a **2.2**: rebasa sobre `origin/2.2` antes de empezar y abre el PR contra `2.2`.

## Qué se pide
1. Aplicar la decisión en el detalle, reutilizando la lógica existente de conversión/tasas (no duplicar cálculo).
2. Test unitario del caso (nativo ≠ 0, convertido 0, con y sin tasa del día).
3. Textos en los 16 idiomas.
4. Pipeline serial de la Mini: limpiar, `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador (iPhone 17 Pro), tests, apagar y borrar sus datos. Prohibido solapar build con simulador.
5. Antes del gate: fetch + rebase sobre origin/2.2, sin esperar el CI de PRs anteriores.
6. Capturas antes/después en `capturas/` (`antes.png`, `despues.png`).
7. Al cerrar, borrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados, sin preguntar.
8. PR a 2.2; fusionar cuando el CI esté verde.

## Qué NO hay que tocar
Solo el detalle del registro y su test. No tocar 2.1, marketing/ ni otros cálculos.

## Cómo se sabe que está bien
El detalle nunca muestra 0 como importe convertido de un registro con importe nativo distinto de 0; test verde; capturas; PR fusionado a 2.2.

## Paso 0

Decisiones resueltas antes de tocar código (sesión lanzada, sin nadie delante: las asumidas van marcadas).

1. **Qué cuenta como «la tasa del día del registro».** Solo `RateQuality.exact`: la fila de tasas de esa fecha trae las dos divisas. Si la conversión baja a la fila anterior (`carriedForward`) o a la tabla estática (`staticFallback`), el detalle muestra el texto «Sin tipo de cambio para ese día». *Asumido*: la tabla estática puede ir un orden de magnitud desviada (`currency-fx.md`), y pintar un arrastre como «del día» sería otra verdad a medias.
2. **Reutilizar, no duplicar.** La detección es `CashFlowCalculator.storedConversionIsMissing` y la reconversión es `CashFlowCalculator.reconverted` (la segunda rama de `resolvedAmount`). Su `approximateMagnitude == 0` es la señal de tasa exacta. La decisión pura vive en `TransactionDetailSheetLogic.conversionDisplay`, testeable sin SwiftUI.
3. **La línea «TC: …» bajo el importe.** Con el importe reconvertido muestra la tasa efectiva (|reconvertido| / |nativo|), no el `exchangeRate` guardado, que en esas filas no es la tasa usada. Sin tasa, desaparece: no hay tasa que enseñar. *Asumido.*
4. **Nunca 0.** Si la reconversión devolviera 0 con nativo ≠ 0, cuenta como sin tasa.
5. **Tono.** El texto va en `caption` y `.secondary`, como las notas suaves del Panel; ni rojo ni icono de error.
6. **Copy** (es-419): «Sin tipo de cambio para ese día», en las 16 `.lproj`.
7. **Capturas.** Sin seed nuevo (el encargo limita el alcance al detalle y su test): se crea un movimiento en USD desde la app y se pone su convertido a 0 en el SQLite del simulador.
8. **Rama.** Nació de `origin/2.1` sin commits propios; se movió a `origin/2.2` (`git rebase --onto origin/2.2 origin/2.1`) y el PR va contra `2.2`.
