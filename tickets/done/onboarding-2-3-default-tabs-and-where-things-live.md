---
id: onboarding-2-3-default-tabs-and-where-things-live
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-pestanas-por-defecto-y-do-wn2z (docs/onboarding-2-3/SPEC.md, Y23-15)
qa-status: passed
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - barra nueva y guia de dias despues vistas en pantalla por XCUITest con capturas
---
# Bienvenida 2.3 · Pestañas por defecto y «dónde vive cada cosa» (Y23-15)

Una instalación nueva ve Panel · Grupos · Registros, más «Más» y Buscar. Presupuestos, Pagos planificados y
Estadísticas viven en Más. Quien ya usaba Yala sigue con su barra: en el primer arranque con este código, a quien
terminó el alta y nunca tocó sus pestañas se le escribe la de antes (Panel · Estadísticas · Planificación); quien las
configuró no se toca (`TabBarDefaultsMigration`).

«Días después»: una sola vez, en una instalación nueva de 2.3, cuando hay registros en dos días distintos: «Arma tu
Panel» sobre Configurar Panel (1 de 2), «Tus gráficas viven en Más» sobre la pestaña Más (2 de 2) y, al tocarla, Más
con el foco en Estadísticas («Todas tus gráficas»). Terminarla da por hecho el paso 6 de Primeros pasos.

Las guías al terminar los pasos 3, 4 y 5 (presupuestos y pagos → Más; grupos → su pestaña) quedan en el catálogo
`PlaceGuide` con los textos del prototipo; las arrancan sus lotes con `PlaceGuideCenter.shared.start(_:)`.

Pruebas: `YalaTests/Bienvenida23BaseTests` (TabBarDefaults23Tests, TabBarDefaults23WiringTests, PlaceGuide23Tests) y
`YalaUITests/Flows/Bienvenida23BaseUITests` (barra nueva, recorrido de la guía, texto grande).
