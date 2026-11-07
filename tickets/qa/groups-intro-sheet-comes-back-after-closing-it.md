---
id: groups-intro-sheet-comes-back-after-closing-it
status: qa
priority: low
area: "groups, onboarding"
created: 2026-11-05
updated: 2026-11-06
source: "QA en el iPhone de pruebas del 2026-11-05 (montaje C)"
---

# La hoja de bienvenida de Grupos vuelve cada vez que entras si la cerraste con la X

Al entrar en la pestaña Grupos por primera vez sale «Comparte gastos sin perderles el rastro» (3 pasos). Si se cierra
con la X, vuelve a salir cada vez que se entra en Grupos; solo deja de salir al llegar a «Ir a Grupos». Por decidir si
la X debe contar como vista. iPhone 14, iOS 27.2, Yala Dev sobre `origin/2.2` (#809). Vídeo: `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/C-iphone-barra-de-abajo.mov`.

## Decisión y hecho (2026-11-06, lote UI 2.3)

Jürgen eligió la **opción B**: la X la aplaza UNA vez. Si se cierra con la X, vuelve solo en la siguiente entrada a
Grupos; si se vuelve a cerrar con la X, queda marcada como vista y no sale más sola. «Ir a Grupos» la sigue marcando en
el acto. Marca nueva per-device `groupsOnboardingPostponedOnce` (se borra con «Vaciar datos» y el cierre de sesión, como
`hasShownGroupsOnboarding`). Tests: `GroupsOnboardingCloseUITests` (rojo con la X sin efecto, medido con el mutante) y
`GroupsOnboardingCloseOutcomeTests`. Evidencia: `~/Claude/entregas/2026-11-06-lote-bugs-ui-idioma-ipad-grupos/evidencia/antes-1.png` (tercera entrada con la hoja) ·
`~/Claude/entregas/2026-11-06-lote-bugs-ui-idioma-ipad-grupos/evidencia/despues-1.png` (tercera entrada sin ella).

**Guion de QA (iPhone 14, con la bienvenida sin ver):** entra en Grupos → sale la bienvenida → X. Sal y vuelve a
Grupos → sale otra vez → X. Sal y vuelve → ya no sale.
