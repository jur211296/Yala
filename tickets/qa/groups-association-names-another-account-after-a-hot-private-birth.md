---
id: groups-association-names-another-account-after-a-hot-private-birth
status: qa
priority: high
area: "grupos, nube, asociación"
created: 2026-10-19
updated: 2026-10-19
qa-status: needs-testing
source: tarjeta del tablero `tablero-donde-viven-tus-datos-dice-que-tus-grupo-cq2i` (QA guiado del 2026-10-19, A · C1)
---

# «Dónde viven tus datos» decía que tus grupos usan una cuenta vieja y bloqueaba «Activar la nube»

## Qué le pasaba al usuario

Instalación limpia › «Ya tengo una cuenta» con una cuenta solo-grupos (Y) › alta de Grupos a medias › «Es mi primera
vez › Tu cuenta en tu iCloud privado» › «Traer mis datos». Con la sesión de grupos de Y viva y su grupo a la vista,
«Dónde viven tus datos › Grupos» decía «Tus grupos usan X» —una cuenta de otra prueba, ya borrada— y «Activar la nube»
salía deshabilitado con «Tus grupos usan otra cuenta…». La salida que proponía («entra con esa cuenta») era imposible.

## Causa (medida en código)

- `GroupsAccountAssociation.read()` cae al iCloud-KV del Apple ID cuando no hay registro local, y ese KV recordaba la
  asociación de X (15-oct, mismo Apple ID).
- El único escritor que asocia la sesión viva es `GroupsAssociationRegistrar`, y **solo corre en el arranque**. En
  este camino la sesión privada nace con la app abierta (`welcomeRestoreCover` `.directToApp`, o el fin del onboarding),
  y en el arranque de ese proceso aún no había sesión privada (`deviceState == .fresh`). Hasta el arranque siguiente no
  se escribía nada y `read()` devolvía X. La puerta de «Activar la nube» (`isAssociated(sub:)`) bloqueaba con
  `.anotherGroupsAccountAssociated`.
- La hipótesis de la card (el camino que conserva la sesión de grupos no reescribe la asociación) era correcta; el
  matiz es que nadie la escribía, no que la escribiera mal.

## Arreglo

`GroupsAssociationRegistrar.syncFromLiveSessionNow()`, con las mismas guardas que el arranque, en los tres nacimientos
de la sesión privada en caliente: restaurar desde el Welcome, terminar el onboarding personal y «Activar Yala
completo». El adopt no la llama: su sesión no es de Grupos (`AdoptSessionOwnership`).

Tests: `YalaTests/GroupsAccountAssociationTests#GroupsAssociationPrivateBirthTests` (la sesión viva gana al KV y la
puerta deja pasar; controles: sin sesión de Grupos viva se respeta el KV —el segundo teléfono del Apple ID— y antes del
nacimiento no se asocia nada; cableado de los tres nacimientos detrás del eje).

## Lo que no cubre

- Una sesión de Grupos viva que **no** sea de la persona (heredada de una reinstalación sin sello) se asocia igual que
  ya hacía el arranque: el registrador no lo distingue, ni antes ni ahora.
- Sin seam de XCUITest para sembrar la asociación del KV con otra cuenta (`uitest-seam-for-a-seeded-groups-association`,
  backlog), así que no hay captura de antes y después en el simulador.

## Device-QA (Jürgen, iPhone de QA, Yala Dev contra staging)

Montaje: el iCloud-KV del Apple ID con una asociación de Grupos de OTRA cuenta (lo deja la prueba A · C1 del 19-oct;
**no** toques «Desasociar»).

1. Borra Yala Dev e instálala de nuevo.
2. «Ya tengo una cuenta» › Google con la cuenta solo-grupos (admin@yala-app.pe). Deja el alta de Grupos a medias.
3. Vuelve y elige «Es mi primera vez › Tu cuenta en tu iCloud privado» › «Traer mis datos».
4. **Sin cerrar Yala**, Ajustes › «Dónde viven tus datos».
5. **Esperado:** la sección Grupos nombra admin@yala-app.pe y «Activar la nube» no sale bloqueado por otra cuenta.
