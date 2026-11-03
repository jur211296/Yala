---
name: un-haptico-nuevo-mira-aguas-abajo
description: Al añadir un DS.Haptic, recorre el callback hasta el final (anfitrión, VM, cierre con aviso); la tanda C4 metió cuatro dobles vibraciones así
metadata:
  type: feedback
---

Al añadir un háptico en una vista, sigue el callback que llama hasta el final antes de darlo por bueno: el anfitrión que
lo recibe (`askSegmentFilter` ya vibraba al tocar un sector de la tarta), el ViewModel (`savePayment` ya vibraba
`error()`), y el cierre con aviso del formulario (`closeWithSavedNotice` / `closeAfterRecurringEditor` ya vibraban
`success()`). En la tanda C4 (2026-11-02) puse cuatro hápticos dobles así; los cazó la review adversarial de
comportamiento, no los tests.

**Why:** la auditoría de fluidez marcaba «sin háptico» mirando solo el fichero de la vista; el háptico vivía aguas
abajo. La fila de la tarta estaba mal medida. Grep por `DS.Haptic` en el fichero tocado no ve al anfitrión.

**How to apply:** por cada háptico nuevo, grep del callback (`onSelect…`, `onSaved`, `handle…`) y de las funciones que
encadena; si alguna vibra, no añadas el tuyo o haz el del componente condicional (`hostVibratesOnSave`). Fíjalo con un
source-scan de «uno por gesto». Relacionado: [[la-premisa-del-encargo-tambien-se-mide]].
