---
name: una-lectura-del-body-basta-para-todo-el-body
description: En SwiftUI la dependencia es del body entero: quitar una de dos lecturas de un @State no mata el mutante si la otra sigue en el mismo body
metadata:
  type: feedback
---

Para mutar un repintado por dependencia (`let _ = sessionRevision`), quita **todas** las lecturas que caen en el mismo
`body`, no solo la del sitio que te interesa. El 2026-10-23 (card nve0) leía `sessionRevision` en el estado vacío y en el
aviso del attest, los dos dentro del `body` de `GroupsContainerView`: quitar solo la primera habría dejado verde el XCUITest
con el bug dentro, porque cualquier lectura del body re-evalúa el body entero.

**Why:** el mutante parecía apuntar a la línea responsable y no lo era; la dependencia la registra la vista, no la expresión.

**How to apply:** antes de lanzar el mutante, `grep` del `@State` en todo el fichero de la vista y retira todas las
lecturas de ese body. Relacionado: [[el-mutante-tiene-que-caer-por-su-caso]].
