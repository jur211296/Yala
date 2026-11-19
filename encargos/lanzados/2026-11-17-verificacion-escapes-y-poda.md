Yala
# «Origen:» en los arreglos, primera revisión de escapes y poda de reglas
---
toca: .claude/rules/swiftdata-cloudkit.md,.claude/rules/testing.md,.claude/rules/archivo/,.github/pull_request_template.md,docs/verificacion/escapes/,docs/verificacion/revision-de-escapes.md,tickets/done/2026-11-17-verificacion-escapes-y-poda.md
esfuerzo: high
cierre: cierra-sola
---

## Qué hay que hacer (P5)
Va después de «Curar la checklist de confiabilidad con disparadores a partir de las reglas»: parte de `2.3` con ese PR mergeado (usa su mapa regla → ítem para podar).

- Convención `Origen:` en los PR de arreglo (el PR que trajo el bug, o «desconocido» con el porqué). Plantilla en `.github/pull_request_template.md`. Solo 1 de 11 arreglos lo dice hoy.
- Primera revisión de escapes (del 3 al 17-nov): qué bugs llegaron a 2.3, qué gate los habría parado y qué ítem de checklist se propone. Un ítem nuevo solo si el patrón salió en dos PRs y se ve en un diff, refutado por un revisor; los ítems nuevos van como propuesta en el artifact, no los metas en la checklist sin el visto de Jürgen en el PR.
- Poda: lo de `swiftdata-cloudkit.md` y `testing.md` que ya cubre la checklist o que no aplica pasa a `.claude/rules/archivo/` con su porqué (no se borra). Arregla la cita a `docs/TESTING-STRATEGY.md` («Lista Negra»), que no existe.
- `docs/verificacion/revision-de-escapes.md`: cómo se hace la revisión mensual (qué se mide, de dónde y el criterio de archivar lo que no se disparó en 90 días), para que la sesión mensual lo siga igual.
- Ticket en `tickets/done/2026-11-17-verificacion-escapes-y-poda.md`.

## Contexto
Propuesta de verificación del 17-nov (comparación con el equipo de Claude Code), aprobada por Jürgen el 17-nov: «Apliquemos todo lo recomendado». Fuente en `origin/2.3`: `docs/verificacion/README.md` y `docs/verificacion/propuesta-2026-11-17.html` (array `PROPUESTAS`). Artículo de referencia: https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/ . Lee la propuesta correspondiente entera antes de empezar; las mediciones de ahí son tu punto de partida, pero vuelve a medir lo que cambies.

## Reglas
- Commits y PR sin firma de IA. PR hacia `2.3`. Rama desde `origin/2.3`; justo antes del PR, `git fetch` y un solo rebase.
- Dependencias: la sesión arranca sobre `origin/2.3`, sin esperar CI ni merge del PR anterior; solo espera el merge si toca los mismos archivos o necesita el código de otra sesión (se indica abajo cuando aplica).
- `toca:` acotado: si necesitas tocar un archivo fuera de la lista, anótalo en el cierre con el motivo.
- Simuladores: en la Max puedes usar un segundo simulador si otra sesión ocupa uno (tope 2); también el iPhone 14 conectado por DeviceMCP.
- Nada de reglas, scripts ni workflows del gate que se lean del propio PR cuando la propuesta dice «leído de 2.3»: se leen de `origin/2.3`.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital (accesos, credenciales, seguridad, ruleset distinto de lo aprobado, minutos de runner fuera de lo razonable) se pregunta, no se asume. Semi 05:30–20:00: preguntas y esperas con la sesión viva. Nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto.
- Si el trabajo queda completo y el modo lo permite, termina con `/cerrar-total`.
- Entregable: artifact visual de Claude (antes/después, qué se midió, qué queda en observar y cuándo se promueve).
- El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada una con motivo o «Nada», y una sección «Lección» si hubo un error evitable.

## Paso 0 — decisiones

> Resueltas en semiautónomo por Frank: lo menor y reversible con la recomendación. Se discuten en el PR.

**D1 · ¿Se espera al PR de la checklist (P4, primera parte) antes de empezar?** → No se espera para trabajar; sí para abrir el PR.
Por qué: su mapa regla → ítem se lee de su rama; pero mi poda mueve líneas que sus `regla:` citan, así que mi PR toca `qa/checklist-confiabilidad.yaml` y necesita ese fichero en la base. Ese PR estaba en cola con un choque en `docs/TICKETS.md` y su sesión ya cerrada: lo rebasé sobre `origin/2.3` (choque solo de índice, banco en verde). Alternativa descartada: `BLOQUEANTE` por un choque de una fila.

**D2 · ¿Qué es «ya lo cubre la checklist»?** → Una entrada de la regla cuyo tramo cita el `regla:` de un ítem Y cuya lección dice lo mismo que la `comprobacion` del ítem. Se archiva entera y deja en su sitio una línea: título + `→ checklist <id>` + dónde está el texto.
Por qué: la checklist dispara en la revisión, pero quien escribe código en esa carpeta sigue cargando la regla; la línea le dice que existe la lección sin cargar 3 KB. Alternativa descartada: archivar sin dejar rastro (se pierde el aviso al escribir) o no archivar lo cubierto (no poda nada).

**D3 · ¿Qué es «no aplica»?** → Una entrada que describe código que ya no existe (medido con `grep` en `Yala/` y `YalaTests/`) o que la propia regla marca `[STALE]`, y cuya lección no repite en código vivo. Se archiva sin línea en su sitio.
Por qué: la cabecera de `swiftdata-cloudkit.md` ya dice que esas entradas son históricas; el archivo conserva el porqué. Alternativa descartada: archivar por fecha (una lección vieja puede seguir viva).

**D4 · ¿Dónde y cómo se archiva?** → `.claude/rules/archivo/<regla>.md`, con `paths: [".claude/rules/archivo/**"]` para que no se cargue solo, cada entrada con su fecha de archivo, motivo (`cubierta: <id>` o `no aplica: <qué se fue>`) y su posición original. `archivo/README.md` explica el criterio.
Por qué: Claude Code carga `.claude/rules/` recursivo y un fichero sin `paths:` se cargaría siempre, peor que hoy. Alternativa descartada: `docs/` (pierde la cercanía con la regla viva).

**D5 · ¿Se tocan los `regla:` de la checklist?** → Sí: los que apuntan a texto archivado pasan a apuntar al archivo, y los que siguen en la regla viva se recalculan. Fuera de `toca:`; se anota en el cierre.
Por qué: el revisor lee esos tramos («Regla larga»); un número de línea que se desplaza apunta a otra lección sin que el banco lo note (solo comprueba que la línea exista).

**D6 · ¿Qué cuenta como arreglo y como escape?** → Arreglo: commit `fix…` en un aterrizaje de `2.3` del 3 al 17-nov. Escape: el arreglo cambia líneas que trajo OTRO PR ya aterrizado. El origen se atribuye por `git blame` de lo que el arreglo borra (con lo que solo añade, la línea anterior, marcada débil), con un script repetible en `docs/verificacion/escapes/medir_escapes.py`.
Por qué: «1 de 11» de la propuesta contaba títulos; el blame da el PR de origen sin depender de que el arreglo lo diga, y la sesión mensual lo puede repetir igual. Alternativa descartada: leer solo títulos (pierde los arreglos dentro de lotes).

**D7 · ¿El script va en `qa/scripts/`?** → No: en `docs/verificacion/escapes/`, dentro de `toca:`.
Por qué: no lo usa el gate ni el CI; es la herramienta de una revisión mensual de documentos.

**D8 · ¿Ítems nuevos de checklist?** → Solo como propuesta en el artifact y en `docs/verificacion/escapes/2026-11.md`, con dos PRs de origen, el disparador visible en un diff y la refutación de un revisor independiente. No entran en `qa/checklist-confiabilidad.yaml`.
Por qué: lo pide el encargo; entran con el visto de Jürgen en el PR.

**D9 · ¿La convención `Origen:` se exige?** → Se pide en la plantilla del PR y en la revisión mensual se cuenta (con el script, `--origen-declarado`); no se bloquea en CI.
Por qué: la propuesta P5 la plantea como convención medida, no como gate; bloquear sería un cambio de ruleset no aprobado.

**Lo que cambió al ejecutar.** D2 se endureció: «el tramo lo cita un `regla:` y la lección dice lo mismo» no
bastó. De 41 entradas propuestas como cubiertas, el revisor de la poda encontró en 32 una regla operativa que la
checklist no dice, y se quedaron; se archivaron 9 (más las 3 de D3). D7 sigue: además de `medir_escapes.py`, el
criterio de 90 días necesitó `ultimo_disparo.py`, porque `ultimo_disparo` del YAML no lo escribe nadie.
