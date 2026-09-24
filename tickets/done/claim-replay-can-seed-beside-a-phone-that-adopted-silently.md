---
id: claim-replay-can-seed-beside-a-phone-that-adopted-silently
status: done
updated: 2026-09-24
priority: medium
area: "modo-nube, sesiones"
created: 2026-09-24
source: "review adversarial de `claim-promotion-lost-response-blocks-the-retry` (2026-09-24), lente del servidor"
---

# Dos teléfonos pueden empezar desde cero en la misma cuenta de la nube a la vez

## El síntoma, en lenguaje de usuario

Activo la nube en el iPhone A y se corta la red justo al final. Mientras tanto entro con la misma cuenta en
el iPhone B («Ya tengo cuenta»): la cuenta está vacía, así que B arranca de cero y creo mis cuentas y
categorías. Vuelvo a A y toco «Reintentar»: termina y crea las suyas. Acabo con dos juegos de cuentas y
categorías en la misma nube. No se pierde nada; sobra.

## Por qué pasa (inferido del código, no reproducido)

- Desde `qa/cloud/g16_01_…` el reintento del teléfono que promocionó la cuenta recibe `created` si la cuenta
  no tiene ninguna escritura personal (sin fila en `sync_seq_counters`).
- B entra por el adopt, que no deja huella en el servidor: «Ya tengo cuenta» solo llama a `/account/exists`, y
  el adopt de un backend vacío no sube nada (guard anti-subida masiva, `MigrationWorkExecutor`). La primera
  huella de B es su primera subida.
- Si A reintenta antes de esa subida (B sin red, o los dos en el mismo minuto), el servidor no ve a B y deja
  sembrar a A. Antes de g16_01, A se bloqueaba siempre.

## Alcance

- Medir cuánto dura de verdad la ventana: ¿el onboarding de B sube algo antes de terminar?
- Opciones: que el adopt deje huella en el servidor (p. ej. un `claim` con `kind` que no promociona, o una
  marca de «adoptada por»), y que la rama de g16_01 la mire.

## Criterios de aceptación

- [x] Con B ya dentro de la cuenta (adopt terminado), el reintento de A bloquea aunque B no haya subido nada.
- [x] El reintento de A tras una respuesta perdida, sin nadie más dentro, sigue terminando.

## Resolución (2026-09-24)

**Solo servidor:** migración `qa/cloud/g16_02_claim_remembers_another_device_entered.sql`, aplicada en staging y en
producción. Sin deploy del Worker ni release de la app; el cliente solo cambia docblocks. Decisiones en el Paso 0 del
encargo (`encargos/lanzados/2026-09-24-claim-replay-can-seed-beside-a-phone-that-adopted-silently.md`).

**La ventana, medida:** el adopt de B **sí** llega al servidor antes de terminar —todo adopt pasa por
`performClaim` (`POST /account/claim`, `migration: true`, el 22 % de la barra)—, pero sobre la cuenta ya estable ese
claim caía en la rama final de `claim_account` y no escribía nada. El «inferido» del ticket era cierto en lo que
importa: el servidor no veía a B.

**El arreglo:** columna `profiles.personal_adopted_at`, que la rama final estampa cuando el claim lleva `migration` y
quien llama no es el líder; la rama g16_01 exige que sea nula. Así «con B dentro» deja huella en cuanto B pide
entrar, antes de que el adopt termine.

**Criterios, medidos:**
- Criterio 1: escenarios 14, 15, 17 y 18 de la sonda (adopt, adopt con el rol de PostgREST, «Soy nuevo → nube» y su
  adopt, alta born-cloud perdida + adopt) y el paso 8 del golden 28 contra staging: el reintento de A recibe
  `existing_stable`. Con la función VIVA los cuatro daban `created` (control negativo).
- Criterio 2: escenarios 1-3, 16 (otro teléfono choca desde «Activar Yala completo» y no entra), 19 (otro solo por
  Grupos) y 20 (el propio A pasa por el adopt), y el paso 5 del golden 28: el reintento sigue recibiendo `created`.
- Cinco mutantes, uno por término, todos muertos. Goldens contra staging: 34/35 (el 20 es el timeout conocido,
  `account-goldens-freeze-read-test-times-out`).

**La review (2 lentes) cambió dos cosas:** el sello exige `migration` (la primera versión sellaba cualquier claim
personal de otro dispositivo y bloqueaba a los dos teléfonos cuando el segundo solo chocaba desde «Activar Yala
completo»), y se retiró un `for update` que no cambiaba ningún desenlace posible.

**Residuales, escritos en la cabecera de la migración:** A reintenta ANTES de que B entre (la carrera de siempre entre
dos teléfonos); los segundos entre los dos claims de «Soy nuevo → nube»; y un «Migrar» de B rechazado en el claim, que
sella sin entrar. La salida que ve A cuando bloquea («Tu cuenta ya tiene finanzas personales» + «Cerrar») ya es de
`full-activation-cloud-adopt-when-account-already-complete`, con una nota nueva.

Device-QA: no hace falta. El contrato es del servidor y lo cubren la sonda (corre en cada aplicación) y los goldens.
