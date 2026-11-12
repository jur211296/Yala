# Auditoría modo Solo gastos

Cierre: **cierra-sola o PARA** → si dejas propuestas/lienzo, PARA y espera a Jürgen; si solo informe y cierra, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `auditoria-solo-gastos` · Sesión cola **S5** · al cerrar → **S6**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/auditoria-solo-gastos-heroes-1qfi.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones

Auditoría hecha y propuestas en https://claude.ai/artifact/JPiTrKo6574VBoKpmFjTm8. **Jürgen eligió en la sesión (26-oct):**

- **L1-A** Las cuatro cabeceras de Estadísticas en «Solo gastos», como el Panel: «Gastos del período», cifra del gasto y chip de variación «vs período anterior»; fuera el chip pequeño que repetía la cifra.
- **L2-A** Tendencias: fuera la frase de variación del balance en «Solo gastos» (decía «por debajo» cuando el gasto subía).
- **L3** (bug, sin opciones) La naturaleza que fija «Solo gastos» deja de contar como filtro aplicado (píldora «Gasto» del Panel, título vacío y punto en Estadísticas).
- **L4-A** Widget de flujo de inicio: «Gastado» y la cifra en positivo.
- **L5-A** Comparativa: el selector «Ingresos y gastos» se llama «Gastos».

Asumido por mí (autónomo):
- Registros no tiene período anterior calculado ni en modo normal: su cabecera lleva rótulo y cifra, sin chip de variación. Calcularlo es otro alcance.
- Distribución toma la variación del mismo total anterior que ya enseña la tarjeta de la tarta.
- Solo «Solo gastos»: el modo normal no cambia.
