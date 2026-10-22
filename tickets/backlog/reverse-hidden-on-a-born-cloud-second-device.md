---
id: reverse-hidden-on-a-born-cloud-second-device
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-10
updated: 2026-10-08
source: "residual CONOCIDO y aceptado de `reverse-cutover-cerrado-para-cuentas-born-cloud` (2026-09-10), decisión D4"
---

# «Volver a iCloud» sigue oculta en el SEGUNDO teléfono de quien nació en la nube

## El problema, en lenguaje de usuario

Creé mi cuenta de Yala con Google en mi iPhone y ahí sí veo «Volver a iCloud». En mi iPad —donde entré
con la misma cuenta— la opción **no aparece**: dice «Ahora mismo no puedes volver a iCloud desde este
dispositivo». Es la misma cuenta y no hay ninguna diferencia que yo pueda ver.

## Por qué pasa, y por qué se dejó así a propósito

El guardarraíl `ReverseEligibility` exige un mapa de coordenadas CloudKit antes de dejar revertir,
porque sin él remontar el mirror puede **resucitar** lo que se borró durante la época nube: la zona
CloudKit sigue teniendo esos records. A una cuenta nacida en la nube no le aplica —nunca tuvo esa zona—,
y `reverse-cutover-cerrado-para-cuentas-born-cloud` le abrió la puerta.

La señal que la abre es **positiva y local**: `StorageModePersistence.isBornCloud`, que escribe el alta
born-cloud **en el dispositivo donde ocurre**. Un segundo dispositivo entra por *adopt* («Ya tengo
cuenta»), no por el alta, así que no tiene la marca y cae en el guardarraíl.

**Eso es deliberado y el motivo está medido.** La alternativa obvia era derivarlo de la ausencia del
`CloudMigrationMarker` («no hay marcador ⇒ no migró»), y una review adversarial demostró el 2026-09-10
que eso **falla ABIERTO**: el marcador falta también en un segundo dispositivo *adoptado* de una cuenta
**migrada** —su propio belt lo dice, «ausente = no bloquea (solo diagnóstico)»— y lo borra un botón del
panel DEBUG pensado para limpiar marcadores stale. En los dos casos, un migrado habría pasado por
born-cloud y se habría llevado por delante el guardarraíl justo para la población que protege.

⇒ Entre un falso negativo (alguien no ve un botón que podría usar) y un falso positivo (alguien puede
resucitar datos borrados), se eligió el primero. Este ticket es la deuda que eso deja.

## Qué haría falta para cerrarlo

La pregunta «¿esta cuenta nació en la nube?» es **de la cuenta**, no del dispositivo, así que la
respuesta autoritativa está en el backend: `profiles.migrated_at` (nulo ⇒ nació en la nube). Hoy no
viaja al cliente — `/account/exists` devuelve `{exists, kind}` y el `claim_account` no lo incluye en su
jsonb.

Dos vías, y la elección no es obvia:

- **A · Exponerlo.** Añadir `migrated` (o `migrated_at`) a la respuesta de `/account/exists` y guardarlo
  con el resto del descubrimiento de identidad que el paso 3 del rediseño ya cableó
  (`AccountKindService`). El gate pasaría a preguntar por la cuenta, no por el device. Es la respuesta
  correcta y toca backend + Worker + cliente.
- **B · El faro.** `CloudBeacon` (iCloud-KV) sobrevive a la reinstalación y ya viaja entre dispositivos
  del mismo Apple ID. Más barato, pero es una señal de encaminamiento y por decisión del 2026-09-06 «el
  faro solo encamina, nunca bloquea» — usarlo como autorización va contra esa decisión.

Ojo con una tercera que parece más simple y no lo es: montar el mirror para «mirar si hay zona» es
justamente la operación peligrosa que el guardarraíl evita.

## Criterios de aceptación

- [ ] Elegida la vía (A o B), con el motivo escrito.
- [ ] En un segundo dispositivo de una cuenta born-cloud, «Volver a iCloud» aparece.
- [ ] El migrado-sin-mapa **sigue excluido**: es la mitad que no se puede perder, y su test es el que
      lleva el peso (`reverseEligibility_mapOnlyRequiredWithoutBornCloudMark`).
- [ ] Mutante verificado en las dos direcciones.

## Relacionado

- `reverse-cutover-cerrado-para-cuentas-born-cloud` §Paso 0 D4 — la decisión y su medición.
- La otra mitad del mismo círculo, abierta desde antes y ahora la única población que ve
  `storage.revert.ineligible`: el **migrado que perdió el mapa**, brecha `N2` de
  `docs/modo-nube/MODO-NUBE-AUDITORIA-ESCENARIOS.md`.

## Medido en 2.1 (triage 2026-10-08)

- `ReverseEligibility.decide` (`MigrationWorkExecutor.swift:180-199`): `isBornCloud` ⇒ `.eligible`; si no, exige el mapa.
  La marca sigue siendo local (`CloudMigrationController.swift:1906`, `StorageModePersistence.isBornCloud()`).
- Desde el ticket hay un caso nuevo, `.mapUnreadable`, que no cambia el problema.

## Pregunta para Jürgen (triage 2026-10-08)

Cómo sabe el segundo dispositivo que la cuenta nació en la nube:

- **A** · Exponer `migrated` en `/account/exists` y guardarlo con el descubrimiento de identidad (backend + Worker + cliente).
- **B** · Usar el faro del iCloud-KV. Va contra la decisión del 2026-09-06 («el faro solo encamina, nunca bloquea»).
- **C** · Dejarlo: el primer dispositivo sí puede volver.

**Recomendación: A.** Es un dato de la cuenta y la única fuente fiable es el servidor. B convierte una señal de
encaminamiento en autorización justo en el guardarraíl que evita resucitar datos borrados. Con A, `medium`.

Triage 2026-10-08: abierto · medium → medium · ReverseEligibility.decide sigue abriendo la puerta solo con la marca local isBornCloud, y la cuenta no expone migrated_at; pendiente elegir vía A o B.
