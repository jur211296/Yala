Yala
# Primeros pasos para «Solo gastos» y Panel progresivo sin guía ni coach tips
---
toca: Yala/App/Logic/SetupDeckLogic.swift,Yala/App/Logic/OnboardingStepPlan.swift,Yala/App/Logic/PrimerosPasosPlanningLogic.swift,Yala/App/Logic/PrimerosPasosPlanningCreator.swift,Yala/App/Logic/UsageModeLogic.swift,Yala/App/Services/UsageModeService.swift,Yala/App/Views/Panel/SetupChecklistCard.swift,Yala/App/Views/Panel/PrimerosPasosPanelPresentations.swift,Yala/App/Views/Panel/PrimerosPasosHomeScreenPresentation.swift,Yala/App/Views/Panel/PrimerosPasosPlanningPresentations.swift,Yala/App/Views/Panel/PanelView.swift,Yala/App/Views/Panel/PanelAccountsSection.swift,Yala/App/Views/Panel/PanelFilterAndWidgetsSection.swift,Yala/App/Views/Panel/PanelWidgetSection.swift,Yala/App/Views/Panel/Sections/,Yala/App/Tips/,Yala/App/Logic/ReturningUserBeginnerTips.swift,YalaTests/SoloGastosPrimerosPasos/,YalaTests/PanelProgresivo/,tickets/backlog/2026-11-19-solo-gastos-primeros-pasos.md,tickets/done/2026-11-19-solo-gastos-primeros-pasos.md,tickets/backlog/2026-11-19-panel-progresivo-primeros-pasos.md,tickets/done/2026-11-19-panel-progresivo-primeros-pasos.md,docs/TICKETS.md
esfuerzo: high
cierre: cierra-sola
depende:
---

Rama base: 2.3. Dos temas que Jürgen vio en la build 2.3 (5) creando una cuenta de cero en iCloud privado. Un solo PR y un solo cierre.

## 1. «Solo gastos» no tiene Primeros pasos
Jürgen, 19-nov 21:35: cuenta nueva en iCloud privado, eligió «Solo gastos» y no aparecen los Primeros pasos. Deberían ser los mismos que en el onboarding normal («Yala completo»), con algunas modificaciones.
- Revisa cómo se arma el mazo y la lista de Primeros pasos (`SetupDeckLogic`, `OnboardingStepPlan`, `PrimerosPasos*`, `SetupChecklistCard`) y por qué en «Solo gastos» no sale (por ejemplo, porque cuelga del Panel o de un modo que «Solo gastos» esconde). Encuentra la causa de fondo.
- Arma los Primeros pasos de «Solo gastos» con los mismos pasos del normal, adaptados: quita o cambia solo los que apuntan a algo que este modo no muestra (por ejemplo Presupuestos, Grupos o Panel, si aplica) y conserva lo demás, igual en orden y estilo. Como Jürgen no detalló las modificaciones, decide con tu recomendación, anótalo en «Decidido sin consultar» y muestra en el artifact la lista del modo normal junto a la de «Solo gastos», paso por paso, con el motivo de cada cambio, para que la revise.
- Verifica también qué pasa al cambiar de modo después (de «Solo gastos» a completo y al revés) con los pasos ya hechos.
- Card: «“Solo gastos” no tiene Primeros pasos: deberían ser los del onboarding normal, adaptados». Ticket `tickets/backlog/2026-11-19-solo-gastos-primeros-pasos.md`.

## 2. Panel progresivo durante los Primeros pasos (acuerdo ya tomado)
Jürgen, 19-nov 21:45, para «Ingresos y gastos» y «Solo gastos». Esto ya se había acordado, así que no es diseño abierto:
- Al entrar por primera vez SOLO se ven los Primeros pasos. No aparecen la guía, «Tus finanzas» ni ningún widget.
- Después del primer paso (primera cuenta), aparece esa cuenta en «Tus finanzas» y nada más.
- Después del paso de registro, aparece el widget «Últimos registros» y nada más.
- Después de los pasos de presupuesto y de pago planificado, aparecen sus widgets, solo si el usuario eligió añadirlos al Panel.
- Durante estos pasos aparecieron coach tips que no deberían salir (ver `Yala/App/Tips/`, `ReturningUserBeginnerTips`, la guía del Panel). Durante los Primeros pasos no sale ningún coach tip ni guía.
Jürgen quiere analizar cada paso en detalle para ver qué se está colando y cuándo. Recorre en el simulador, desde una cuenta nueva, los dos modos y también Modo Nube e iCloud privado si cambia algo. Captura el Panel antes del primer paso, después de cada paso y al terminar. En cada captura anota todo lo que se ve (secciones, widgets, tips, banners, guía) y qué condición lo hace aparecer. Después corrige lo que no calce con el acuerdo y vuelve a capturar. El artifact muestra dos líneas de tiempo por modo, antes y después del arreglo, con cada intruso marcado y su causa. Si ves un caso que el acuerdo no cubre (por ejemplo, un banner de Modo Nube o de Siri), decide con tu recomendación y anótalo; si cambia el diseño de forma importante, es decisión vital.
- Card: «Panel progresivo en Primeros pasos: solo aparece lo que ya se completó, sin guía ni coach tips».

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Tests en `YalaTests/SoloGastosPrimerosPasos/` y `YalaTests/PanelProgresivo/`.
- Corren otras sesiones de Yala sobre `Yala/App/Views/SignOut/`, `Yala/App/Views/Profile/`, `Yala/App/Views/Onboarding/`, `Yala/App/Views/Settings/`, `Yala/App/Views/Planning/` y `Yala/Services/CloudSync/EntityApplyMap.swift`/`EntityEmissionMap.swift`: no los toques. Si el arreglo necesita otro archivo fuera de `toca:`, anótalo en «Decidido sin consultar» y mantenlo mínimo.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después, comparación de los Primeros pasos), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 (Frank, 2026-11-20, nocturno: auto-contestado)

**Causa medida de «Solo gastos» sin Primeros pasos:** `PanelView.setupDeckSlot` cambia el mazo por un botón suelto
«Anotar el primer gasto» (`SetupFirstExpenseAction`) mientras dura la llegada tranquila en «Solo gastos». Venía de la
ficha Y23-05 («Con Solo gastos: Anotar el primer gasto…»). El mazo solo salía después del primer gasto, ya en el paso 3.

Decisiones (todas reversibles, ninguna vital):
1. **«Solo gastos» usa el mismo mazo de 7 y en el mismo orden.** El paso 1 queda hecho solo porque Yala crea «Gastos
   Soles»; en «Ver los 7 pasos» su línea dice eso. No se quita: los flujos de cada paso (Onboarding/, de otra sesión)
   dicen «2 de 7», «6 de 7», «7 de 7», y un mazo de 6 los contradiría. Los otros seis ya trabajan solo con gastos.
2. **Panel progresivo**: con el mazo a medias, el Panel enseña solo lo que el usuario completó. Cuentas tras el paso 1
   («Ingresos y gastos») o tras el paso 2 («Solo gastos», porque el paso 1 no lo hizo la persona). «Últimos registros»
   tras el paso 2. Presupuestos y Pagos planificados solo si dijo «Sí» en su paso. Nada más: ni salud, ni tendencias,
   ni barra de filtros, ni la tarjeta de cambio de divisas.
3. **El saludo y el saldo en cero se quedan**: son la «llegada tranquila» de la ficha Y23-05.
4. **Avisos**: se callan la guía del Panel, la oferta Pro periódica, el aviso de grupos y el de Siri. Siguen los que
   hablan de los datos (nube, cuenta caducada, movimientos sin cuenta, actualización disponible).
5. **Guías y coach tips**: fuera durante el mazo las guías de cada pantalla, la de «días después», el tour Pro del
   Panel, el de tasa de cambio y los consejos de TipKit. Se quedan las guías que SON parte de un paso (la Bandeja al
   cerrar el 2, Más en el 3, 4 y 6, Grupos en el 5): las abre el paso que la persona tocó.
6. Fuera de `toca:` mínimos: `SetupChecklistManager` (estado del mazo), `PanelViewModel` no se toca,
   `ContextualGuideBanner` (una condición), `SetupStepRow`/`SetupStepsListSheet` (línea del paso 1).
