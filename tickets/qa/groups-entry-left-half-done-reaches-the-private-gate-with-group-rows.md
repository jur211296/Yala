---
id: groups-entry-left-half-done-reaches-the-private-gate-with-group-rows
status: qa
priority: low
area: "modo-nube, onboarding, groups"
created: 2026-10-12
updated: 2026-10-16
source: "medición de alcanzabilidad de `private-gate-device-notice-has-no-forward-exit` (2026-10-12)"
---

# Quien entra con una cuenta de solo grupos y deja el alta a medias puede llegar a «Ya hay datos en este teléfono»

## El problema, en lenguaje de usuario

Entro en Yala con «Ya tengo una cuenta» y mi cuenta es de solo grupos. Empiezo el alta de grupos, la dejo a medias,
vuelvo atrás y elijo «Es mi primera vez → Tu cuenta en tu iCloud privado». Si para entonces Yala ya bajó mis grupos, la
puerta me dice «Ya hay datos en este teléfono» y solo me deja borrarlos o volver. Esos grupos son míos.

## Medido / inferido (2026-10-12)

- **Inferido del código, sin reproducir.** Es el único camino que se encontró hasta esa pantalla. Una sesión de solo
  grupos COMPLETADA no vuelve a la bienvenida (el alta deja `hasCompletedOnboarding = true`), que es lo que el QA de
  `device-qa-private-gate-device-corpus` dio por inalcanzable el 2026-09-16.
- La cadena: `onEnterGroupsOnly` deja viva la sesión de la nube y abre `.groupsGate` (`ContentView.swift`, ~3058-3096);
  abandonar la rama vuelve a `.groupsChooser` y de ahí a «Es mi primera vez»; el canal de Grupos arranca solo con la
  flag y la sesión (`GroupsSyncClient.swift:~422`), sin mirar el onboarding; con el mount neutro de una instalación nueva,
  `deviceCorpusGate` mide esas filas.
- «Activar Yala completo» no es la salida aquí: la activación da por hecha una sesión de solo grupos ya terminada (marca
  del neutro, onboarding completo). Decisión de Jürgen del 2026-10-12 en `private-gate-device-notice-has-no-forward-exit`:
  no se añadió.

## Qué hay que decidir (Jürgen)

- **A:** al abandonar el alta de grupos con la sesión viva, cerrarla (o no arrancar el canal sin onboarding), para que la
  puerta privada no vea filas de esa cuenta.
- **B:** en la puerta privada, no contar como «de otra persona» los grupos de la sesión de la nube viva.
- **C:** aceptarlo: población mínima y sin reproducir.

## Cómo se prueba

Device-QA: cuenta de solo grupos en un teléfono recién instalado; reproducir antes de decidir.

## Medido y arreglado (2026-10-16)

**Se reproduce (por traza, con citas en el PR).** `onEnterGroupsOnly` deja la sesión viva; ninguna salida atrás la cierra
ni purga Grupos; el canal arranca sin mirar el onboarding (`GroupsLoopRestartLogic.shouldStart`) y en este recorrido lo
arranca la vuelta a primer plano (inferido); con el montaje neutro de una instalación nueva la puerta cuenta todos los
`SplitGroup` y da «Ya hay datos». Peor que lo que decía el ticket: su «Borrar» usa el alcance del traspaso, que purga y
**sella** el dominio de Grupos de la propia persona y retira su sesión. El camino real no se puede conducir en el
simulador (bajo XCUITest el montaje nunca es neutro), así que la reproducción es un test de la cadena de decisiones con
las piezas de producción (`GroupsEntryKeptGroupsTests.sinMarca_laPuertaVeSusPropiosGruposComoAjenos`).

**Opción elegida: B**, con la pieza que ya existía. `onEnterGroupsOnly` escribe `LateNoticeKeptGroupsMark` atada a la
sesión que la persona acaba de abrir, **solo si la sesión la abrió ese mismo intento y en ese instante no hay ningún grupo
en el teléfono**. Todo lo que el canal
baje después es suyo, y los lectores de la marca (puerta privada, alerta de «Empezar de cero», borrado del teléfono, portal
del relanzamiento) dejan de tratarlo como de otra persona. La marca muere al completar el onboarding y la invalida otra
cuenta. A rompía la unión por invitación (necesita el canal antes del onboarding); C dejaba el borrado que sella los grupos
propios. Las dos condiciones evitan que una sesión de una persona anterior que sobrevivió a una reinstalación en el
llavero (el Welcome la reutiliza sin pedir nada) haga pasar sus grupos por los de quien entra. Residual heredado de la
marca: si esa sesión se va sin borrado (un 401, la cuenta borrada desde otro dispositivo), «sin sesión» la sigue dando
por buena.

## Device-QA (Jürgen, iPhone, cuenta de solo grupos)

1. Borra Yala del iPhone de pruebas e instala el build del PR.
2. «Ya tengo una cuenta» → entra con la cuenta de solo grupos. En la mini-app de Grupos, vuelve atrás sin terminar el alta.
3. Manda Yala a segundo plano unos segundos y vuelve (para que baje los grupos).
4. «Es mi primera vez» → «Tu cuenta en tu iCloud privado».
5. **Pasa si** NO sale «Ya hay datos en este teléfono» y sigues al onboarding; al terminarlo, tus grupos siguen en Grupos.

## Barrido de QA · 2026-10-16

Barrido de QA 2026-10-16 · se queda: §4 entrada real con una cuenta de solo grupos: bajo XCUITest el montaje nunca es neutro (medido en #522), así que el camino solo se conduce en un iPhone. La cadena de decisiones la fija un test (21 aserciones caen con el arreglo revertido). Prueba A · dzih de `docs/qa/tanda-qa-jurgen-2.1.md`.
