Yala
# Mejoras necesarias 2.3 · Cuentas, categorías, etiquetas y divisas: lo que aparece sin pedirlo
card: tablero-mejoras-necesarias-2-3-cuentas-categoria-u8nd
toca: Yala/App/Views/Settings/,Yala/App/Views/Tags/,Yala/App/Views/Categories/,Yala/App/ViewModels/,Yala/Resources/
esfuerzo: high

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
FIN
