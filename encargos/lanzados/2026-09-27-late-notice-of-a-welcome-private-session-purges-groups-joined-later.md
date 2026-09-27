# El aviso tardío de quien empezó en Welcome privado ya no se lleva los grupos a los que se unió después

## Contexto
Cola A autónoma Yala (riesgo real): tras PR #280 (activation-private-gate-leaves-a-late-notice-that-purges-groups), quien activa Yala completo ya no pierde grupos al «Empezar de cero» del aviso tardío. Queda el gemelo del Welcome: quien eligió «Es mi primera vez → privado» sin iCloud/red, se une a grupos después, y cuando iCloud vuelve el aviso «Encontramos datos tuyos» + «Empezar de cero» sí se lleva esos grupos (y la sesión de Grupos), aunque el copy solo nombre registros/cuentas/presupuestos.

Ticket: `tickets/backlog/late-notice-of-a-welcome-private-session-purges-groups-joined-later.md` (medium, groups/onboarding/modo-nube; hallazgo de #280; inferido por lectura, NO reproducido).

Rama base: `2.1` (ya trae #280). Arrancas en contexto limpio.

Horario diurno Lima: si hace falta AskUserQuestion de producto/acceso, úsala. Frank contesta por el canal (elige la opción robusta / recommended sin preguntar a Jürgen salvo device/secrets o decisión demasiado grave).

MODO AUTÓNOMO (norma Jürgen 2026-09-22, override vigente): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa de punta a punta hasta gate/PR/merge a 2.1 y `/cerrar-total` sin pedir permiso para continuar. Solo paras de verdad ante AskUserQuestion de producto/acceso o algo irreversible que no puedas asumir.

## Que se pide
1. Reproduce o confirma en código el camino Welcome privado → testigo de espejo tardío (`continueWithoutValidating`) → aviso tardío con `ICloudWipeScope.lateNotice(sessionBornFromFullActivation: false)` → borrado `.handover` que sube cambios de grupos, purga dominio local, sella y retira sesión de Grupos.
2. Arregla para que «Empezar de cero» del aviso tardío NO se lleve grupos a los que la persona se unió después de elegir privado. El copy y el alcance del wipe tienen que coincidir.
3. Si hay que separar «borrado a medias de la puerta Welcome (`.leaveForLateNotice`, posible dominio de otra persona)» vs «misma persona que se unió a grupos después», elige la opción robusta (buena práctica / recommended): no inventes un hecho durable frágil si no hace falta; documenta la decisión en el PR/ticket.
4. Tests que fijen el comportamiento (y que no rompan el caso de activación completa ya cubierto por #280).
5. Actualiza ticket → qa (o done si no pide device-QA) y `docs/TICKETS.md`. Si salen bugs/decisiones nuevas, créalos en `tickets/` antes de cerrar.
6. PR a `2.1`, merge cuando el gate lo permita, `/cerrar-total` al terminar (worktree propio).

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- prod Supabase; solo local/staging si toca nube
- No relances otros encargos ni pises el árbol principal de Jürgen
- No ensanches a Cola B (rediseño UI) ni a mediums Cola C post-2.1

## Como se sabe que esta bien
- Criterios del ticket cumplidos: «Empezar de cero» del aviso tardío no se lleva grupos unidos después de la elección privada; el copy no miente.
- Tests verdes del alcance; PR mergeado a `2.1`.
- Board al día (`tickets/` + `docs/TICKETS.md`); `/cerrar-total` limpio.
- Resumen de cierre en lenguaje de usuario (Cambiado / Encontrado / Necesita de ti si aplica).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** El testigo del espejo tardío solo lo escriben dos puertas: la del Welcome
(`continueWithoutValidating`) y la privada de la activación. La del Welcome sigue a `startFreshPrivateOnboarding`, que
solo arranca el onboarding privado con el teléfono vacío (`hasLocalDataNow` cuenta `SplitGroup`) o tras borrarlo con el
handover. ⇒ todo grupo que haya al salir el aviso con el corpus es de la persona de la sesión. El aviso comparte el arm y
«a medias» con la puerta del Welcome (`.handover`) y con la suya propia, y hoy nada dice cuál de los dos borrados está
pendiente.

**D1 · ¿Qué alcance tiene «Empezar de cero» del aviso con el corpus?** → `.importedRows` para todas las sesiones.
Por qué: la persona que contesta es la de la sesión y el copy solo nombra registros, cuentas y presupuestos. Alternativa
descartada: seguir decidiendo por de dónde nació la sesión (#280) — deja fuera justo al Welcome privado.

**D2 · ¿Cómo sabe el aviso, al TERMINAR un borrado (reanudación o «Terminar de borrar»), si es el del Welcome o el suyo?**
→ El borrado apunta su alcance al entrar (`performICloudCorpusWipe`, antes del primer `await`), como sub-estado del arm
que sobrevive a «a medias» y muere con los dos. Terminar = terminar el que se armó.
Por qué: es el único hecho que distingue los dos casos sin inventar fechas de unión a grupos; lo escribe quien sabe el
alcance y vive lo que vive el borrado. Alternativas descartadas: comparar la fecha de unión a cada grupo con la de la
elección privada (frágil, datos del canal); purgar nunca (dejaría sin sellar el dominio de la persona anterior en el
borrado a medias del Welcome).

**D3 · ¿Y un borrado pendiente sin apunte (armado por un build anterior)?** → El comportamiento de antes: de dónde nació
la sesión (`isBornFromFullActivation` ? `.importedRows` : `.handover`).
Por qué: no se puede saber qué borrado era, y el Welcome viejo tiene que seguir sellando. La marca de #280 se queda con
ese papel; retirarla es churn sin ganancia.

**D4 · ¿Cambia el copy?** → No. «Tus registros, tus cuentas y tus presupuestos» ya describe `.importedRows`.

**D5 · Las señales tras el borrado** → se re-miden siempre (`hasExistingData`, `hasPersonalData`). Por qué: el alcance
ya no se puede releer al terminar (sus marcas se retiran antes), y tras un handover la medida da `false` sola.

**D6 · Efecto de producto aceptado**: tras «Empezar de cero» del aviso, quien empezó en el Welcome privado vuelve al
onboarding personal con su nombre y divisa, no al Welcome, y conserva su sesión de Grupos (igual que quien activó, #280).

**D7 · Residual que no se toca**: el testigo no se retira al elegir «Restaurar» tras cancelar el alert del Welcome; en
ese rincón podría haber grupos de otra persona en el teléfono. Va a ticket, no a este PR.

**¿ADR?** No: es la mecánica de un borrado, y su sitio durable es la regla de área (`.claude/rules/swiftdata-cloudkit.md`),
que se actualiza en el mismo PR.
