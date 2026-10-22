---
name: el-orden-hace-invisible-al-segundo-termino
description: Descarté un término por «redundante, porque el otro ya lo implica por el orden» — y ese orden era justo lo que lo hacía invisible. El flag se enciende ANTES de mirar el error, así que se lo traga
metadata:
  type: feedback
---

**Cuando justifiques descartar un término porque «el orden hace que el otro ya lo implique»,
comprueba en qué DIRECCIÓN trabaja ese orden.** Implicar no es lo mismo que distinguir: un flag que
se enciende antes de mirar el error implica que hubo un evento, y por eso mismo **no puede decirte
si ese evento trajo algo o falló**.

**Why:** el 2026-09-20, en `restore-says-no-data-when-the-icloud-import-never-settled`, escribí en el
Paso 0 que `lastImportError` no entraba como segundo término porque «es redundante: por ese mismo
orden, todo error de import implica ya la actividad». Medido: `hasObservedImportActivity = true` está
en la CABECERA del `case .importEvent`, antes del `if let error`. Leí eso como «el error ya está
cubierto» cuando significa lo contrario — **la actividad se traga el error**. Resultado: la pantalla
nueva le decía «seguimos trayendo tus datos» a dos poblaciones que no iban a recibir nada, con un
«Reintentar» que devolvía al mismo sitio indefinidamente. Y la peor de las dos era **el usuario nuevo
con red inestable**: un solo evento con `networkUnavailable` le encendía el flag con la cuenta vacía,
o sea el remedio que Jürgen había descartado, entrando por la puerta de atrás.

Lo cazaron **las tres lentes de la review a la vez**, lo que ya dice cuánto se veía desde fuera y
cuán poco desde dentro.

**How to apply:**

- Un argumento de la forma «A implica B, luego B no aporta» exige nombrar **qué distingue B que A no
  distinga**. Si no lo sabes contestar, B no es redundante: es el término que falta.
- Con un flag booleano encendido por un evento, pregunta siempre: *¿lo enciende también el caso que
  fracasa?* Si sí, el flag responde «pasó algo», no «pasó bien».
- **El segundo término suele estar ya escrito en el repo.** Aquí era la vigencia por fechas
  (`lastExportErrorAt` vs `lastSuccessfulExportDate`, `ICloudCutoverGateLogic`, `ReverseUploadBlockerLogic`),
  con su lección ya pagada: un `last*Error` es un latch que ningún éxito limpia, así que se compara
  con la fecha del último éxito. Busca el gemelo antes de inventar.
- Y el corolario de escritura: **un Paso 0 con un argumento así es una premisa, no una decisión**.
  Va a la review como todo lo demás. Relacionado: [[mi-docblock-tambien-es-una-premisa]],
  [[la-premisa-del-encargo-tambien-se-mide]], [[un-gate-falla-abierto-por-su-entrada]].
