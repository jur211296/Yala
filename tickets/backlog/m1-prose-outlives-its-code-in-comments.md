---
id: m1-prose-outlives-its-code-in-comments
status: backlog
priority: medium
area: "documentación en código, sesiones"
created: 2026-09-13
source: "medido al cerrar el PR-B del paso 12 (`shell-derives-from-two-session-axes`)"
---

# La sesión de visita ya no existe, pero 94 comentarios siguen hablando de ella

## Qué se midió

El PR-B del paso 12 retiró la sesión de visita (M1) y su criterio de aceptación era **grep cero de los
SÍMBOLOS retirados** en `Yala/` y `YalaWidgets/`, comentarios y docblocks incluidos. Eso se cumple: los
símbolos dan cero.

Lo que queda es otra cosa: la **prosa**. Al barrer el árbol por las palabras del mecanismo —«sesión
secundaria», «la visita», «la invitada»— salen **94 líneas en 30 ficheros** (medido el 2026-09-13 con
`git grep`, descontando los sentidos ajenos: divisa secundaria, acción secundaria, jerarquía
secundaria). Los mayores: `AppBootstrapper` (8), `SIWATokenRevocation` (6), `ContentView` (6), `L10n`
(4), `WelcomeCloudSignInView` (4), `PreferenceSyncService` (4).

## Por qué importa, y por qué no es urgente

No son todas iguales, y por eso hace falta leerlas una a una:

- **Las que MIENTEN sobre el código de hoy** son el problema real: un docblock que justifica un guard
  citando un escenario que ya no puede ocurrir invita a retirar el guard, o a razonar sobre él con el
  modelo equivocado. El PR-B cerró **cinco** de esta clase (el párrafo de la «frontera M1» dentro de
  `armGroupsOnlyNeutralMount`, el `MARK` vacío del panel DEBUG, la cabecera del remote-config que
  nombraba un percent que el propio PR borra, el bloque huérfano del seam de uitest y las dos
  justificaciones de `L10n`). Las cerró porque el PR las había falsificado él mismo: era su
  responsabilidad, no una limpieza.
- **Las que son HISTORIA bien escrita** no se tocan: explican por qué algo es como es y ya se leen en
  pasado (`OwnerKeyValueStore`, `L10n.overrideLanguage`, los cuatro párrafos de
  `.claude/rules/swiftdata-cloudkit.md`).

⇒ el trabajo no es un `sed`: es decidir, línea a línea, en cuál de los dos montones cae. Y el de la
izquierda hay que reescribirlo conservando la lección, que es la decisión de Jürgen del 2026-09-09.

## Criterio de aceptación

- [ ] Las 94 líneas revisadas una a una. Cada una queda: reescrita en pasado (si la lección vale),
      borrada (si no), o movida a `.claude/rules/` (si vale para más de un fichero).
- [ ] Ningún comentario justifica un guard, un orden o una fachada **vivos** con un escenario que hoy
      es imposible sin decir que lo es.
