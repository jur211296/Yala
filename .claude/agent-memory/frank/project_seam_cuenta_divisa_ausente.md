---
name: seam-cuenta-divisa-ausente
description: PR #114 — el seam `-uitest-seed-foreign-account <ISO>` que desbloquea la familia FX en simulador; qué tickets salen enteros, cuáles a medias y qué seam falta para los dos que siguen parados.
metadata:
  type: project
---

**Desde el 2026-09-09 se puede sembrar una cuenta en una divisa fuera de la fila de tasas sin tocar
la UI** (PR #114, `-uitest-seed-foreign-account <ISO>`, aditivo al perfil y apagado por defecto).

**Why:** era la palanca con mejor relación coste/desbloqueo del board — siete tickets de FX
esperaban ese único estado de partida y ninguno necesitaba teléfono. El camino por UI está cerrado
de verdad y conviene no volver a intentarlo: el selector de Moneda es un `NavigationLink` y no
responde a los taps sintéticos (medido con cuatro técnicas, y el `NavigationLink` hermano tampoco
abre ⇒ va con el patrón, no es un bug de la app).

**How to apply:**

- **Lo que el seam da, y lo que no.** Da una divisa ausente de la fila ⇒ `.staticFallback` ⇒ filas
  marcadas provisionales por el camino de producción. **No** da: dos patas con coberturas distintas
  (lo pide `bridge-de-grupos-pierde-la-marca-de-sus-patas`) ni una fila envenenada con
  `exchangeRate = 1.0` (lo pide `chat-rows-sealed-before-the-fix-have-no-repair-path`). Esos dos
  siguen parados y **lo que les falta es seed, no teléfono**: son los siguientes candidatos baratos.
- **La salida 3 quedó sin hacer a propósito** (`-uitest-preferred-currency <ISO>`): el AC no la pedía
  y ejercita `CurrencyChangeService`, otro objeto. La necesita el AC nº3 de
  `fx-partial-rate-rows-silent-1to1`; está anotada allí.
- **Al verificar con este seam, acota el período.** Con «Todo el tiempo» NO marca (0,36 %, bajo el
  umbral del 5 %) y eso es correcto, no un fallo. Está escrito en el ticket porque es justo el falso
  negativo que alguien va a reportar.
- Tres tickets siguen sin salir del simulador por causas ajenas al montaje: dos piden **red** y uno
  el **LLM real**.

**Lo que aprendí del corpus, y que vale para cualquier fixture futuro de FX:** el seed normal
escribe `exchangeRate` a mano y deja `isExchangeRateProvisional` en su default `false`, así que
**cualquier aserción sobre ese flag sobre el corpus sembrado es vacua por construcción**. Un fixture
que quiera probar la marca tiene que pasar por `recalculatePreferredCurrency`, o solo prueba que sé
escribir constantes. Ver [[la-asercion-que-no-puede-fallar]].

**Y una cifra que corregí midiendo, porque la de partida era falsa:** el ticket decía cuatro tickets
bloqueados y el `docs/ESTADO.md` decía cinco. **Son siete** los que esperan el montaje, y de los
cuatro que nombraba, dos pedían además otra cosa y uno no declaraba bloqueo alguno.
Ver [[la-premisa-del-encargo-tambien-se-mide]].

## 2026-09-09 (tarde) — la familia recorrida entera, PR #115

**5 PASS con evidencia en pantalla** (`fx-presentation-still-shows-1to1`,
`fx-approximate-mark-missing-on-secondary-surfaces`, `chat-rows-sealed-...`,
`bridge-de-grupos-...`, `approximate-mark-ors-over-whole-period`) y **2 parciales por causa
propia**: `fx-manual-writes-seal-approximate-as-final` (el flag no tiene superficie por fila: no hay
nada que mirar) y `fx-partial-rate-rows-silent-1to1` (red + el seam `-uitest-preferred-currency`,
que sigue sin existir).

**Los dos que «necesitaban más seed» ya lo tienen**: `-uitest-seed-chat-sealed-rate <ISO>` y
`-uitest-seed-group-bridge-fx <ISO>`. Los dos idempotentes, los dos con suite propia y mutantes.

**Lo que hay que saber para volver a correr esto:**

- **El veredicto del barrido legacy necesita DOS arranques**, y sale gratis del orden que ya existe:
  el barrido es el paso 2 del bootstrap y el seed el 19, así que el arranque que siembra deja la
  fila envenenada y el siguiente la cura.
- **En el segundo arranque NO pases `-uitest-seed <perfil>`**: duplica el corpus entero
  (2.326 → 4.651). Ticket propio: `uitest-seed-reseeds-the-corpus-without-reset`.
- **El barrido depende del gate de quiescencia de CloudKit** y puede no correr en un arranque
  concreto. Si el log no dice `repair sweep …`, relanza; no es un FAIL.
- **Con «Todo el tiempo» el fixture no marca** (0,36 % < 5 %). Acota el período o leerás un falso
  negativo — y ese par es, a la vez, la demostración en pantalla del umbral de
  `approximate-mark-ors-over-whole-period`.

**Quedan 4 tickets**, tres de ellos superficies que las tablas de sus padres no nombraban:
`live-anchor-breakdown-doubles-the-approximate-glyph` (el «≈» del copy y el de la marca se suman y
salen «≈ ≈»), `pie-header-total-unmarked`, `weekday-bar-daily-average-unmarked` y el del seed.

**Y lo que sigue sin poder verificarse aquí**: el widget de inicio (simulable, no cupo), el
asistente (LLM real), la red y el cambio de divisa preferida.
