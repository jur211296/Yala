# chat.answer — banco del 2026-10-07

Precios comprobados el 2026-10-07. Generado por `npm run bench -- --report`.

| Candidato | Proveedor | Esfuerzo | Detalle | Lado mayor | Casos | Acierto | JSON válido | Errores | p50 ms | p95 ms | Tokens entrada (media) | Tokens salida (media) | Coste medio (USD) | Coste por 1 000 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `gpt-6-luna` | openai | none | - | - | 66 | 100.0 % | 100 % | 0 | 1463 | 2076 | 6340 | 37 | 0.000203 | 0.203 |
| `gpt-6-luna` | openai | low | - | - | 66 | 100.0 % | 100 % | 0 | 1437 | 2192 | 6340 | 47 | 0.000208 | 0.208 |
| `gpt-oss-120b` | workersai | low | - | - | 66 | 100.0 % | 100 % | 0 | 2126 | 4959 | 6398 | 114 | 0.002325 | 2.325 |
| `gpt-4.1-mini` | openai | - | - | - | 66 | 98.5 % | 100 % | 0 | 1116 | 1561 | 6341 | 52 | 0.001455 | 1.455 |
| `claude-haiku-5-5` | anthropic | low | - | - | 66 | 90.9 % | 100 % | 0 | 2104 | 3667 | 9957 | 246 | 0.001119 | 1.119 |
| `claude-haiku-5-5:none` | anthropic | none | - | - | 66 | 81.8 % | 100 % | 0 | 1318 | 1643 | 9956 | 88 | 0.001040 | 1.040 |
