# Extractos en PDF de varias páginas: `photo.read` página a página (2026-10-08)

Ticket `pdf-statement-reads-only-the-first-page`. La app lee un PDF hasta 10 páginas, cada página como una foto más
(render a 2×, reducida a 1536 px). La pregunta: ¿el modelo de hoy saca como movimientos el saldo arrastrado, los
subtotales o las páginas sin movimientos?, y ¿lee una página densa de 40 filas?

## Casos (12 páginas nuevas, `stmt-*`)

Todos ficticios, generados por `bench/fixtures/make_statements.py`. Cada página es un caso con la verdad de esa página
sola; un saldo o un subtotal leído como movimiento cuenta como «de más» y el caso falla.

| Extracto | Páginas | Qué trampa lleva |
|---|---|---|
| `stmt-pe` (ahorros, S/, es-PE) | 3 de movimientos (14+14+12) + 1 de condiciones | Saldo anterior, «saldo que pasa / viene de la página anterior», subtotal por página, totales del periodo, saldo al corte; la página 4 trae tasas, comisiones y un saldo promedio en el texto y ningún movimiento |
| `stmt-pe-dense` | 1 | Las mismas 40 filas en una sola página a 7 pt (el «uno de 40, no medido» del ticket) |
| `stmt-us` (checking, $, en-US) | resumen + 2 de detalle (12+8) | La página 1 es solo saldos y totales con «$»; las de detalle dicen «Beginning balance», «Balance forward», «Balance carried forward», totales y «Ending balance», y no escriben «$» en ninguna parte |
| `stmt-es` (cuenta, €, es-ES) | 2 (10+8) | Coma decimal, «Suma y sigue» / «Suma anterior», «Total hoja», «Saldo final» |
| `stmt-tc` (tarjeta, S/, es-PE) | 2 (9+6) | Una sola columna de importes: saldo anterior, el que pasa, subtotal, deuda total y pago mínimo van en la MISMA columna que los consumos; un pago y una devolución en negativo |

## Resultado: el prompt de hoy ya los separa

Fila de producción (`gpt-6-luna`, esfuerzo `low`, detalle `high`), 5 repeticiones por página:

| Lado mayor | Llamadas | Aciertos | Saldos o subtotales leídos como movimiento | Páginas sin movimientos devueltas vacías | Latencia |
|---|---|---|---|---|---|
| 1536 (11 normales + la densa) | 60 | **59 (98,3 %)** | **0** | 10 de 10 | p50 4,5 s / p95 6,5 s (normales); 11,5–13,1 s (la densa) |
| original 1684 (solo la densa) | 3 | 3 | 0 | — | 11,4–12,0 s |
| 1024 (solo la densa) | 3 | 3 | 0 | — | 13,5–15,1 s |

- **Ningún saldo arrastrado, subtotal, total ni pago mínimo salió como movimiento** en 66 llamadas, tampoco en la
  tarjeta, donde van en la misma columna que los consumos. Las dos páginas sin movimientos volvieron vacías 10 de 10.
- **El único fallo** (1 de 5 en `stmt-es-p1`): «REINTEGRO CAJERO 100,00», en la columna Debe, salió con otro importe o
  signo. En España *reintegro* es retirar; en otros países, devolver. Es una lectura de signo, no de saldos.
- **La página de 40 filas se lee entera** a 1024, 1536 y original (11 de 11 llamadas, 40 de 40 movimientos cada vez).
- **Por eso no se cambió el prompt.** Una regla de «los saldos no son movimientos» no tenía nada medible que mejorar.

### Duplicados entre páginas: qué los quita

Dos capas, ninguna nueva:

1. **El modelo no los emite** (lo medido arriba): cada página se lee sola y los saldos arrastrados y subtotales salen
   fuera en 66 de 66 llamadas.
2. **La red de la app** (`DraftDeduplicationService.deduplicate`, sin cambios) junta dentro de la tanda dos borradores
   con el mismo importe, el mismo día y una nota parecida. Cubre una fila que el banco repita al pie de una página y al
   principio de la siguiente. No cubre un saldo con nota distinta en cada página («Saldo que pasa» / «Saldo anterior»),
   y por eso la capa que cuenta es la primera.

## Lo que sí sale, y es de la app

**Una página que no escribe la divisa vuelve con `currency: null`.** En `stmt-us` el «$» solo está en el resumen de la
página 1. Leídas solas, las páginas de detalle no tienen ningún indicador, y el prompt pide `null` en ese caso: en la
primera corrida, descartada al corregir la verdad del caso, salieron 4 de 4 con `null`. En la app, un borrador sin
divisa no casa ninguna cuenta (`VisionDraftFactory` → `DraftBuilder.findAccount(byCurrency:)`) y la persona elige
cuenta en cada fila. El caso acepta `null` (`currencyAlt`). Salida posible, en la app: si otra página del mismo PDF
trajo divisa, heredarla en las que volvieron con `null`. Queda como ticket aparte.

## Recomendación de modelo y resolución

**No cambiar nada: `photo.read` se queda en `gpt-6-luna` a 1536 px.** La calidad es la misma de 1024 al original, y
1536 ya es menos que la página a 2× (1684), así que la app no manda nada que el modelo no aproveche.

Lo que cambia es la latencia de una página densa: **11,5–15 s**, frente a los 4–7 s de una página normal, porque
escribe unos 2 000 tokens de salida. El SDK de la app corta a **20 s** (`ProxyClientFactory`, `timeoutInterval: 20`).
Hay margen, pero es el primer caso del banco que pasa de 10 s. Un PDF de 10 páginas densas tarda unos 2 min en leerse.

## Coste

66 llamadas, **0,041 USD**: unos 0,00047 USD por página normal y 0,0013 USD por la densa. Tope de la sesión: 1 USD.

## Cómo repetirlo

```bash
python3 bench/fixtures/make_statements.py      # regenera las 12 páginas y sus casos stmt-*
npm run bench -- --task photo.read --only openai:gpt-6-luna --efforts low --details high --edges 1536 \
  --cases stmt-pe-p1,stmt-pe-p2,stmt-pe-p3,stmt-pe-p4,stmt-pe-dense,stmt-us-p1,stmt-us-p2,stmt-us-p3,stmt-es-p1,stmt-es-p2,stmt-tc-p1,stmt-tc-p2 \
  --reps 5 --date 2026-10-08-multipagina/antes
```
