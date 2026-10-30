# Capturas App Store 2.2 iPhone+iPad+Duo

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `capturas-app-store-2-2` · Sesión cola **S29** · al cerrar → **FIN**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/capturas-app-store-2-2-iphone-ipad-duo.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.

## Noche autónoma (Jürgen 2026-10-29 22:18 Lima: «que la noche fluya sin pedirme inputs»)
- Se lanza con `--permission-mode bypassPermissions`. No uses AskUserQuestion ni esperes respuesta de Jürgen: es de noche (21:00–6:00).
- Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en el ticket/card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card separada con `cierra-sola` asignada a jurgen explicando la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

/cerrar-total
