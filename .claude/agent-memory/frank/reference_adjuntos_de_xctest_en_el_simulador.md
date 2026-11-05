---
name: reference-adjuntos-de-xctest-en-el-simulador
description: Las corridas de XCUITest dejan GB de adjuntos en tmp/Attachments del daemon de tests DENTRO del simulador; disk-report solo ve el device engordar
metadata:
  type: reference
---

`~/Library/Developer/CoreSimulator/Devices/<udid>/data/Containers/Data/InternalDaemon/<uuid>/tmp/Attachments` acumula vídeos y capturas de las corridas de XCUITest. El 2026-11-05 el iPhone 17 Pro pasó de 7,5 a 24 GB en una tarde (16 GB ahí), con una corrida colgada pidiendo el árbol de accesibilidad durante 2 h.

Con ninguna corrida viva (`pgrep -fl '[x]codebuild'`) se vacía con `find <ruta> -mindepth 1 -delete`. Tras borrar, `df` puede bajar unos segundos antes de subir (APFS liberando). Y `~/Library/Developer/XcodeBuildMCP/workspaces/` guarda DerivedData de worktrees ya retirados (9,3 + 5,9 GB ese día): se borra la carpeta cuyo worktree ya no existe.
