---
id: groups-entry-left-half-done-reaches-the-private-gate-with-group-rows
status: backlog
priority: low
area: "modo-nube, onboarding, groups"
created: 2026-10-12
updated: 2026-10-12
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
