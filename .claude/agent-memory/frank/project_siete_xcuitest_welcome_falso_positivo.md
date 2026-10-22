---
name: siete-xcuitest-welcome-falso-positivo
description: Los 7 XCUITest del Welcome que un ticket high daba por rotos están SANOS — descartado el 11-sep con tres mediciones; lo que quedó fue el centinela del simulador y un high nuevo esperando decisión de Jürgen
metadata:
  type: project
---

**`welcome-chooser-uitests-cannot-reach-the-chooser` está `discarded` desde el 2026-09-11: los siete
casos pasan.** PR #145.

**Why:** el ticket nació `high` durante el gate de `groups-invite-on-a-mirrored-store-crosses-data`
(#143) y traía su propia bisección contra `1a9cbb83`. Medido tres veces: 11/11 verde en `2.1` de hoy
(dos corridas), 11/11 en `1a9cbb83` —la revisión de la bisección— y los once verdes en la nocturna de
CI del 11-sep dentro de los 149 casos. Las dos suites eran **byte-idénticas** entre esas revisiones,
así que no había eje que bisecar: lo que variaba era la máquina. La corrida que lo midió compartía el
único simulador con la sesión de #143.

**How to apply:**

- **No lo reabras suelto.** El ticket descartado lleva dentro la medición y qué hacer si reaparece:
  correr las dos suites aisladas con el centinela en verde. Si con eso siguen rojas, entonces sí.
- **Lo que quedó abierto es la contención, no el Welcome**: `diez-worktrees-comparten-un-simulador`
  subió a `high` y **espera decisión de Jürgen** entre sus tres opciones (un simulador por worktree ·
  un lock de fichero · seguir a mano). Este PR solo añadió DETECCIÓN
  (`qa/scripts/sim-libre.sh --vigilar`), no prevención.
- **Dato de paso que sigue vivo:** la nocturna del 11-sep confirma que los cuatro de
  `nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` siguen rojos, y tres de ellos **3/3 reintentos**
  en dos noches distintas. Eso ya no se sostiene como «flaky de runner frío».
- El `docs/ESTADO.md` de `2.1` citaba este ticket como «el `high` de testing que va primero»: hay que
  corregirlo al escribir el estado tras el merge.

Relacionado: [[dos-corridas-un-simulador]] · [[la-premisa-del-encargo-tambien-se-mide]] ·
[[puerta-neutro-del-invitado]]
