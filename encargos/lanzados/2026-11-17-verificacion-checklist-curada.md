Yala
# Curar la checklist de confiabilidad con disparadores a partir de las reglas
---
toca: qa/checklist-confiabilidad.yaml,qa/scripts/checklist-confiabilidad-test.sh,docs/verificacion/checklist-confiabilidad.md,tickets/done/2026-11-17-verificacion-checklist-curada.md
esfuerzo: high
cierre: cierra-sola
---

## Qué hay que hacer (P4, primera parte)
Las lecciones viven en reglas de prosa que se cargan enteras (`swiftdata-cloudkit.md` 2.097 líneas y 263 entradas; `testing.md` 296 y 73).

- `qa/checklist-confiabilidad.yaml` con 30 a 40 ítems. Cada uno: id, disparador verificable en un diff (rutas, símbolos o patrones), comprobación concreta, incidente o PR que lo creó, y última vez que se disparó (vacío por ahora).
- Fuente: `.claude/rules/swiftdata-cloudkit.md`, `testing.md`, `currency-fx.md`, `ingreso-gasto.md`, el formulario de registro y los tickets de rojos del 14 y 16-nov. Solo lógica cara primero: nube, dinero, migraciones, formulario de registro. Ejemplo de la propuesta: «cambia la altura de Nuevo registro → correr la calculadora, el selector de tarjeta, favoritos y casos límite».
- Un ítem entra solo si su disparador se ve en un diff y el patrón salió en al menos dos incidentes o PRs; un revisor adversarial refuta la lista antes de cerrar.
- No borres las reglas: en el artifact deja el mapa regla → ítem, para que la sesión de poda archive lo que ya quedó cubierto.
- Banco que valide el formato del YAML.
- Ticket en `tickets/done/2026-11-17-verificacion-checklist-curada.md`.

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

## Paso 0 (Frank, 2026-11-17 11:45, modo semi)

Decisiones tomadas antes de escribir (todas menores y reversibles; ninguna pide a Jürgen):

1. **Semántica del disparador.** `rutas` (glob tipo fnmatch, `*` cruza carpetas) acota DÓNDE; `simbolos` y
   `patrones` acotan QUÉ, sobre las líneas añadidas o quitadas del diff. Un ítem se dispara si alguna ruta casa
   (o no tiene rutas) **y** algún símbolo o patrón casa (o no tiene ninguno). Así un ítem puede ser «cualquier
   cambio en este fichero» o «este patrón en cualquier sitio» sin un segundo campo de modo.
2. **Formato del YAML.** Fechas entre comillas (`"2026-11-17"`): sin PyYAML en la Max, el banco parsea con el YAML
   de la librería estándar de Ruby, que rechaza fechas sin comillas en `safe_load`; con PyYAML, igual. Un solo
   formato para los dos.
3. **El banco valida contra el árbol, no solo la forma.** Cada glob tiene que casar con al menos un fichero, cada
   símbolo existir en el código, cada clase de prueba nombrada existir, cada `regla` apuntar a un fichero y unas
   líneas que existen, cada regex compilar, y cada ítem traer ≥2 orígenes distintos. La documentación de este
   repo envejece más rápido que el código: un ítem que apunta a algo renombrado tiene que caer.
4. **Medición retrospectiva aparte.** Para cada ítem se comprueba en `git` que su disparador se habría encendido
   en el diff de al menos uno de sus PRs de origen. Es una medición de esta sesión (va al documento y al
   artifact), no parte del banco: el selector es la segunda parte de P4.
5. **El banco no se engancha al CI en este PR.** Engancharlo toca `.github/workflows/qa.yml`, fuera del `toca:`;
   lo hace la segunda parte («revisor con checklist en el gate»), que es quien lee el fichero de `origin/2.3`.
6. **Las reglas no se tocan.** El mapa regla → ítem va en el documento y en el artifact.
7. **Fuentes leídas por cuatro lectores en paralelo** (nube 1-1050, nube 1050-2097, pruebas+divisas+saldo,
   formulario+rojos de interfaz); la selección final, la redacción y la medición son mías, y un revisor
   adversarial aparte refuta la lista antes de cerrar.
