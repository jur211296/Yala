---
id: nightly-ui-suite-hits-its-110-minute-cap-every-night
status: backlog
priority: medium
area: testing
created: 2026-10-07
updated: 2026-10-07
source: hallazgo de advisory-ui-tests-fail-every-retry (run 37485294893)
---

# La suite UI de la QA programada se corta por tiempo todas las noches y no llega a correr un cuarto de las suites

## Qué se midió el 2026-10-07

El paso `UI tests (YalaUITests) — solo nocturna · advisory` de `qa.yml` lleva `timeout-minutes: 110`. En las seis
últimas QA programadas el paso dura lo mismo que el tope:

| Run | Inicio | Fin | Duración |
|---|---|---|---|
| 37485294893 (6-oct) | 15:46:35 | 17:36:48 | 110 min |
| 37346159546 (5-oct) | 17:37:57 | 19:28:10 | 110 min |
| 37207917034 (4-oct) | 14:26:34 | 16:16:48 | 110 min |
| 37125969899 (3-oct) | 13:51:46 | 15:40:27 | 109 min |
| 37021905092 (2-oct) | 15:24:26 | 17:14:46 | 110 min |
| 36884315519 (1-oct) | 15:49:41 | 17:31:55 | 102 min |

En el del 6-oct el log termina con `The action 'UI tests …' has timed out after 110 minutes`, y solo arrancaron
**62 de las 84 suites** de `YalaUITests/Flows/`. `TransactionsCrudUITests`, entre otras, no aparece ni una vez.
Como el paso es `continue-on-error`, el run sale verde.

⇒ La QA programada no prueba la suite entera, y lo que se queda fuera depende del orden alfabético: las suites
del final no corren nunca.

## Qué lo agrava

`-retry-tests-on-failure` repite cada caso rojo hasta 3 veces. Los tres persistentes de
`advisory-ui-tests-fail-every-retry` gastaban ~6 min por noche entre los tres. Arreglarlos ayuda, pero no
alcanza para entrar en 110 min.

## Qué haría falta (no decidido)

Medir cuánto dura la suite entera en el runner y elegir: subir el tope, partir la suite en dos pasos o dos
noches, o quitar el reintento de los casos que tardan. Cualquiera toca `qa.yml`, que el encargo que lo encontró
tenía vetado.
