---
esfuerzo: medium
---
# S12 · Grupos UX: copy crear vs Ajustes + aviso pendientes

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `grupos-ux-copy-aviso` · Sesión cola **S12** · al cerrar → **S13**.

## Contexto · cards del lote
- Grupos: el formulario de crear y los Ajustes del grupo nombran las mismas opciones con palabras distintas
- Grupos: «Grupo» del botón + con grupos solo pendientes de aprobación no abre nada ni avisa

## Briefs per-card (lee y cumple cada uno)
- `~/Claude/tmp-frank/grupos-copy-crear-vs-ajustes-avq3.md`
- `~/Claude/tmp-frank/grupos-plus-pendientes-aviso-k26u.md`

## Qué se pide
1. Lee y cumple ambos briefs: igualar copy Crear↔Ajustes (Moneda/División) + aviso al tocar «Grupo» del + con solo pendientes (`showPendingApprovalNotice`).
2. Un PR a 2.2; tests/capturas según briefs.

Mueve las cards a «in progress» con `--agente frank` al empezar; al cerrar, a in qa / done según el cierre de cada una.

## Qué NO tocar
- marketing/ y Web/ (Lola).
- Otras sesiones de la cola (no las lances).
- No desactivar tests ni saltarte el gate.
- Lo específico de cada brief per-card.

## Cómo se sabe que está bien
Cada card cumple su hechaCuando; suite relevante verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


Cards: `tablero-grupos-el-formulario-de-crear-y-los-ajus-avq3`, `tablero-grupos-grupo-del-boton-con-grupos-solo-p-k26u`. Versión 2.2. Base `origin/2.2`.
Cierre: cierra sola con `/cerrar-total` salvo decisión vital (fuerza mayor, seguridad o diseño crítico).

## Paso 0

Modo: **autónomo** (cierra-sola). Worktree → rama + PR a `2.2` en auto-merge.

Ficheros (nota, no pregunta):
- `Yala/App/Views/Groups/GroupFormView.swift` — Moneda y División usan las claves de Ajustes (`L10n.UXL19.singleCurrency` / `.splitType`).
- `Yala/Utils/L10n+UXAudit22Lote13Decididas.swift` + 16 `Localizable.strings` — se retiran `groups.d13.form.singleCurrency` y `groups.d13.form.splitType`, que quedan sin uso.
- `Yala/App/Views/Groups/GroupsContainerView.swift` — al llegar el «Grupo» del + sin grupo elegible y con alguno pendiente de aprobación: aviso de pendiente y se retira la petición.
- `YalaUITests/Flows/GroupsCrearDecididoUITests.swift`, `YalaUITests/Flows/GroupPendingMemberDoorUITests.swift` y `qa/coverage-index.json`.

Decisiones asumidas:
1. **Copy por reuso de clave, no por copia**: crear lee las mismas claves que Ajustes, así no pueden volver a divergir y las 16 traducciones ya existen. Nada de copy nuevo.
2. **«Menos pagos entre ustedes»**: el título ya es igual; su ayuda en crear («Yala junta las deudas…») no contradice el ejemplo de Ajustes, así que no se toca. El pie de moneda ya es la misma clave en los dos.
3. **«Otro pendiente de aprobación» = reutilizar el aviso existente** («Esperando aprobación» + cuerpo), tal cual. No se escribe un título nuevo.
4. **Cuándo avisa**: ningún grupo donde apuntar ya y al menos uno con tu solicitud pendiente. Antes de avisar se recarga una vez (la aprobación pudo bajar hace un instante). Solo archivados, sin pendientes: sigue la hoja «primero crea un grupo» de L13-8, que es la que dice la verdad en ese caso.
5. **El gasto pedido se retira** al avisar: ya no salta solo horas después, cuando llegue la aprobación.
6. Solo el camino del + sin grupo concreto. El «Apuntar un gasto» de un grupo concreto (L12-18) ya tiene su propia espera y no se toca.
