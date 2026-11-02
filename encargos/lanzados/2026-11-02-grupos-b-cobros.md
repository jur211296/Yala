---
esfuerzo: high
release: no
---
# Grupos B: lo cobrado por antigüedad, el ingreso con la fecha del pago, y Estadísticas, Yala IA y el conector

Cards: tablero-grupos-b-9-calculo-de-lo-cobrado-lo-mas-7y8f, tablero-grupos-b-10-al-liquidar-el-ingreso-cuent-emjb, tablero-grupos-b-11-estadisticas-yala-ia-y-el-co-8ukl

## Contexto
Manda la opción B que Jürgen acordó el 1-nov: `docs/disenos/grupos-tu-parte-en-lineas/README.md`, sección «Versión final acordada», y el diseño técnico en `tickets/in-progress/grupos-tu-parte-en-lineas.md` (PR #733).

## Qué hacer
### Card 9: Cálculo de lo cobrado: lo más antiguo primero
- Lógica pura: dado el historial del grupo y tus ventas por cobrar, qué parte queda cobrada y en qué fecha. Lo más antiguo primero (ventas y gastos adelantados por fecha), pagos a medias, deudas cruzadas que dejan el saldo en cero, «simplificar deudas» (cuenta tu saldo, no quién paga). Review adversarial (cálculo).
- Desbloqueo: Card 8 mergeada.
- Hecha cuando: Tabla de tests con los cuatro casos de la página (escenario 6) y mutantes muertos.

### Card 10: Al liquidar, el ingreso cuenta con la fecha del pago
- El puente de la liquidación crea las patas de ingreso cobrado (fecha del pago) y reduce lo por cobrar; la hoja de pago de la Bandeja añade «Cobras … cuentan como ingreso hoy». Textos en 16 idiomas.
- Desbloqueo: Card 9 mergeada.
- Hecha cuando: Caso Ana: Yape +120, Grupos 0, Ventas 120 en noviembre; XCUITest de la hoja de pago; capturas.

### Card 11: Estadísticas, Yala IA y el conector con ventas por cobrar
- Lo por cobrar no cuenta como ingreso y lo cobrado sí, en la app (calculadores, FullFinancialContextBuilder) y en el port de mcp/. Review adversarial (cálculo).
- Desbloqueo: Card 10 mergeada.
- Hecha cuando: Tests Swift y vitest: ingreso del mes = lo cobrado en el mes.

## Orden
1. Card 9: la lógica pura.
2. Card 10: la liquidación y la hoja de pago.
3. Card 11: los cálculos, la IA y el port de `mcp/`.

Haz una review adversarial del cálculo. Pon capturas de antes y después de la hoja de pago en el digest.

## Reglas
- Lo que toque el servidor (Worker o Supabase) se prueba en staging antes de producción.
- Capturas de antes y después de la UI en el digest.
- Si algo no cabe, crea su card en 2.2 antes del barrido QA (S36).

Termina con /cerrar-total.

## Paso 0

Decisiones tomadas antes de escribir código (sesión autónoma; lo asumido va marcado).

1. **Un PR con las tres cards.** «Desbloqueo: card N mergeada» se cumple dentro de la rama. Tres PRs encadenados
   obligarían a esperar el CI de cada uno. Van en un solo commit de código: el sello del gate es la huella del árbol
   contra HEAD, y un commit por card pediría tres gates sobre árboles que nunca se probaron por separado.
2. **Qué cubre una venta: tu saldo en el grupo, lo más antiguo primero** (`GroupReceivableCoverageLogic`, pura). Cada
   movimiento del grupo que te toca en la divisa de la venta sube o baja tu saldo: lo que pagaste por otros y las ventas
   suben (lotes a favor, con fecha); tu parte de lo que pagó otro y lo que te pagan bajan. Lo que baja consume primero el
   lote más antiguo; si consume una venta, esa parte queda **cobrada con la fecha del movimiento que bajó el saldo**. Una
   venta que llega cuando ya debías algo se cobra en su propia fecha contra esa deuda. Los cuatro casos de la página salen
   de la regla: pago parcial (abril cubre la cena, mayo la venta), venta a medias (50 hoy, 70 después), deudas cruzadas
   (120 en total), «simplificar deudas» (cuenta tu saldo, no quién paga). *Asumido:* en deudas cruzadas, si el almuerzo
   de Ana es posterior a la venta, sus 64 cuentan el día del almuerzo y los 56 el día del pago (la regla «al bajar tu
   saldo» de la misma tabla); la página no fecha esa fila.
3. **Cómo queda en tus cuentas.** La pata «por cobrar» guarda solo el resto; lo cobrado va en patas de ingreso normales en
   «Grupos» (categoría de la venta, fecha del cobro, sin `balanceAdjustmentType`), una por (venta, movimiento que la
   cubre). «Grupos» suma lo mismo que antes y Estadísticas cuenta el ingreso el día del cobro. Venta cobrada entera: sin
   pata por cobrar. La liquidación de siempre no cambia.
4. **La marca de una pata cobrada viaja en `splitLinesRaw`** (`{"k":"c","of":<id del movimiento>,"v":1}`): no hace falta
   campo nuevo, ni CloudKit, ni Worker. Este build la lee como `.collected`; una build con las cards 2-8 la lee como pata
   derivada de una línea y la borra al repasar la venta (residual de builds intermedias, se corta con la versión mínima).
5. **Quién la escribe: una pasada por grupo** (`reconcileReceivables`) al final de cada puente de gasto o liquidación del
   grupo y de cada borrado, solo si el grupo tiene ventas. Ids deterministas por (venta, movimiento): dos aparatos
   convergen, y un duplicado se funde con la regla del superviviente.
6. **La hoja de pago**: frase bajo la cuenta con lo que ese pago cobra, leída de las patas cobradas de esa liquidación.
   «hoy» si el pago es de hoy; si no, con su fecha. Una venta: nombre, importe y categoría; varias: los nombres y el total.
7. **Registros** dice «Cobrado» en la pata cobrada (como «Por cobrar» en la card 8), y el editor, el lote y el menú la
   tratan como pata del puente (todo bloqueado).
8. **Card 11:** Estadísticas y Yala IA ya excluyen lo por cobrar por su tipo (card 8). Lo cobrado es un ingreso normal;
   el ajuste de grupo (`GroupBridgeStatsAdjustment` y su port en `mcp/`) lo deja fuera del neteo de préstamos de forma
   explícita. Tests: ingreso del mes = lo cobrado en el mes, en Swift y en vitest.
9. **Sin servidor**: nada toca Worker ni Supabase, así que no hay paso de staging.

## Lo que cambió la review adversarial

Tres lentes (cálculo, puente y consumidores, cifras). Arreglado:
- **Observaciones** contaba lo cobrado como gasto compartido (tiene el puntero de la venta): fuera de los dos filtros.
- **Un céntimo** que el grupo ya da por saldado (Ana paga 119,99 de 120) quedaba «por cobrar» para siempre: va con la
  última parte cobrada.
- **Lotes** (pull de Grupos, importar el historial): el repaso corría en cada gasto y leía el grupo entero N veces; ahora
  una vez por grupo al final del lote.
- **Salidas tempranas** (te quitan del gasto, o la liquidación deja de incluirte): ahora también repasan.
- **Dos aparatos** escriben cada uno su pata cobrada: el repaso al volver a primer plano funde las copias.
- **Puerta de dominio**: el repaso no escribe con Grupos cerrado.
- **Conector**: `isCollectedLeg` exige un UUID y acepta `l: null`, como la app.

Queda fuera, con card o en el PR: la venta en una divisa y el pago en otra (grupos con «deudas en una sola moneda»): el
saldo del grupo se guarda por divisa y la consolidación es solo de pantalla, con el tipo del día; cubrirla pide decidir
con qué tipo. Las liquidaciones duplicadas por id (el saldo del grupo las cuenta dos veces, lo cobrado una) y una venta
marcada «saldada» por sync (pierde sus patas, como pierde su deuda en el grupo).

## Por el camino

- Xcode se actualizó a 27.2 a mitad de la sesión. Jürgen instaló los componentes y pidió adaptarse: la Mini queda con un
  solo simulador (iPhone 17 Pro, iOS 27.2), sin el runtime 27.0 ni el del Duo. Commit aparte, `chore(xcode)`.
- Banco de mutantes sobre el cálculo: 10 de 10 muertos. El único superviviente («un gasto que pagó Ana cuenta como venta
  tuya») no cambiaba lo cobrado; se fija en `events` con `aSaleThatAnaPaid_isNotYourSale`.
- Capturas de la hoja de pago con y sin venta en `docs/disenos/grupos-tu-parte-en-lineas/card-10-pago-*.jpg`.
