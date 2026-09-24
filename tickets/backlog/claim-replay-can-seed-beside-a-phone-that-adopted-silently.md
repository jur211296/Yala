---
id: claim-replay-can-seed-beside-a-phone-that-adopted-silently
status: backlog
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

- [ ] Con B ya dentro de la cuenta (adopt terminado), el reintento de A bloquea aunque B no haya subido nada.
- [ ] El reintento de A tras una respuesta perdida, sin nadie más dentro, sigue terminando.
