# text.parse — banco del 2026-10-07

Precios comprobados el 2026-10-07. Generado por `npm run bench -- --report`.

| Candidato | Proveedor | Esfuerzo | Detalle | Lado mayor | Casos | Acierto | JSON válido | Errores | p50 ms | p95 ms | Tokens entrada (media) | Tokens salida (media) | Coste medio (USD) | Coste por 1 000 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `grok-4.20-non-reasoning` | xai | - | - | - | 88 | 100.0 % | 100 % | 0 | 2628 | 6152 | 2141 | 170 | 0.003100 | 3.100 |
| `gpt-6-luna` | openai | low | - | - | 88 | 97.7 % | 100 % | 0 | 2549 | 3685 | 1955 | 203 | 0.000146 | 0.146 |
| `gpt-5.6-luna` | openai | low | - | - | 88 | 97.7 % | 100 % | 0 | 2472 | 3255 | 1955 | 159 | 0.000284 | 0.284 |
| `claude-haiku-5-5:none` | anthropic | none | - | - | 88 | 95.5 % | 100 % | 0 | 1279 | 1545 | 3047 | 175 | 0.000392 | 0.392 |
| `gemini-3.1-flash-lite` | gemini | - | - | - | 88 | 93.2 % | 100 % | 0 | 1177 | 1566 | 2083 | 199 | 0.000819 | 0.819 |
| `gpt-4.1-mini` | openai | - | - | - | 88 | 90.9 % | 100 % | 0 | 1836 | 3161 | 1956 | 167 | 0.000589 | 0.589 |
