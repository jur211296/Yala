---
id: onboarding-2-3-arrival-and-getting-started-deck
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-llegada-y-mazo-de-primero-nkwu (docs/onboarding-2-3/SPEC.md, Y23-05)
qa-status: passed
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - mazo 1 de 7, cartas que asoman y lista de 7 pasos vistos por XCUITest con capturas
---
# Bienvenida 2.3 · Llegada y mazo de «Primeros pasos» (Y23-05)

«Primeros pasos» deja de ser una lista con barra de progreso y pasa a ser un mazo: adelante el paso actual
(«Primeros pasos · N de 7» y su nombre, en el color de la app) y asomando detrás los dos siguientes que faltan
(«Después: …», «Luego: …»). «Ver los 7 pasos» abre la lista con los hechos marcados y «Seguir donde iba». El mazo
avanza al completar u omitir el paso de adelante y desaparece al resolver el séptimo.

Orden de la ficha: cuenta, registrar, presupuesto, pagos fijos, grupo, a dónde va el dinero, pantalla de inicio. Lo
avanzado en 2.2 cuenta (claves 2, 3 y 4). «Conoce todo lo que puedes personalizar» y «Conoce Yala Pro» salen del mazo;
voz y foto quedan como prácticas dentro de «Aprender a registrar».

Llegada: en una instalación nueva de 2.3, mientras «Aprender a registrar» no esté hecho u omitido, el mazo es la única
acción del Panel; después va debajo de Nuevo registro, Voz, Foto y Yala IA, fuera del carrusel de avisos. Con «Solo
gastos», en ese tramo, «Anotar el primer gasto».

Hasta que lleguen los flujos guiados (Y23-07 a Y23-16), cada paso abre lo que ya existe: formulario de cuenta, Nuevo
registro, editor de presupuesto, editor de pago, pestaña Grupos, guía de gráficas y Ajustes › Tutoriales.

Pruebas: `YalaTests/Bienvenida23BaseTests` (SetupDeck23Tests), `SetupChecklistManagerTests` y
`YalaUITests/Flows/Bienvenida23BaseUITests`.
