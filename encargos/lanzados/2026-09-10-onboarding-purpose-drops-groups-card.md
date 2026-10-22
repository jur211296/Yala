# Implementar ticket paso 7: onboarding-purpose-drops-groups-card

## Contexto
Cola del rediseño de sesiones. Pasos 0–6 en `2.1` (último: #135 beacon). Este es el **paso 7**: pequeño e independiente — retirar la card «Grupos» del paso *propósito* del onboarding personal. Solo-grupos es una sesión (Welcome «Vengo por un grupo»), no un propósito de [P].

Decisiones: sección **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»** del ticket + índice `docs/sessions/2026-09-09-desbloqueo-decisiones-rediseno-sesiones.md`. **Mandan.** (borrar el caso del enum y su gate; retirar textos.)

MODO AUTÓNOMO HASTA TERMINAR: modo **directo** (no [spec] obligatorio en runbook). Gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`. Ambigüedad NUEVA: elige lo más seguro alineado con Decisiones y regístralo.

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle — una vez.

## Que se pide
1. Leer Decisiones → ADR §7 → ticket → runbook (este paso).
2. Retirar card `groups` del propósito; `groupsOnly` inalcanzable desde [P]; strings/tests/`l10n-check`.
3. «Vengo por un grupo» sigue llevando a solo-grupos.
4. Un PR a `2.1` + `/cerrar-total`.

## Que NO hay que tocar
marketing/. Pasos 8–13 salvo lo mínimo. Welcome / bloque [I].

## Como se sabe que esta bien
Criterios del ticket; l10n-check verde; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión lanzada desde encargo, `CLAUDE_SESION_TMUX` puesto): las recomendaciones
> se dan por buenas. Se discuten en el PR. Medido en el árbol `75c5da00`.

**D1 · ¿Hasta dónde llega «borrar el caso y no dejar ramas muertas»?** → Hasta la **puerta B entera**: la
cesión de la card a la cadena de Grupos (`onGroupsOnlyComplete`, `startGroupsOnlyBranch`,
`pendingGroupsOnlyPayload`, `GroupsOnlyOnboardingPayload`, `GroupsGateLogic.Entry.onboardingCard` y el
parámetro `explicitCurrencyCode` del alta). Lo que comparte con «Vengo por un grupo» (puerta A) se queda
byte-idéntico.
Por qué: el único productor de todo eso es la card; sin ella es código que compila y no corre, y
`Entry.onboardingCard` sería exactamente el «caso deprecated» que la decisión prohíbe. Alternativa
descartada: quitar la card y dejar la cadena inalcanzable — contradice la decisión y el criterio C2 del
propio repo («un método que sigue compilando es lo que alguien vuelve a llamar»).

**D2 · ¿Se borra `OnboardingGroupsPurposeGateLogic`?** → Sí, con sus dos suites.
Por qué: medido antes de borrar, sus dos únicos llamadores son las dos líneas de la card
(`shouldShowGroupsCard`, `shouldBlockSelection`); el «bloqueaba en producción» de su docblock era el tap
de esa card. Alternativa descartada: conservarlo «por si acaso» — no le queda ninguna decisión que tomar.

**D3 · ¿Qué textos se retiran?** → 7 keys de los 16 `.strings`, con sus accessors en `L10n.swift`: las 2
de la card, las 3 que solo pintaban las ramas solo-grupos del onboarding (título y subtítulo del paso de
moneda, frase del resumen) y las 2 del aviso del muro de iCloud, cuyo único uso era el `.alert` de la card.
Por qué: quitar el accessor hace que el compilador garantice que nadie más las usaba. Alternativa
descartada: solo las 2 de la card — dejaría 5 keys huérfanas que nadie pinta.

**D4 · ¿Qué pasa con `OnboardingGroupsOnlyGuardUITests`?** → Se reescribe y se renombra a
`OnboardingPurposeStepUITests`: (a) el paso muestra «Llevar el control» y «Solo anotar gastos» y no la de
grupos, con las positivas antes de la negativa; (b) el tap de vuelta de C5 se conserva saliendo de «Solo
anotar gastos», que salta el paso de cuentas, así que llegar a él prueba que el tap surtió efecto. Los dos
casos que elegían la card se van con ella.
Por qué renombrar: el nombre viejo describe un guard que ya no existe. Alternativa descartada: mantener el
nombre — un test llamado «GroupsOnlyGuard» que afirma que no hay card de grupos confunde a quien lo lea.

**D5 · ¿Y `SecondarySessionGateUITests.test_purposeStep_inSecondarySession_hidesGroupsOnlyCard`?** → Se
borra.
Por qué: su premisa (el gate oculta la card en visita) y su control positivo (el hermano que sí la veía)
desaparecen; la red del AC1 queda en el test nuevo, que corre sin seam. Alternativa descartada: dejarlo
con el docblock retocado — sería redundante en un fichero que el ticket 12 retira entero.

**D6 · ¿Cómo quedan los unitarios?** → Selección: 3 modos y 2 cards, más un pin
`OnboardingPurposeCard.allCases == [.control, .expenses]` (el AC1 a nivel de tipo). Plan de pasos y botón
«Siguiente»: pierden `groupsOnly` y sus casos. `GroupsGateLogicTests` y `GroupsOrganizerBranchTests`: 3
puertas, 48 celdas, 1 celda de alta, y el alta con **un** call-site (la pantalla del nombre de la puerta
A), que es la red real de «solo el Welcome lleva a solo-grupos».

**D7 · ¿Se retira también el guard de sesión secundaria de `advanceGroupsOrganizerFlow`?** → No. Se le
quita la línea del payload y se corrige su comentario.
Por qué: existía por la puerta B; sin ella es defensa en profundidad de la puerta A, y M1 entera se retira
en el ticket 12. Retirar un guard M1 aquí es ampliar a otro objeto. Se anota en el ticket 12.

**D8 · ¿Qué se hace con los docblocks que describen la card como viva?** → Se corrige solo la frase falsa
y se fecha; no se re-razona el diseño de nadie. El neutro durable del paso 5 pierde uno de sus recorridos
medidos, pero su motivo principal —durar todos los arranques— no depende de la card.

**D9 · ¿El ticket va a `done` o a `qa`?** → `done`.
Por qué: nada de esto necesita CloudKit ni sesión real. AC1 lo prueba el XCUITest nuevo; AC2 no cambia de
comportamiento (con el payload nulo la puerta A ya tomaba exactamente esta rama) y lo prueban
`WelcomeChooserUITests.testGroupsOrganizer_createCardWalksToTheGroupForm` y las tablas unitarias.

**D10 · ¿Review adversarial?** → Una lente independiente sobre el diff de la cadena, no tres.
Por qué: el runbook marca el paso «directo», pero el cambio toca el choke-point que comparte «Vengo por un
grupo» (AC2), que es el gancho de adquisición.

**D11 · ¿Qué corre el gate?** → Suite unitaria **entera** (regla 5 del runbook: el paso borra código),
XCUITest de las áreas cruzadas por lotes y en primer plano, y la paridad de `l10n-check`.

**D12 · ¿Qué fila de la matriz se marca?** → Ninguna: el paso propósito es detalle de pantalla dentro de
[P] y la matriz lo excluye a propósito. Se dice en el PR.
