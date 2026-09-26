---
id: fresh-start-has-no-way-out-when-group-writes-can-never-upload
status: backlog
priority: medium
area: "groups, modo-nube"
created: 2026-09-26
source: "review adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently` (2026-09-26)"
---

# «Empezar de cero» no tiene salida cuando los cambios de grupos no pueden subir nunca

## El síntoma

Recibo un iPhone que era de otra persona, o mi sesión de grupos caducó. Quedan gastos de grupo sin subir. Toco
«Empezar de cero» y la app me dice que faltan cambios de grupos por subir. Vuelvo a intentarlo días después y me
dice lo mismo. No puedo empezar de cero, y el texto me pide «vuelve a iniciar sesión» en una cuenta que no es mía.

## Lo medido (2026-09-26, review adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently`)

Desde ese ticket, «Empezar de cero» sube el outbox de grupos antes de borrar y, si no sube, no borra. Con
`.sessionExpired` (la sesión la borró el SDK), `.permanent` o `.channelPaused` sostenido, la subida no drena nunca.
El gesto no ofrece «perderlos», por la decisión de Jürgen del 2026-09-15 para el desasociar, y el cierre de sesión
solo la ofrece con `.attestUnavailable`. Queda una salida real: desinstalar Yala, que borra el store y el outbox de
todas formas.

Lo cazaron dos lentes por separado. Antes de ese ticket el gesto era justo la salida: borraba el outbox sin avisar.

## La decisión que falta (de Jürgen)

1. Ofrecer «Empezar de cero y perderlos», con la cifra y una segunda confirmación, solo con los motivos que esperar
   no arregla: `.sessionExpired`, `.permanent` y `.attestUnavailable`. Es el molde del cierre de sesión con el attest.
2. Dejarlo como está: la salida es reinstalar.

En el alert del shell, la opción 1 pide un segundo alert con sus labels literales y su entrada en la matriz de
readiness (`.claude/rules/swiftui-ds.md`).
