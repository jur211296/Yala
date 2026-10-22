# photo.read — banco del 2026-10-10-nota-despues

Precios comprobados el 2026-10-07. Generado por `npm run bench -- --report`.

| Candidato | Proveedor | Esfuerzo | Detalle | Lado mayor | Casos | Acierto | JSON válido | Errores | p50 ms | p95 ms | Tokens entrada (media) | Tokens salida (media) | Coste medio (USD) | Coste por 1 000 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `gpt-6-luna` | openai | low | high | 1536 | 100 | 97.0 % | 100 % | 0 | 10786 | 27493 | 3014 | 367 | 0.000357 | 0.357 |

| Candidato | Movimientos esperados | Importe | Importe + fecha + divisa | Comercio | Nota cruda | Nota limpia |
|---|---|---|---|---|---|---|
| `gpt-6-luna` | 510 | 508 (99.6 %) | 508 (99.6 %) | 461 (90.4 %) | 469 (92.0 %) | 473 (92.7 %) |
