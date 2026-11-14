Yala
# Puerta de Grupos, las tres preguntas completas al recuperar datos y Primeros pasos en el iPhone 14
---
card: tablero-puerta-de-grupos-tres-cosas-que-conviene-8z4t
toca: Yala/App/Views/Settings/CloudConsentView.swift, Yala/App/Views/Onboarding/WelcomeConversationView.swift, Yala/App/Logic/PrimerosPasosPlanningLogic.swift, Yala/App/Logic/PrimerosPasosPlanningCreator.swift, Yala/App/Tips/PlaceGuide.swift, Yala/App/Views/Panel/SetupChecklistCard.swift, Yala/App/Views/Panel/PrimerosPasosPanelPresentations.swift, Yala/App/Views/Panel/PanelSheetsModifier.swift, Yala/App/Views/GroupsDoor/, Yala/Utils/L10n.swift, Yala/Utils/L10n+Bienvenida23Alta.swift, Yala/Resources/de.lproj/Localizable.strings, Yala/Resources/en-GB.lproj/Localizable.strings, Yala/Resources/en.lproj/Localizable.strings, Yala/Resources/es-419.lproj/Localizable.strings, Yala/Resources/es-AR.lproj/Localizable.strings, Yala/Resources/es-ES.lproj/Localizable.strings, Yala/Resources/es.lproj/Localizable.strings, Yala/Resources/fr.lproj/Localizable.strings, Yala/Resources/it.lproj/Localizable.strings, Yala/Resources/ja.lproj/Localizable.strings, Yala/Resources/nl.lproj/Localizable.strings, Yala/Resources/pl.lproj/Localizable.strings, Yala/Resources/pt-BR.lproj/Localizable.strings, Yala/Resources/pt-PT.lproj/Localizable.strings, Yala/Resources/pt.lproj/Localizable.strings, Yala/Resources/zh-Hans.lproj/Localizable.strings, YalaTests/GroupsDoorAndFirstSteps/, tickets/backlog/groups-door-three-questions-first-steps.md, tickets/done/groups-door-three-questions-first-steps.md
esfuerzo: medium
cierre: cierra-sola
---

Lote chico de bugs del recorrido de la bienvenida en el iPhone 14 (13-nov), reportados por Jürgen. Lee cada card entera.

1. `tablero-puerta-de-grupos-tres-cosas-que-conviene-8z4t`: desde la puerta de Grupos, «¡Hola de nuevo!» no muestra iCloud (Grupos no tiene iCloud), y las «tres cosas que conviene saber» van en otra hoja, con otro diseño y antes de elegir la cuenta.
2. `tablero-quien-recupera-sus-datos-no-pasa-por-las-ptuf`: quien recupera sus datos pasa por las tres preguntas completas (nombre, moneda, qué llevar), no a medias.
3. `tablero-primeros-pasos-en-el-iphone-14-la-hoja-c-hara`: en el iPhone 14 la hoja corta el séptimo paso y los avisos se apilan; el tutorial de la Bandeja dice 4 pasos con 6 puntos; las páginas del paso 7 más lentas. «¡Primeros pasos completos!» aunque se omitan pasos se queda como está.

**Pruebas:** de punta a punta en el iPhone 14 por DeviceMCP (conectado a la Mini; ya no tenemos las limitaciones del simulador). Si el iPhone está ocupado, usa un segundo simulador. Tests que fallen sin el arreglo, en la subcarpeta propia de `toca:`. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR. Hay PR abiertos de la bienvenida y de «entrar con la cuenta a medias» contra 2.3: rebasa sobre lo último antes de abrir el tuyo.

**Entrega:** un PR contra 2.3 (la 2.2 está cerrada), mergeado si CI pasa, el ticket en done y las cards en QA. Commits y PR sin firma de IA. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Lo vital (acceso, datos del servidor, seguridad) se pregunta según el modo de la sesión. Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, modo nocturno)

Fuente: las tres cards y `docs/qa/recorrido-bienvenida-2026-11-13/escenarios.json` (E01, E03, E13, E14). El artifact del recorrido no se pudo leer.

1. **«¡Hola de nuevo!» desde la puerta de Grupos** → sin «Restaurar desde iCloud» y sin la nota «La que usaste en este dispositivo» (el faro habla de la cuenta personal de este Apple ID, no del último acceso del teléfono). Si no hay entradas a una cuenta visibles, se queda lo que había. La marca de la puerta es `WelcomeGroupsDoorLanding` (sobrevive al remontaje del contenedor).
2. **Un solo diseño y un solo momento para «tres cosas que conviene saber»** → las entradas Apple/Google de «¡Hola de nuevo!» y la vuelta de la puerta de la entrada con otra cuenta van por el acceso único de la vitrina (`.unified`): firma, verifica y el consentimiento va dentro de «¿Cargamos tus datos…?» / «Vamos a crear tu cuenta». Se retira la hoja aparte antes de elegir la cuenta. Sin cuenta, ahora sale «Vamos a crear tu cuenta» en vez de «No encontramos una cuenta», igual que en la vitrina.
3. **Tres preguntas enteras al recuperar datos** (nota de Jürgen: «que pregunte todo, no a medias», manda sobre el «hecha cuando» de la card, escrito antes) → la conversación no propone nada del resumen restaurado: nombre (el del proveedor si lo hay) y moneda de la región, como a cualquiera. El camino «resumen completo → directo a la app» no cambia.
4. **«Ver los 7 pasos»** (decisión de Jürgen 16:15) → abre grande; cualquier paso sin hacer (pendiente u omitido) se abre tocándolo; los hechos no. Se abre al terminar de cerrarse la hoja.
5. **Guías apiladas** → arrancar una guía de foco retira para siempre la tarjeta «Este es tu resumen» del Panel (como su X).
6. **Paso 7 más lento** → 6 s por parte en «Anota sin abrir Yala» (antes 3,4 s); las demás páginas cortas siguen igual.
7. **Tutorial de la Bandeja «4 pasos» con 6 puntos** → los puntos de los tutoriales de la biblioteca son sus pasos (sin portada ni final): vale para todos.
8. **Fuera de alcance (a «Encontrado»)**: tutorial del correo en la biblioteca (función nueva), nota de Gmail bajo «Listo» (se lee al desplazar), «¡Primeros pasos completos!» aunque se omitan (Jürgen: se queda).
9. Ficheros fuera de `toca:` con cambio mínimo: `WelcomeFlowContainer`, `WelcomeAccountChoiceLogic`, `ContentView`, `SetupStepsListSheet`, `TutorialStoryPage`, `HomeScreenTutorialFlowView`, `TutorialDetailView`, y los tests que fijaban el comportamiento viejo.
