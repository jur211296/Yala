# text.parse — divisas del usuario y JSON estricto (2026-10-09)

Tickets `voice-note-parser-prompt-knows-six-currencies` y `voice-parser-sends-no-json-mode`. Mismo modelo y esfuerzo que
la fila (`openai:gpt-6-luna`, `low`); cambian el prompt (divisa principal y cuentas, nombres de divisa resueltos, jerga,
decimales en letra, una sola regla de fecha, ejemplos sin subcategorías inventadas) y el formato de la fila (JSON
estricto con `TEXT_PARSE_SCHEMA`).

| Corrida | Prompt | Formato | Casos × reps | Acierto | JSON que la app no lee | Coste |
|---|---|---|---|---|---|---|
| 2026-10-07 (referencia) | viejo | texto | 44 × 2 | 97,7 % (86/88) | 0 | 0,013 USD |
| `2026-10-09-antes` (control rojo) | viejo | texto | 7 nuevos × 2 | 50,0 % (7/14) | 0 | 0,002 USD |
| **2026-10-09** | nuevo | **estricto** | 51 × 2 | **100 % (102/102)** | 0 | 0,019 USD |

Lo que fallaba con el prompt viejo en los casos nuevos (`2026-10-09-antes/text.parse.jsonl`):

- `es-US-01` (principal USD, una cuenta ARS, «5000 pesos»): USD ×2.
- `en-CA-01` (principal CAD, «25 dollars»): USD ×2.
- `ja-04` (principal PEN, «ローソンで860円»): PEN ×2 — el «860 円 sale en soles» del ticket.
- `es-ES-04` (principal EUR, «30 francos»): EUR ×1.

Y lo que fallaba el 2026-10-07 ya pasa: `es-PE-03` («18 lucas» en Lima) y `ja-01` (la fecha de «昨日» en el segundo
importe). Latencia, en serie (`2026-10-09-latencia`, 20 casos, concurrencia 1): **p50 3,2 s y p95 7,2 s**, contra el corte de
20 s del cliente (el 2026-10-07, p95 3,7 s con el prompt viejo, de 1 950 tokens de entrada; el nuevo tiene ~3 250). Medida
con un build de Xcode corriendo a la vez: tómala como techo. En paralelo (concurrencia 4) sale p95 13,4 s, inflada.
Coste: 0,22 USD por 1 000 lecturas (antes 0,146). Tope de gasto: 0,50 USD por corrida; la más cara costó 0,019.
