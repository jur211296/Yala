Yala
# Mejoras necesarias 2.3 · Cuentas, categorías, etiquetas y divisas: lo que aparece sin pedirlo
card: tablero-mejoras-necesarias-2-3-cuentas-categoria-u8nd
toca: Yala/App/Views/Settings/, Yala/App/Views/Tags/, Yala/App/Views/Categories/, Yala/App/ViewModels/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 09 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/39-cuentas-categorias/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/862.

## Encargo y criterio de terminado
Implementar SOLO estos 4 puntos:
1. Sin ninguna moneda secundaria, Tipo de cambio enseña las dos primeras divisas de la lista, que no tienen por qué importar a nadie (CurrencySettingsView.swift:250, prefix(2)).
2. La lista de cuentas dice los saldos con el código (PEN 2,000.00) y el formulario y el Panel con el símbolo (AccountsSettingsListViewModel.formattedBalance).
3. El + de Categorías crea e inserta una categoría vacía antes de escribir nada; si la app se cierra a mitad puede quedar una categoría sin nombre (CategoriesSettingsListViewModel.createAndOpenNewCategory; hipótesis: reproducir antes).
4. Etiquetas: la X del formulario cierra sin preguntar con cambios (Cuentas y Categorías sí preguntan); el nombre se corta a 20 sin avisar y la lista enseña el color como «#5E5CE6» (TagFormView; G3 de la zona 39).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Punto 3: reprodúcelo antes con un test; si no se reproduce, documéntalo y no toques nada.
- Punto 1: lo mínimo es no enseñar divisas que nadie eligió; seguir solas las monedas de las cuentas (F2) queda para Jürgen.
- No toques archivar ni el número de cuenta: son decisiones abiertas.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 (Frank, 10-nov noche, modo nocturno)

- **Precondición medida:** `origin/2.3..origin/2.2` = 16 commits, pero el merge corto de 2.2 en 2.3 ya entró (PR #884). Lo que falta es la cola del día (Grupos: borradores repetidos; subida a TestFlight; docs). `git diff origin/2.3...origin/2.2` no toca ninguna vista del lote (solo `InboxViewModel`, fuera). ⇒ sigo; no es BLOQUEANTE.
- **Rama:** nació de 2.2 por error del lanzador; recolocada sobre `origin/2.3`.
- **Aviso de otra sesión sobre Settings/ViewModels** (registrar-decisiones del 5-nov): no hay rama remota ni tmux; ningún PR abierto toca estos ficheros. ⇒ sigo.
- **Los 4 puntos siguen vivos en 2.3** y `git log origin/2.3..origin/2.2` no trae nada sobre sus ficheros.
- P1 · sin secundarias, Tipo de cambio no enseña ninguna divisa: solo «Ver todo». Asumido: sin texto nuevo (seguir las monedas de las cuentas, F2, queda para Jürgen).
- P2 · la lista usa la preferencia «código / símbolo» de Personalización, como el Panel (por defecto, símbolo). Decimales: se quedan en 2 (no es el defecto).
- P3 · primero se reproduce con un XCUITest (crear, guardar subcategoría, cerrar la app, volver). Si no sale, no se toca.
- P4 · X con cambios pregunta (alerta de descartar, la misma de Categorías); contador del nombre al acercarse a 20 y aviso al llegar; el color se nombra (y VoiceOver lo lee por nombre; uno propio = «Color propio»). «Activas» en singular NO entra: tiene su ticket.
