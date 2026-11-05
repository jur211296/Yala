---
name: el-log-que-lee-el-estado-cura-el-bug
description: Al instrumentar un bug de observación de SwiftUI, un log que LEE el estado en el body añade la dependencia que faltaba y el fallo desaparece; loguea sin leer.
metadata:
  type: feedback
---

Al cazar un `onChange` que deja de disparar, el log no puede leer el estado observado dentro del `body`: esa lectura
registra la dependencia que se estaba perdiendo y el fallo se esfuma (2026-11-05, filtro del Panel: 3 corridas
seguidas en verde con `NSLog(..., sessionState.selectedAccountIDs.count)` en el body; con `NSLog("body")` a secas cayó a
la primera).

**Why:** pasé una hora creyendo que el bug era raro cuando el instrumento lo curaba.

**How to apply:** en el body, log sin argumentos del estado; el valor, en el `didSet` del modelo (fuera de la vista).
Un conductor XCUITest con N rondas y la cifra leída por accesibilidad da la tasa base antes de arreglar
([[instrumentar-gana-a-razonar]]).
