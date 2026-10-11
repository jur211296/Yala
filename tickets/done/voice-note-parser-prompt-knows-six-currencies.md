---
id: voice-note-parser-prompt-knows-six-currencies
status: qa
priority: medium
area: voice, ai, currency
created: 2026-10-07
updated: 2026-10-09
source: banco de text.parse (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-chat-y-nota.md)
---

# La lectura de una nota de voz solo conoce seis divisas y no sabe cuál es la del usuario

## Qué le pasa al usuario

Dicta «30 francos» en Suiza y el borrador sale en EUR; dicta «5000 pesos» en Argentina y sale en MXN o PEN.

## Lo medido (2026-10-07)

- El prompt de `TranscriptionParserService.parseMultiple` enseña seis divisas y no recibe la divisa principal del
  usuario. Es el mismo arreglo que el paso 6 bis hizo en la foto (`VisionCurrencyContext`): pasar la divisa principal y
  las de las cuentas, y enseñar los nombres de las divisas de los 10 idiomas.
- También falla la jerga: «18 lucas» en Lima se lee como 18 000 (una luca es un sol).
- Y los decimales coloquiales en letra: «28 euros e 30» lo parte en dos movimientos (banco de voz,
  `docs/ai-voice-bench-2026-10.md`). La transcripción ya pide cifras (prompt de la fila `voice.transcribe`), pero el atajo
  de texto y el chat pueden traer el importe así. Una nota japonesa de 860 円 sale a veces en soles.

## Hecho cuando

- Con divisa principal ARS, «5000 pesos» sale ARS; con CHF, «30 francos» sale CHF.
- `npm run bench -- --task text.parse` igual o mejor que el 97,7 % del 2026-10-07.

## Hecho (2026-10-09)

- **Divisas del usuario en el prompt** (`ParserCurrencyContext`, molde de `VisionCurrencyContext`): la divisa principal y
  las de las cuentas activas viajan al parser desde la hoja de voz, el chat (rama «registrar») y el atajo de Siri (la
  caché del App Group gana `accountCurrencies`, opcional). Los nombres que comparten varias divisas (pesos, dólares,
  francos, coronas, libras, rupias, riyales, dírhams, en los 10 idiomas) se resuelven en Swift —principal de la familia →
  la única cuenta de la familia → el defecto— y el prompt recibe el código ya decidido. Además: nombres de una sola
  divisa en los 10 idiomas, jerga («lucas» según la divisa principal, «pavos», 万, «k») y decimales en letra («28 euros e
  30» → 28,30, un solo movimiento).
- **Banco `text.parse`**, misma fila (`gpt-6-luna`, `low`): **100 % (102/102)** en 51 casos × 2, con 7 casos nuevos
  (ARS, USD con cuenta ARS, CHF ×2, CAD, decimales en letra, 860 円 con principal PEN). Con el prompt viejo los 7 nuevos
  daban 50 % (control rojo). Informe: `gateway/bench/results/2026-10-09/REPORT-text-parse.md`. Coste 0,22 USD por 1 000.
- Tests: `YalaTests/TranscriptionParserCurrencyTests` (resolución, prompt, ejemplos, esquema) y
  `ProxyTaskHeaderTests#textParse` (la petición real lleva la divisa en el prompt).

## Device-QA (Jürgen)

Montaje: build de `Yala Dev` o TestFlight con este cambio, Pro activo y una cuenta en la divisa que toque.

1. Ajustes → divisa principal **ARS**, con al menos una cuenta en ARS. Botón de voz → di «gasté 5000 pesos en el súper».
   Debe salir 5000 **ARS** (no MXN ni PEN).
2. Divisa principal **CHF** y una cuenta en CHF. Di «almuerzo 30 francos». Debe salir 30 **CHF**.
3. Desde el chat de Yala IA, escribe «registra 28 euros e 30 en el súper»: un solo borrador de 28,30 EUR.
4. (Opcional) Siri: «Oye Siri, anota en Yala 5000 pesos de nafta» con principal USD y una cuenta ARS: 5000 ARS.
