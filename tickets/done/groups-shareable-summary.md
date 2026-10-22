---
id: groups-shareable-summary
status: done
priority: medium
area: groups
created: 2026-07-01
source: YalaWiki/Backlog/groups-resumen-compartible-exportable.md
updated: 2026-09-08
qa-status: passed
qa-date: 2026-09-08
---


# Resumen de grupo compartible/exportable ("cierre del viaje")

## Problema

Al cerrar un viaje o evento con gastos compartidos, no hay forma de generar un resumen visual o exportable — quién pagó qué, balance final, cómo saldar en pocos pagos. Hoy la única forma de "compartir" algo del grupo es el enlace de invitación (`createShareLink()`, CKShare) — no un resumen de cierre.

## Solución

Un resumen (imagen renderizada y/o PDF, más un CSV de settlements) generado a partir de datos que ya se calculan hoy: quién pagó más, desglose por categoría, y las deudas simplificadas a la mínima cantidad de pagos necesarios para saldar todo. Punto de entrada natural: un botón "Compartir resumen" en `GroupSettingsView` o en el header de `GroupStatsView`/`GroupBalancesView`.

## Por qué es Tier 1 (bajo riesgo)

Es de solo lectura — no crea, modifica ni borra ningún `SplitExpense`/`SplitSettlement`. No toca el schema CloudKit de Grupos en absoluto. Reutiliza exclusivamente cálculos que ya existen y ya corren en cada apertura del detalle del grupo.

## Servicios existentes a reutilizar (confirmado en código, 2026-07-01)

| Servicio | Qué aporta | Notas |
|---|---|---|
| `GroupStatsViewModel.swift` | `memberSpending: [MemberSpending]`, `categoryBreakdown: [GroupCategoryBreakdown]`, `monthlyTrend: [GroupMonthlyTrend]`, `totalSpent`, `myPortion` — todo ya calculado por período/moneda | Multi-moneda: `perCurrencyStats`, `totalsByCurrency`, `availableCurrencies` — un resumen de cierre probablemente quiere "todo el historial" (`selectedPeriod = .allTime`), no el período por defecto |
| `DebtSimplificationService.simplify(debts:) -> [Debt]` | Algoritmo greedy O(n²) que reduce N deudas cruzadas a la mínima cantidad de pagos — `Debt { fromMemberID, toMemberID, amount, currencyCode }` | Ya lo usa `GroupBalancesView` para mostrar deudas simplificadas — es exactamente el "cómo saldar en pocos pagos" que pide este ticket |
| `GroupBalanceService.calculateBalances`/`calculateDebts` | Balance neto por miembro + deudas crudas (input de `simplify`) | Stateless, sin cache — recalcular para el resumen es aceptable (no es un hot path repetido) |
| `TransactionsExportService.swift` | `exportToCSV`/`export`/`makeCSVData`/`makeExportData` — patrón de export ya usado para transacciones personales | Es específico de `TransactionItem`, NO de `SplitExpense` — sirve como referencia de patrón (estructura de columnas, generación de archivo), no es reutilizable directo sin adaptar |

**No existe ningún precedente de renderizado a imagen/PDF en el codebase** (grep de `ImageRenderer`/`UIGraphicsPDFRenderer`/`ShareLink` en `Yala/App/Views/` sin resultados relevantes a exportación visual) — esto sería la primera vez que la app genera un asset visual compartible, no solo un archivo de datos. `ShareLink`/`createShareLink()` existentes son para el **enlace de invitación** (CKShare), un concepto completamente distinto — no confundir ambos en el nombre del botón/función nueva.

## Plan técnico

### Qué falta construir

1. **Vista de resumen dedicada** (SwiftUI) que consuma `GroupStatsViewModel` (con `selectedPeriod = .allTime`) + `DebtSimplificationService.simplify(...)` — diseño simple: header con nombre/icono del grupo + total gastado + tarjetas por miembro (cuánto pagó, cuánto le corresponde) + lista de "pagos para saldar" (de `simplify`).
2. **Renderizado a imagen**: `ImageRenderer(content: resumenView).uiImage` (API SwiftUI nativa, iOS 16+) — sin dependencias nuevas.
3. **(Opcional) PDF**: `UIGraphicsPDFRenderer` envolviendo la misma vista, o diferir a v2 si la imagen sola ya cubre el caso de uso principal ("mandar el resumen por WhatsApp").
4. **(Opcional) CSV de settlements**: adaptar el patrón de `TransactionsExportService.makeCSVData` a una lista plana de `Debt`/`SplitSettlement` — columnas: de, a, monto, moneda, confirmado.
5. **Punto de entrada**: botón "Compartir resumen" en `GroupSettingsView` (junto a las secciones existentes) o en el toolbar de `GroupStatsView`/`GroupBalancesView` — presenta un `ShareLink`/`UIActivityViewController` nativo con la imagen generada.

### Decisión de diseño abierta

¿El resumen es de **todo el historial** del grupo, o del **período actualmente seleccionado** en Stats? Para el caso de uso "cierre del viaje" tiene más sentido todo el historial (`selectedPeriod = .allTime`) — pero si se reutiliza el mismo botón desde Stats con un período específico ya seleccionado, podría tener sentido respetar ese filtro. Decidir antes de implementar; afecta si el botón vive en Settings (sugiere todo el historial) o en Stats (sugiere período actual).

## Decisión Jürgen (2026-09-06)

**Todo el historial, con el botón en Ajustes del grupo.** Elegida entre eso y «el período
seleccionado, con el botón en Estadísticas». Motivo, tal como se le puso delante y ratificó: el caso de uso es el cierre del viaje; un solo
comportamiento que no depende del filtro que haya puesto en la pestaña. `selectedPeriod = .allTime`.

## Acceptance Criteria

- [x] Existe un punto de entrada ("Compartir resumen" o similar) desde el cual se genera una imagen compartible con: nombre del grupo, total gastado, desglose por miembro (cuánto pagó cada uno), y la lista mínima de pagos para saldar todas las deudas (vía `DebtSimplificationService.simplify`).
- [x] El resumen respeta multi-moneda si el grupo tiene gastos en más de una (mostrar por separado, no mezclar montos de distinta moneda en una suma).
- [x] La imagen generada se comparte vía el share sheet nativo de iOS (`ShareLink` o `UIActivityViewController`).
- [x] No se crea, modifica ni borra ningún dato del grupo al generar el resumen (verificado: es una operación de solo lectura).
- [x] Localización del texto del resumen en los 16 locales del proyecto.

## Notas

- El nombre de la feature/botón debe distinguirse claramente de "Invitar por enlace" (`createShareLink`) para no confundir a los usuarios — son dos "compartir" distintos (invitar vs. resumen de cierre).
- CSV de settlements (punto 4) es menor prioridad que la imagen — la imagen es lo que resuelve el caso de uso principal descrito ("mandar el resumen del viaje"); el CSV es un nice-to-have para quien quiera los números en una hoja de cálculo.

migrated from YalaWiki Backlog/groups-resumen-compartible-exportable.md @ 1934e8ad

---

## Implementado (2026-09-07)

**Qué hace ahora la app.** En Ajustes de un grupo hay una sección nueva, «Resumen del grupo», con un
botón «Compartir resumen». Genera una imagen con el nombre y el icono del grupo, la fecha, el total
gastado, una tabla de quién pagó qué (lo que puso cada uno y lo que le tocaba) y la lista mínima de
pagos para saldarlo todo. Se ve antes de mandarla —lo que se previsualiza es la imagen ya
renderizada, no una maqueta— y se comparte por el share sheet de iOS: WhatsApp, Mensajes, Guardar en
Fotos. Cubre **todo el historial** del grupo, sin depender del filtro de Estadísticas (decisión del
owner, 2026-09-06). Si el grupo tiene gastos en varias monedas, cada una lleva su propio bloque: no
se suman entre sí. Y si no queda nada pendiente, lo dice con un «¡Todo saldado!» en verde.

Es de **solo lectura**: no crea, modifica ni borra nada del grupo.

**Piezas nuevas**
- `Yala/App/Logic/GroupShareableSummaryLogic.swift` — la lógica pura: qué cuenta como gasto, qué como
  deuda, y cómo se reparte todo por moneda.
- `Yala/App/Views/Groups/GroupShareableSummaryCard.swift` — la tarjeta que se rasteriza. Sin un solo
  `@Environment` dentro, a propósito.
- `Yala/App/Views/Groups/GroupShareableSummarySheet.swift` — la previsualización y el compartir.
- Sección nueva en `GroupSettingsView`, 12 claves en los 16 `.lproj`, y
  `NSPhotoLibraryAddUsageDescription` en el `Info.plist` y en los 16 `InfoPlist.strings`.

**Primera vez que la app genera una imagen.** No había ningún precedente de `ImageRenderer` ni de
PDF en el codebase (medido, el ticket lo decía y seguía siendo cierto). De ahí las dos reglas que
gobiernan la tarjeta: ni un `@Environment` dentro —`ImageRenderer` hostea su contenido fuera del
árbol y una sub-vista que lea `AppPreferences` daría `SIGTRAP`, la misma trampa que las
`.annotation` de Swift Charts— y colores fijos en claro, porque la imagen sale de la app y no puede
depender del tema del que la mandó.

**El CSV de liquidaciones del plan técnico (punto 4) se deja fuera**, y no por recorte: ya existe.
`GroupsExportBuilder` genera un CSV de grupos con gastos, liquidaciones y balances desde el wizard
de exportación. El ticket lo daba como nice-to-have frente a la imagen, que es lo que resuelve el
caso de uso.

### Lo que cambió la review adversarial

Tres lentes independientes sobre el mismo cambio. **La más cara fue una decisión mía razonada al
revés**: había escrito que los pagos irían siempre por moneda cruda, «porque una conversión al
cambio del momento se congela en una imagen». El razonamiento era bueno para los totales y falso
para los pagos, porque se me escapó que la preferencia «ver deudas en una sola moneda» **también
decide en qué moneda se ESCRIBE la liquidación**: `SettlementFormView` recibe una deuda ya
consolidada. Con ese ajuste puesto, una cena de US$ 100 liquidada por S/ 380 dejaba la deuda
original viva en dólares y el pago como deuda inversa en soles — la imagen habría mandado al chat
dos transferencias fantasma en direcciones opuestas por dinero ya pagado, contradiciendo a la
pestaña Balances de la propia app. Ahora, con ese ajuste, los pagos se consolidan a la moneda del
grupo y se marcan con «≈»; los totales siguen sin sumarse jamás entre divisas.

Los otros ocho, en corto:

1. **La imagen se ofrecía en grupos migrados y congelados**, que enseñan una copia de cuando el
   grupo se movió — la app ya avisa de que «puede que no esté al día». La imagen no tiene dónde
   poner ese aviso y encima se fecha hoy. Ya no se ofrece. (No es `canCurrentUserParticipate`: quien
   salió del grupo sí conserva el resumen.)
2. **El botón se ofrecía con un proxy equivocado** (`!expenses.isEmpty`), que cuenta también los
   saldos iniciales. Un grupo importado y ya liquidado producía una tarjeta con cabecera, fecha y
   pie, y nada en medio. Ahora lo decide el propio resumen.
3. **Los repartos no se deduplicaban**, solo los gastos: el total quedaba blindado y «le tocaba»
   salía al doble. La misma imagen contradiciéndose a sí misma.
4. **Sin techo de tamaño.** Un grupo de 40 personas en 4 divisas da ~13 000 pt de alto: a escala 3
   son 38 940 px —más del doble del techo de textura de la GPU— y un bitmap de ~336 MB. Ahora se
   mide el contenido antes de rasterizar y la escala se acota (2× como máximo, y menos si hiciera
   falta). Se prefiere perder nitidez a recortar filas de un resumen de dinero.
5. **Faltaba `NSPhotoLibraryAddUsageDescription`.** «Guardar imagen» del share sheet escribe en la
   fototeca, y es la primera vez que esta app lo hace: sin la clave, crashea.
6. **«Inténtalo otra vez» sin nada que tocar.** El error de render ya trae botón de reintento.
7. **El `ActivityView` sin `onDismiss` ni `completion`**, que es justo lo que prohíbe la regla del
   bug de la «toolbar muerta». Añadidos los dos.
8. Menores: el importe de la lista de pagos podía ser lo que se truncara con dos nombres largos;
   VoiceOver leía el título del sheet dos veces y ni un dato de la imagen; `owedLabel` en polaco era
   «Jego część», el único texto nuevo con género marcado; y el chino estrenaba 小结 donde la app dice
   摘要 en cinco sitios.

**Y una explicación mía que era falsa, aunque la medición fuera buena.** Había documentado que la
columna «le tocaba» no cuadra «porque el reparto asigna los céntimos gasto a gasto». Lo que vi en el
simulador era cierto (123,34 × 3 contra un total de 370), pero la causa no: `GroupSplitCalculator.equalSplit`
**sí** reparte el residuo y cuadra exacto. El descuadre era del seed, que redondea sin repartir. En
producción el descuadre existe por otras vías —el reparto exacto tolera ±0,02, y los importes que
bajan del wire no pasan por el calculador—, con otra frecuencia y otra magnitud. Un comentario que
dice «medido» y está mal es peor que no tenerlo.

### Verificado

- Build ×2 (`Yala` y `Yala Dev`) en verde, sin warnings nuevos.
- **18 tests propios** (`GroupShareableSummaryLogicTests`) y la suite entera en verde: 6334 tests en
  643 suites.
- **Nueve mutantes verificados**, uno por decisión: cada uno pone rojo exactamente su test. **Dos
  sobrevivieron en su primera pasada** y obligaron a escribir el caso que los distingue — el del
  orden de monedas usaba PEN/USD, donde «la principal primero» y «alfabético» coinciden. Es la
  trampa del helper ciego de `.claude/rules/testing.md`, y salió dos veces en el mismo cambio.
- XCUITest: `GroupsSmokeUITests` 10/10, incluido el caso nuevo. Es el **primero que entra en
  `GroupSettingsView`** — esa pantalla no tenía ni un `accessibilityIdentifier`, así que se añadió
  uno al engranaje de `GroupDetailView` y otro a la fila nueva.
- Paridad de localización: 23 tests en 5 suites, verde. 12 claves × 16 locales, cero
  `[NEEDS_TRANSLATION]`, alias `es`/`pt` byte-idénticos a sus bases.
- En el simulador (seed `grupos`, iPhone 17 Pro, iOS 26.5): la imagen sale con sus dos bloques
  PEN/USD y el neto cuadra con el header del grupo (S/ 190,00 + $ 46,67).

### Pendiente

- **Device-QA**: el share sheet real —mandarla por WhatsApp y **Guardar en Fotos**, que es camino
  nuevo y estrena el permiso de fototeca— y cómo se ve la imagen recibida en un chat.
- Dos tickets abiertos de camino: `debt-simplification-nondeterministic-ties` (ante un empate exacto
  de saldos, la simplificación puede devolver conjuntos distintos entre ejecuciones; hasta ahora
  quedaba en pantalla, ahora se congela en una imagen) y
  `group-balance-service-shares-not-deduped` (el mismo hueco de repartos duplicados que se cerró
  aquí, todavía abierto en el servicio que alimenta Balances).

---

## QA Visual · 2026-09-08

**Veredicto: PASS.** iPhone 17 Pro (iOS 26.5), `Yala Dev`, seed `grupos`, grupo «Viaje a Cusco»
(3 miembros, gastos en PEN y USD). Ajustes del grupo → «Compartir resumen».

### Lo que se vio

La previsualización monta la imagen ya rasterizada, con **un bloque por moneda**, que era el AC
central:

**Bloque PEN** — Total gastado S/ 1.230,00

| Quién | Pagó | Le tocaba |
|---|---|---|
| Tú | S/ 600,00 | S/ 410,00 |
| Ana | S/ 360,00 | S/ 410,00 |
| Beto | S/ 270,00 | S/ 410,00 |

Para saldar: **Beto → Tú S/ 140,00** · **Ana → Tú S/ 50,00**

**Bloque USD** — Total gastado $ 370,00

| Quién | Pagó | Le tocaba |
|---|---|---|
| Tú | $ 170,00 | $ 123,34 |
| Ana | $ 150,00 | $ 123,34 |
| Beto | $ 50,00 | $ 123,34 |

Para saldar: **Beto → Tú $ 46,67** · **Beto → Ana $ 26,66**

Cabecera con nombre e icono del grupo, fecha («8 de setiembre de 2026»), pie «Hecho con Yala» y el
botón **Compartir resumen** que abre el share sheet.

### La aritmética cierra, y con la pantalla anterior

No es solo que los números se vean: **cuadran entre sí y con la cabecera del grupo**.

```
PEN  600+360+270 = 1.230 ✓      1.230/3 = 410 ✓
     neto Tú: 600-410 = 190  =  140 + 50 (los dos pagos mínimos) ✓
USD  170+150+50 = 370 ✓         370/3 = 123,33 → 123,34 ✓
     neto Tú: 170-123,34 = 46,66 ≈ 46,67 ✓
```

Y el balance del detalle del grupo decía **«Te deben S/ 190,00 + $ 46,67»** — los mismos dos netos,
por separado y sin mezclar monedas. Ese cruce es lo que descarta que el resumen esté pintando
números plausibles pero desconectados del grupo.

**No aparece «≈» y es correcto**: al separar por moneda no hay conversión que marcar.

### Captura

- `qa-shareable-summary-01-dos-bloques-moneda-20260908-212149.png`

### Lo que queda fuera de esta pasada

- **«Guardar en Fotos»** y cómo se ve la imagen ya recibida en WhatsApp/Telegram: eso sí es device.
- El share sheet se abre desde el botón, pero no se completó ningún envío real.
