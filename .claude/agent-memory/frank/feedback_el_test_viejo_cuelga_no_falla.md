---
name: el-test-viejo-cuelga-no-falla
description: Cuando un fix mueve un outcome de "parada" a "reintento", los tests que pinneaban la parada no se ponen rojos — cuelgan la corrida; y el inventario de tests a tocar que trae el ticket se mide, no se cree.
metadata:
  type: feedback
---

Cuando un arreglo mueve un outcome de **parar** a **reintentar**, los tests viejos que esperaban la
parada **no dan rojo: cuelgan la corrida**. El `await task.value` de un loop que ahora hace backoff no
vuelve nunca, y si el test inyecta un sleeper que no duerme, además gira al 100 % de CPU.

**Why:** el 2026-09-14, en `groups-sync-treats-an-infra-403-as-an-account-verdict`, el 403 sin envelope
del kill pasó de `.accountUnavailable` (parada sellada) a `.transient` (backoff). El ticket enumeraba
«los dos tests que hoy pinnean el comportamiento actual» y yo los arreglé. **Eran cuatro.** Los otros
dos vivían en `GroupsSyncClientTests`, un fichero que el arreglo no tocaba, y sembraban
`StubHTTPSession(statusCode: 403)` con su **body por defecto** —una página de pull vacía, sin
envelope—, así que caían en la rama nueva. Uno no inyectaba sleeper siquiera: habría dormido la
escalera del backoff (5→10→…→300 s) para siempre. La suite no tiene `.timeLimit` y no hay
`.xctestplan` en el repo, así que nada los habría cortado. Los cazó la review adversarial; las tres
lentes coincidieron en ello como su hallazgo ALTA.

**How to apply:**

- **El inventario de tests que trae un ticket es una afirmación verificable, como cualquier otra
  coordenada suya.** Antes de darlo por bueno: `grep -rn "<el status/código que cambia>" YalaTests/`
  filtrado por el área, y **mira el cuerpo POR DEFECTO de cada stub** — el fallo no estuvo en que el
  test nombrara el 403, sino en que su stub no nombraba nada y por eso no salía en la búsqueda obvia.
- **El modo de fallo a buscar no es «¿este test se pondrá rojo?», sino «¿este test TERMINA?».** Un
  test que espera una parada y recibe un reintento es la forma más barata de colgar una suite entera,
  y el síntoma no se parece a un test roto: se parece a un simulador lento o a un disco lleno, que es
  a donde te vas a ir a buscar primero.
- **Corolario que descubrí midiendo: eso también le pasa a los mutantes.** Un mutante que se traga el
  kill (devolver `.transient` para todo 403) **cuelga** el test del kill en vez de fallarlo. Si un
  mutante "sobrevive" y la corrida tarda de más, mira si está colgado antes de creerte el verde.
- Cuando el sujeto de un test deja de existir, **retíralo y deja una nota en su sitio** diciendo dónde
  vive ahora la cobertura. Un test borrado en silencio reaparece como hueco tres meses después.
