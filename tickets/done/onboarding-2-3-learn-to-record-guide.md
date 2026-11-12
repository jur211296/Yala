---
id: onboarding-2-3-learn-to-record-guide
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-2-pagina-y-formulari-6vu0 (docs/onboarding-2-3/SPEC.md, Y23-08)
qa-status: passed
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - cuatro maneras, guía de foco 1 a 5 sobre el formulario de hoy y ¡Listo! recorridos por XCUITest con capturas; texto grande AX XL comprobado
---
# Bienvenida 2.3 · Paso 2 · Página y formulario con guía de foco (Y23-08)

«Aprender a registrar» abre «Cuatro maneras de anotar» (A mano · Con la voz · Con una foto · Con Yala IA, cada 3,4 s;
las tres últimas con PRO y «Aquí la pruebas gratis una vez») con «Empezar a mano» y «Omitir este paso». A mano abre el
formulario de HOY (`NewTransactionView`, sin rediseñarlo) con la guía de foco de la app (`CoachMarkOverlay`) en cinco
pasos: «Empieza por el monto» · «¿En qué fue?» (abre la hoja real de categorías) · «Tu cuenta ya está puesta» ·
«Un nombre, si quieres» (Escribir / Saltar) · «Guárdalo». Cada paso avanza al hacer la acción (el foco deja pasar el
toque) y «Omitir guía» deja el formulario normal. Al guardar, el «¡Listo!» de los primeros registros.

Mientras dura el tutorial nada da por hecho el paso 2 (ni el formulario, ni `autoDetect`, ni las prácticas): lo cierra
el tutorial al terminar. Si se cierra a mitad, el mazo sigue en el paso 2 y se retoma donde iba.

Pruebas: `YalaTests/Bienvenida23PasosTests` (NewRecordTutorialGuideTests) y
`YalaUITests/Flows/Bienvenida23PasosUITests#test_step2_manualWithGuide_thenCleanupAndInboxGuide`.
