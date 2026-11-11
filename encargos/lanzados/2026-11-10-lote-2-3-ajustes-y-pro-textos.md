Yala
# Mejoras necesarias 2.3 · Ajustes y Pro: textos que mandan al sitio equivocado
card: tablero-mejoras-necesarias-2-3-ajustes-y-pro-tex-t1w8
toca: Yala/App/Views/Settings/, Yala/App/Views/ExportWizard/, Yala/App/Views/Subscription/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 10 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/40-perfil-ajustes/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/864.

## Encargo y criterio de terminado
Implementar SOLO estos 3 puntos:
1. La prueba de Pro dice «Cancela en Ajustes y no se cobra nada»: en los Ajustes de Yala no hay dónde; es en los del iPhone (uxpro.trial.cancelBody).
2. Privacidad y datos IA marca Yala IA como Pro pero no Resumen con IA, que también lo es (AIPrivacySettingsView; FeatureGateService.isProOnly .smartInsightsAI).
3. Sin registros, la fila de Exportar sale gris sin decir por qué (D4 de la zona 40).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas.
- No reordenes Ajustes ni renombres filas (A2 y B1 de la revisión quedan para Jürgen).
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, sesión nocturna): las recomendaciones se dan por buenas. Se discuten en el PR.

**D0 · ¿2.3 tiene lo de 2.2?** → Sí para este lote; se sigue. `git rev-list --count origin/2.3..origin/2.2` = 16, pero
son el arreglo de Grupos de la tarde del 10-nov (borradores repetidos), la subida de TestFlight 2.2 (9) y documentación.
Ninguno toca `Settings/`, `ExportWizard/`, `Subscription/`, `Profile/` ni `FeatureGateService`
(`git diff origin/2.3...origin/2.2 -- <esas rutas>` vacío). Por qué: el criterio «casi 0» busca no portar a mano lo que
2.2 ya arregló, y aquí no hay nada que portar. Alternativa descartada: parar con BLOQUEANTE, que frenaría la cadena por
commits que no cruzan con el lote.

**D1 · Punto 1: ¿qué dice la prueba?** → «Cancela en los ajustes de tu dispositivo y no se cobra nada.» (y su
equivalente en los 16 idiomas, con la misma fórmula que ya usa `usageMode.leave.pro`). Por qué: medido en código, la
premisa de la revisión es solo medio cierta — durante la prueba `isProUser` es verdadero (la prueba es un derecho en
`currentEntitlements`), así que Ajustes › Yala Pro SÍ muestra «Gestionar o cancelar». Pero esa fila no existe en la vista
de Solo grupos y el texto «Ajustes» a secas es ambiguo; los ajustes del dispositivo existen siempre, en iPhone y iPad,
y es lo que el encargo pide («es en los del iPhone»). «Dispositivo» y no «iPhone» porque la app corre también en iPad.
Alternativa descartada: «Ajustes › Yala Pro», más corto pero falso en Solo grupos.

**D2 · Punto 2: ¿solo la marca, o también el gesto?** → Las dos: sin Pro la fila lleva `ProBadge` y encenderla abre la
hoja de Pro en vez del permiso, igual que Yala IA. Por qué: es la decisión L14-11 opción D sobre esta misma pantalla
(«sin Pro su fila lleva la marca y encenderla abre la hoja de Pro»); con solo la marca, la fila seguiría aceptando un
permiso para una función bloqueada, que es el defecto que esa decisión cerró. Completa el objeto de la decisión, no
añade otro. Alternativa descartada: solo la marca (deja la incoherencia a la vista).

**D3 · Punto 3: ¿qué texto y dónde?** → El subtítulo de la fila apagada pasa a decir el motivo con el texto que ya
existe y ya está traducido (`accessibility.noTransactionsToExport` «No hay registros para exportar»; en Solo grupos,
`noGroupsToExport`). Con el motivo a la vista, la pista de VoiceOver repetida se quita. Por qué: es D4 en su versión
mínima (decir por qué); el enlace a Importar de la maqueta es UI nueva y la fila «Importar» ya está justo debajo.
Alternativa descartada: un texto nuevo «Aún no tienes registros que exportar» (16 traducciones nuevas para el mismo
significado).

**D4 · ¿`ProfileView.swift` entra aunque no está en `toca:`?** → Sí. La fila de Exportar vive ahí; ningún PR abierto lo
toca (medido con `gh pr list`). La sesión del 5-nov que avisó `lanzar-sesion` ya no existe (sin tmux ni rama remota).

**D5 · Tests** → Un XCUITest por punto en `AjustesYProNecesariasLote10UITests` (con control en verde para Pro y para
«con registros») y un unit test de los 16 idiomas para el texto de la prueba. Se corren primero sobre el código de
antes: rojos y con las capturas del «antes».
