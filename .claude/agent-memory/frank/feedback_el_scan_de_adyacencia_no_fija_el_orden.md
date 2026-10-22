---
name: el-scan-de-adyacencia-no-fija-el-orden
description: Fijar que un guard va pegado a lo que protege NO impide mover la lectura que lo alimenta por encima del await — el mutante sobrevive en verde y decide con estado rancio. Fija el tramo entero.
metadata:
  type: feedback
---

Cuando lo que protege un guard es **cuándo se leyó su entrada**, el escáner tiene que fijar el
TRAMO ENTERO —desde el `await` hasta la escritura— y no solo que el `guard` vaya pegado a ella.

**Why:** el 2026-09-14, en el aviso de vaciado remoto (`ContentView`, `onChange` de `hasPersonalData`),
escribí un `#expect` sobre el literal `guard sessionObeysWipeSignal else { return } showRemoteWipeAlert = true`
y su docblock prometía cazar «la lectura decidida cinco segundos antes». **No la cazaba.** Mover el
`let` del eje por encima del `try await Task.sleep(...)`, dejando cualquier otro `let` detrás, pasaba
las cuatro aserciones EN VERDE con el eje evaluado cinco segundos antes de afirmarlo.

Peor: **el mutante que probé a mano sí cayó, y me dio confianza falsa.** Cayó por accidente — en su
forma ingenua (mover el `let` sin nada detrás) el delimitador ` guard ` del helper arrastraba el
`sleep` dentro de la sentencia medida, así que la comparación por igualdad fallaba por otro motivo.
Con una línea intermedia habría pasado. Lo cazó una lente adversarial, no yo.

**How to apply:** si la corrección que estás escribiendo tiene la forma «esto se lee DESPUÉS de
aquello», el literal del test empieza en «aquello». Aquí quedó:

    "try await Task.sleep(for: .seconds(5)) " + <la sentencia del eje> +
    " guard sessionObeysWipeSignal else { return } showRemoteWipeAlert = true"

Incluir el `.seconds(5)` es deliberado: cambiar el debounce obliga a pasar por el sitio donde está
escrito por qué el eje se lee después.

Dos hermanos del mismo día, los dos míos y los dos cazados por la review:

- **Contar el literal `= true` no cubre un `@Binding`.** El flag viajaba a `ShellDataAlertsModifier`,
  desde donde `showRemoteWipeAlert = loQueSea` o un `.toggle()` lo encendían sin eje. Se cuenta la
  **asignación** (`"showRemoteWipeAlert = "`), no el valor.
- **El `>= N` holgado como «control del instrumento» es [[la-asercion-que-no-puede-fallar]]**: puse
  `>= 4` sobre un needle que sale 20 veces. Ningún mutante lo mueve, y además es redundante con el
  `== 1` de al lado. El control bueno es un conteo que valga poco y exacto — aquí,
  `"@State private var showRemoteWipeAlert" == 1`.

Relacionado: [[el-source-scan-de-dos-literales-no-es-una-red]] ·
[[la-review-adversarial-caza-lo-mio]] · [[mis-mediciones-fallan-por-el-filtro]]
