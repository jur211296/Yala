# BORRADOR para Lola · textos nuevos del lote App Store 2.2

> **BORRADOR para Lola.** Los escribió Frank el 4-nov-2026 porque no existían (decisión de Jürgen vía su bot: los
> escribe Frank y Lola los revisa después). Español neutro latinoamericano, tuteo, según `docs/planning/BRAND-VOICE.md`.
> Los límites de caracteres son los de Apple y están medidos.

Fuentes de lo que se promete: la hoja de Novedades de la 2.2 de la app (`whatsNew.v22.*`) y las fichas de
`marketing/funcionalidades/` (voz y Yala IA son Pro; Grupos es gratis).

## Páginas de producto personalizadas

Cada página lleva su texto promocional (máx. 170), sus palabras clave y las mismas láminas de la ficha, en otro orden:
primero la de su función. Idiomas: es-MX (el principal de la ficha, en español neutro) y en-US (Jürgen, 4-nov).

**Las palabras clave salen de las de la ficha.** Apple solo deja asignar a una página personalizada palabras que ya
están en las palabras clave de la versión publicada; las que propuse primero («anotar por voz», «dividir gastos»…) las
rechazó. Para usarlas, Lola tendría que sumarlas antes a las palabras clave de la ficha.

### 1 · Voz

- **Nombre interno:** Voz · anota hablando
- **Texto promocional** (145): Dilo como te salga: «almuerzo 25 con la tarjeta». Yala entiende el monto, la cuenta y la categoría, y lo anota por ti. Sin teclear. Con Yala Pro.
- **Palabras clave (de la ficha):** presupuesto, dinero, recibos, tarjetas, cuentas · en-US: budget, money, tracker, spending, receipts, cash
- **en-US · promocional** (136): Say it your way: “lunch, 25, on my card.” Yala picks up the amount, account and category, and logs it for you. No typing. With Yala Pro.
- **Orden de láminas:** 03 voz · 01 Yala IA · 02 foto · 04 captura · 05 estadísticas · 07 presupuestos · 08 cuentas · 10 recordatorios · 06 Grupos · 09 multimoneda

### 2 · Grupos

- **Nombre interno:** Grupos · cuentas claras
- **Texto promocional** (157): Viajes, casa compartida o almuerzos de la oficina: anota quién pagó y Yala te dice quién le debe a quién. Las cuentas claras y la amistad intacta. Gratis.
- **Palabras clave (de la ficha):** dividir, cuentas, viaje, deudas, divisas · en-US: split, bills, travel, debt, currency
- **en-US · promocional** (130): Trips, shared apartments or office lunches: log who paid and Yala tells you who owes whom. Bills settled, friendship intact. Free.
- **Orden de láminas:** 06 Grupos · 09 multimoneda · 05 estadísticas · 01 Yala IA · 03 voz · 02 foto · 04 captura · 07 presupuestos · 08 cuentas · 10 recordatorios

### 3 · Yala IA

- **Nombre interno:** Yala IA · escríbele
- **Texto promocional** (147): Escríbele a Yala como a una amiga: «gasté 45 en un taxi y 120 en el súper». Lo anota y te responde cuánto gastaste o cuánto te queda. Con Yala Pro.
- **Palabras clave (de la ficha):** presupuesto, dinero, ahorro, flujo de caja, cuentas · en-US: budget, money, tracker, spending, savings
- **en-US · promocional** (142): Message Yala like a friend: “spent 45 on a cab and 120 on groceries.” It logs it and tells you how much you spent or have left. With Yala Pro.
- **Orden de láminas:** 01 Yala IA · 05 estadísticas · 07 presupuestos · 03 voz · 02 foto · 04 captura · 08 cuentas · 06 Grupos · 09 multimoneda · 10 recordatorios

## Evento dentro de la app · lanzamiento de la 2.2

- **Distintivo:** Gran actualización (Major Update)
- **Nombre** (14 de 30): Llegó Yala 2.2
- **Descripción corta** (41 de 50): Pregúntale a Siri y anota en menos toques
- **Descripción larga** (114 de 120): Tu tarjeta en dos monedas, junta. Siri te dice cuánto gastaste. Y anotas en menos toques, con deshacer al guardar.
- **en-US:** nombre «Yala 2.2 is here» (16) · corta «Ask Siri and log in fewer taps» (30) · larga «Your card in two currencies, together. Siri tells you what you spent. And you log in fewer taps, with undo on save.» (115)
- **Objetivo sugerido:** mantener informados a los usuarios actuales (y que lo vean los nuevos).
- **Fechas:** las pone Jürgen al publicar la 2.2. Apple deja promocionarlo hasta 14 días antes y que dure hasta 31.
- **Enlace profundo:** ninguno. La app solo abre enlaces universales de invitaciones de grupo; el evento abre la app.
- **Imágenes:** sin texto encima (Apple pinta el nombre y la descripción sobre la tarjeta).

## Variante B de la prueba A/B (Product Page Optimization)

Sin copy nuevo: las mismas 10 láminas, en otro orden. La ficha actual (A) abre con lo Pro; la B abre con lo gratis.

- **A (actual):** 01 Yala IA · 02 foto · 03 voz · 04 captura · 05 estadísticas · 06 Grupos · 07 presupuestos · 08 cuentas · 09 multimoneda · 10 recordatorios
- **B:** 06 Grupos · 05 estadísticas · 08 cuentas · 01 Yala IA · 03 voz · 02 foto · 04 captura · 07 presupuestos · 09 multimoneda · 10 recordatorios
- **Hipótesis:** para una descarga gratis convence más lo que no pide pagar. Se juega en las tres primeras, que son las que salen en la búsqueda.

## Capturas en en-GB y pt-PT (textos de las láminas)

Lola tiene textos de capturas en en-US y pt-BR. Los de en-GB y pt-PT los adapté yo de los suyos:
`ficha-app-store/textos/en-GB.js` (libras, recibo de Londres, fechas británicas) y `ficha-app-store/textos/pt-PT.js`
(português de Portugal, euros, «Viagem ao Algarve»). Los dos llevan la marca «BORRADOR para Lola» arriba.

Desde la 2.2 la lámina 06 del iPhone enseña la **lista** de Grupos; sus dos chips nuevos (`chipsLista`) son las filas del
viaje y también son borrador: «Ben owes you $110 / Ana owes you $80» (en-US y en-GB en libras), y los de pt-BR y pt-PT.
