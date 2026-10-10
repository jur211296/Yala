# La nota de la foto: antes y después (2026-10-10)

Ticket `image-note-uses-bank-template-instead-of-merchant`. El reporte: la nota salió «GROK XAI - Consumo con tarjeta de
crédito BCP» y tenía que ser «Grok (xAI)».

## Qué se midió

- **Modelo:** la fila de producción de `photo.read` (`gpt-6-luna`, esfuerzo `low`, detalle `high`, lado mayor 1536).
- **Casos:** los 38 de antes más **12 nuevos de alertas de banco** (`b01`–`b12`: BCP, Interbank, BBVA, Scotiabank, Yape y
  Plin, en español y en inglés; `fixtures/make_bank_alerts.py`). 50 imágenes, **2 repeticiones**, 510 movimientos
  esperados por corrida.
- **Nota cruda:** la que armaba la app hasta hoy (`comercio - nota`). **Nota limpia:** la que arma ahora, pasada por
  `VisionNoteCleaner.swift` compilado tal cual desde la app (`lib/noteCleaner.ts`).
- **Nota buena** (`noteOk` en `lib/grading.ts`): nombra el comercio esperado y no trae plantilla de banco, banco, números
  de 4 cifras o más ni asteriscos.
- **Categoría:** la foto no la devuelve. La pone la memoria de comercios con la nota, así que el banco no la puede medir.

## Resultado

| Corrida | Acierto (estricto) | Importe | Importe + fecha + divisa | Nota cruda | Nota limpia | Coste |
|---|---|---|---|---|---|---|
| **Antes** (prompt viejo) | 100 % | 100 % | 100 % | 59,4 % | 96,9 % | 0,033 USD |
| Después v1 (prompt largo, descartado) | **97 %** | 99,6 % | 99,6 % | 92,0 % | 92,7 % | 0,036 USD |
| **Después v2** (prompt corto, el que va) | 100 % | 100 % | 100 % | 86,5 % | 95,9 % | 0,041 USD |

**Solo los 12 casos de banco** (24 movimientos): antes, la nota cruda era buena en 11 de 24 y la limpia en 24 de 24. Después,
21 y 24 de 24. Importe, fecha y divisa: 24 de 24 en las dos.

## Qué se decidió con estos números

- **La limpieza en la app es la que arregla el bug.** Con el prompt de siempre ya lleva la nota del 59 % al 97 %, y cubre
  las respuestas que el modelo devuelva mal.
- **El prompt v1 se descartó porque rompía montos.** Pedía mayúsculas normales, la marca conocida y «nunca dejes vacíos
  el comercio y la nota». Con eso el modelo inventó movimientos en una página de resumen (`stmt-us-p1`) y perdió dos
  totales de recibo. Eso es peor que una nota fea.
- **El prompt v2 se queda.** Dice solo dos cosas: el comercio, nunca el banco, la billetera ni la tarjeta; y la nota
  null salvo un dato útil, nunca la plantilla del banco. No toca el acierto (100 %) y sube la nota cruda del 59 % al 87 %.
  La marca y las mayúsculas las pone la limpieza, que es determinista.
- **La nota limpia del v2 (95,9 %) frente a la de antes (96,9 %) no es una regresión.** Lo que queda en rojo es el
  criterio contra un comercio esperado que era una palabra de la línea del extracto: se esperaba «AGUA» y la nota dice
  «Sedapal», se esperaba «SUPERMERCADO» y dice «La Economía», o una línea de pago de tarjeta sin comercio («Pago tarjeta
  de crédito»). Ese 1 % es de la medida, no de la nota.

## Cómo repetirlo

```bash
cd gateway
npm run bench -- --task photo.read --only openai:gpt-6-luna --efforts low --details high --edges 1536 --reps 2 \
  --date AAAA-MM-DD-nota --max-usd 1
```

La primera corrida compila la limpieza con `swiftc` (unos segundos) y la guarda en `bench/.cache/`. El «antes» se midió
con el `ImageVisionService.swift` de `origin/2.1` puesto en su sitio durante la corrida.
