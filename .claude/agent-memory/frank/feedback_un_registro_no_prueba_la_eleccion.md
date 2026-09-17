---
name: un-registro-no-prueba-la-eleccion
description: Bloqueé la puerta en el `nil` de la asociación y las dos lentes cazaron que el `true` lo fabricaba un cinturón con la sesión de otra persona; antes de fiarte de un registro como prueba de elección, cuenta sus ESCRITORES
metadata:
  type: feedback
---

**Cuando una regla lee un registro como «la persona eligió esto», no basta decidir qué valor bloquear: hay que contar
quién escribe el valor que deja pasar.**

**Why:** 2026-09-17, `fresh-start-keeps-a-groups-session-that-migrate-promotes` (PR #190). Bloqueé «Activar la nube»
cuando la asociación de grupos daba `nil` en un teléfono sellado, con 11 mutantes cazados. Las dos lentes de la review, por
separado, encontraron que el cinturón de `GroupsSignInView` escribía `true` con la cuenta de la persona anterior: una
invitación sin token re-presenta la hoja, y la hoja reusa la sesión viva sin botones. Era el bug entero por la otra rama
del mismo valor. Ningún mutante podía verlo, porque un mutante mide lo que ya está escrito, no un escritor que falta por
guardar.

**How to apply:**

- Antes de dar por buena una regla sobre un registro, haz `grep` de TODAS las llamadas a su escritor. Para cada una
  pregunta: ¿puede escribir con un estado que la persona no eligió, como un cinturón, un fallback, un registrador de
  arranque o un reintento?
- Si el escritor no sabe de dónde viene el dato, dáselo con un parámetro sin default y pon el guard DENTRO del escritor.
- La misma pasada sirve para la salida que recomienda tu aviso: aquí «Desasociar» escribía en el iCloud-KV del Apple ID
  de la persona anterior.

Relacionado: [[el-guard-va-dentro-del-escritor]], [[mi-fix-hereda-la-forma-del-bug]],
[[una-frase-de-alcance-se-cuenta-por-llamadores]], [[el-copy-que-promete-se-recorre]].
