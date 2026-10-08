---
id: welcome-beacon-origin-contradicts-not-found-copy
status: backlog
priority: low
area: "onboarding, modo-nube, copy"
created: 2026-09-10
updated: 2026-10-08
source: "review adversarial (lente de producto) de `beacon-routes-only-never-blocks`, 2026-09-10"
---

# Dos pantallas seguidas dicen lo contrario sobre el mismo Apple ID

## El síntoma, en lenguaje de usuario

- **Tras el fresh start, con un faro de Google.** «Es mi primera vez» → «Este Apple ID ya tiene una cuenta
  de Yala creada con Google» → firmo con Google → «No encontramos una cuenta · Este Apple ID aún no tiene
  una cuenta Yala en la nube». Se repite en cada reinstalación hasta que se crea una cuenta, porque con
  Google el faro huérfano no se puede limpiar (no hay prueba de que sea la misma cuenta de Google). Con un
  faro de Apple pasa una sola vez: esa firma sí prueba el huérfano y el faro se apaga.
- **Apple ID compartido; la cuenta de Yala de la madre es de Google.** El padre lee «…creada con Google»
  (cierto), firma con SU Google, la regla 4 del mismatch da «mismo método» y sale «Este Apple ID aún no
  tiene una cuenta Yala en la nube»: falso —la tiene, la de la madre— y le habla de «Apple ID» a quien
  firmó con Google.
- **El mismatch en ese mismo Apple ID compartido.** El cuerpo dice «Tu cuenta de Yala se creó con Apple»
  y le atribuye al padre la cuenta de la madre; el título «Esa cuenta usa otro método» apunta a la cuenta
  de Google que acaba de usar, que no tiene cuenta de Yala.

## Por qué no se tocó en `beacon-routes-only-never-blocks`

La línea del origen es la frase LITERAL de la decisión de Jürgen del 2026-09-09 («Este Apple ID ya tiene
una cuenta de Yala creada con Apple»). Cambiarle el tiempo verbal o el sujeto es una decisión de copy, y
es suya. `welcome.cloud.notFoundBody` («Este Apple ID aún no tiene…») es anterior: lo escribió el paso 3
para los dos métodos.

## Propuesta para decidir (la de la lente)

- Origen en pasado, que es cierto aunque la cuenta esté borrada: «Con este Apple ID ya se creó una cuenta
  de Yala con Google».
- Un `notFoundBody` que no diga «Apple ID» cuando se firmó con Google.
- Mismatch con el sujeto del faro y no de la persona: «La cuenta de Yala de este Apple ID se creó con
  Apple».

## Pregunta para Jürgen (triage 2026-10-08)

La frase del origen es literal tuya (2026-09-09), así que el cambio no se hace sin ti.

- **A.** La propuesta de la lente, entera:
  - el origen, en pasado: «Con este Apple ID ya se creó una cuenta de Yala con Google»;
  - un `notFoundBody` que no nombra el «Apple ID» a quien firmó con Google;
  - el mismatch, con el faro de sujeto: «La cuenta de Yala de este Apple ID se creó con Apple».
- **B.** Solo el `notFoundBody` por método. Es el texto que hoy es falso, y tu frase de origen se queda como está.
- **C.** Dejarlo como está.

**Recomendación: A.** Las tres frases se contradicen entre sí, y arreglar solo una deja las otras dos chocando. Con A la prioridad es `low`: es copy en 16 locales y sin riesgo.

## Medido en 2.1 (triage 2026-10-08)

- Los textos siguen iguales en `es-419.lproj/Localizable.strings`: `welcome.cloud.notFoundBody` (`:4790`), `providerMismatchTitle` (`:4955`), `providerMismatchBody` (`:4958`) y `beaconOrigin` (`:4964`).
- El último commit que los toca es `db1c4b72a` (2026-09-10), el mismo PR que abrió el ticket.
- Por qué low: el texto confunde, pero los dos caminos tienen salida y no se pierde nada.

Triage 2026-10-08: abierto · medium → low · Los cuatro textos implicados siguen como estaban, y cambiarlos es una decisión de copy de Jürgen
