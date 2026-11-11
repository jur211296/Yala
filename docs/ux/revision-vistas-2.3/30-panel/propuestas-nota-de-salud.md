# Nota de salud: propuestas de mejora (para decidir)

Decisión 9 de la revisión 2.3 (9-nov-2026) pidió dos cosas. La primera ya está hecha en el lote del 11-nov: la nota
sale con dos de las tres partes, la tarjeta dice qué falta y lo que la nota no ve, y la hoja deja de felicitar si hay
alertas. La segunda es este documento: propuestas para que la nota sirva de verdad. **Nada de esto está implementado.**

Cada propuesta dice qué ve hoy la persona, qué cambia y lo que cuesta. Las cifras de «hoy» salen del código de
`origin/2.3` (`FinancialScoreCalculator`), salvo donde dice «inferido».

## Lo que la nota mide hoy

| Parte | Peso | Qué mira | Su punto débil |
|---|---|---|---|
| Presupuestos | 40 % | Cada presupuesto vale 100; pasarse resta 8, rozar el límite al final resta 3 | Pasarse por el doble sigue dando 92 |
| Ritmo | 25 % | La racha más larga sin registrar **entre** dos días con registros | No mira los días desde el último registro hasta hoy |
| Compromisos | 35 % | Si el saldo cubre los pagos pendientes, y cuánto de lo que entra se va en ellos | Sin ingresos, la mitad vale 50 fijo |

Y encima, la nota total nunca baja de 50, aunque Configurar Panel la describe «de 0 a 100».

## Propuestas, por lo que aportan

### 1. Ritmo: contar también los días desde el último registro (recomendada, esfuerzo bajo)

- **Hoy:** quien registró los días 1, 2 y 3 y nada más ve Ritmo 100 el día 25. Con un solo día de registros, también 100.
- **Cambio:** el hueco hasta hoy cuenta como cualquier otro (en un período en curso). Quien deja de registrar ve bajar su
  ritmo, que es justo lo que la parte promete («Cuántos días seguidos pasas sin registrar»).
- **Coste:** un cambio en `computeMaxGap` y sus tests. Cambia notas que hoy ven las personas: bajarán para quien dejó de
  registrar.

### 2. Una parte nueva: lo que te queda del mes (tasa de ahorro) (recomendada, esfuerzo medio)

- **Hoy:** la nota no mira si gastas más de lo que entra. Es lo primero que mira cualquier medida de salud financiera.
- **Cambio:** «Te queda» del período (entró − salió) sobre lo que entró, con la regla de una cifra del Panel. Por
  ejemplo: 20 % o más vale 100; 0 % vale 50; gastar más de lo que entra baja de 50.
- **Coste:** pesos nuevos para cuatro partes, textos en 16 idiomas, y una decisión para «Solo gastos» (sin ingresos no
  se puede calcular: la parte no cuenta).

### 3. Pasarse de un presupuesto pesa según cuánto (recomendada, esfuerzo bajo)

- **Hoy:** pasarse por S/ 1 o por el doble del límite da lo mismo: 92.
- **Cambio:** la nota del presupuesto baja con lo que se pasó. Por ejemplo: 100 % del límite vale 90; 150 %, 50; el doble
  o más, 0.
- **Coste:** solo `scoreForBucket` y sus tests.

### 4. Cuentas en rojo dentro de la nota (opción D de la ficha, esfuerzo medio-alto)

- **Hoy (tras este lote):** la tarjeta las nombra («Efectivo en negativo») pero la nota no baja.
- **Cambio:** una cuenta en negativo (sin tarjetas de crédito) resta en Compromisos, o es una cuarta parte.
- **Coste:** decidir qué es «rojo» de verdad: un sobregiro autorizado, un préstamo o un efectivo mal apuntado no son lo
  mismo. Recomiendo esperar a ver cuántas personas reales tienen cuentas en rojo y por qué (inferido: muchas son
  efectivo que no apuntaron como ingreso).

### 5. Quitar el suelo de 50 o pasar a niveles (opción C de la ficha, esfuerzo medio)

- **Hoy:** la hoja dice «La nota total nunca baja de 50» y Configurar Panel dice «de 0 a 100». Se contradicen.
- **Cambio, dos caminos:** (a) quitar el suelo y que la escala sea la que se dice; (b) «Bien · Atento · Revisa» en vez del
  número. Con las propuestas 2 y 3 la nota baja de verdad cuando algo va mal, y el suelo esconde justo eso.
- **Coste:** (a) es una línea y un texto; (b) rehace tarjeta, hoja y textos.

### 6. Visibilidad: la nota en el Panel y su evolución (esfuerzo medio)

- **Hoy:** la sección llega **apagada** en el Panel (`PanelDefaults.hiddenSections`); se ve en Estadísticas › Resumen.
- **Cambio:** encenderla por defecto cuando las propuestas 1-3 estén dentro, y una línea «subió 6 desde el mes pasado»
  con la nota del mes anterior. Una nota que cambia y se explica es la que se vuelve a mirar.
- **Coste:** calcular la nota del período anterior (otra pasada por el cálculo) y decidir el texto.

## Lo que no recomiendo

- **Más partes de golpe.** Con cuatro o cinco partes ya no se entiende de dónde sale el número; la hoja de desglose deja
  de caber a media altura.
- **Comparar con «la media de usuarios».** No tenemos ese dato sin mandar finanzas a un servidor.

## Orden propuesto

1 y 3 primero (bajo esfuerzo, corrigen lo que hoy engaña), luego 5a (coherencia de la escala), después 2 y 6. La 4 se
decide con datos.
