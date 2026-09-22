---
id: reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "review adversarial de `reverse-verify-network-bucket-hides-a-definitive-server-no` (2026-09-22), dos lentes independientes lo cazaron por separado"
---

# Un fallo de UNA vez cobra las horas que otro motivo llevaba esperando, y saca de la vuelta sin un solo reintento

## El problema, en lenguaje de usuario

Llevo tres horas volviendo a iCloud sin cobertura. La app espera, que es lo correcto: la red vuelve sola. Vuelve el
wifi, y justo en esa pasada algo del teléfono falla una vez —una lectura de la base local que no sale—. En vez de
reintentar, la app abandona la vuelta **en ese mismo instante** y me manda de vuelta al principio.

Si ese mismo fallo me hubiera pasado a los dos minutos de empezar, no habría pasado nada: habría esperado y
reintentado. Lo que me saca no es el fallo, es haber esperado mucho antes por otra cosa.

## Por qué pasa (medido el 2026-09-22)

`MigrationRunner.observeReversePreMountStall` mide **dos cosas de procedencias distintas** y las junta:

- `stalled = observedAt - lastProgressAt` es el tiempo parado **de la FASE**, y el sello solo se reinicia al CAMBIAR
  de fase (`MigrationRunner.swift`, la rama `sealedPhase != phase`). Una espera de 3 h por red no lo mueve.
- `cause = blocker?.stallCause ?? .unknown` es de **ESTA observación**, la última.

`MigrationStateMachine` aplica el presupuesto de la causa actual al tiempo acumulado (`guard stalled >= budget`). Con
3 h acumuladas y una causa que elige el techo corto, `10 800 >= 900` sale a la primera. No hay histéresis, ni segunda
observación, ni reintento.

**Existe desde el 2026-09-21** (`reverse-before-mount-has-no-way-to-abandon-the-return`), cuando el 403 estrenó el
techo corto, y ahí molestaba menos: un 403 es una respuesta del servidor, repetible, y el argumento «esperar no lo
arregla» se sostiene. **Lo que lo vuelve urgente es el 2026-09-22**
(`reverse-verify-network-bucket-hides-a-definitive-server-no`): desde ese día el techo corto también lo elige
`.localFailure`, que lo decide **una** excepción de un `fetch` de SwiftData — y eso sí puede ser pasajero.

## Qué habría que decidir antes de hacerlo

1. **¿Histéresis o reloj por causa?** Exigir DOS observaciones seguidas con causa definitiva antes de acortar es lo
   barato; llevar un reloj por causa es lo correcto y toca el journal (schema nuevo).
2. **¿Aplica a los cinco motivos o solo a los que no son del servidor?** El 403 repetido no necesita histéresis; el
   `fetch` local sí. Distinguirlos deja el mecanismo con dos reglas.
3. **El schema.** `reversePreMountProgressAt` es un solo campo; un reloj por causa son cinco, o uno más la causa
   sellada.

## Criterios de aceptación

- [ ] Un `.localFailure` aislado tras una espera larga por otra causa **reintenta al menos una vez** antes de sacar
      a la persona de la vuelta.
- [ ] Un 403 repetido sigue saliendo a los 900 s de parada REAL con esa causa.
- [ ] La red pura conserva su techo largo, y el cambio de fase sigue reiniciando el reloj.
- [ ] Test que siembre una espera larga con una causa y observe con otra: hoy sale al instante y debe holdear.

## Relacionado

- `reverse-verify-network-bucket-hides-a-definitive-server-no` — el que metió `.localFailure` en el techo corto.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el que creó el techo y su reloj por fase.
- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el hermano: el MISMO fetch, leído con signos opuestos.
