---
id: onboarding-2-3-first-scheduled-payment-questions
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-4-primer-pago-planif-s5nd (docs/onboarding-2-3/SPEC.md, Y23-12)
qa-status: passed
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - página corta, tipo (Servicios), nombre precargado con ejemplo, monto estimado, día 15, aviso 3 días antes, ¿En tu Panel?, ¡Listo! con «Anotar otro pago», guía de Más y mazo en el paso 5, recorridos por XCUITest con capturas; lo que se guarda, por test unitario
---
# Bienvenida 2.3 · Paso 4 · Primer pago planificado (Y23-12)

«Anota tus pagos fijos» del mazo abre la página corta (Lo que pagas cada mes · Llega a tu Bandeja · Te avisamos antes,
con el texto real del aviso de pago) con «Anotar mi primer pago» y «Omitir este paso».

Cinco pantallas con la fila del pago llenándose arriba: ¿Qué pagas cada cierto tiempo? (seis subcategorías del seed con
nombre corto: Renta, Servicios, Comunicación, Suscripción de utilidad, Suscripción de ocio, Fitness; «Otra subcategoría»
abre el selector de subcategoría de la app, con rejilla de 4 y buscador, y la elegida queda como tarjeta con «Cambiar»;
«Es una suscripción» encendido en las dos de suscripción) → nombre y monto (nombre precargado con el tipo, ejemplos para
tocar, «Cambia cada vez» encendido en Servicios) → ¿Cuándo toca pagar? (Cada mes con el día, Cada semana con el día, Cada
año y Una vez con fecha) → ¿Te avisamos antes de que toque pagar? (3 días antes por defecto, 1 día antes, el mismo día,
No) → ¿Lo ponemos en tu Panel? → ¡Listo! («El 15 de noviembre llegará a tu Bandeja para que lo apruebes») con «Anotar
otro pago». La tarjeta lleva el resumen del editor («≈ S/ 80.00 cada mes, el día 15. Primer pago: …»).

Se guarda con el ViewModel del editor (`ScheduledPaymentEditorViewModel.savePayment`): subcategoría, monto (estimado o
no), suscripción, frecuencia, día, un aviso, y la cuenta de la última vez. Elegir aviso pide las notificaciones con el
reintento de Y23-17 (hoja «¿Te avisamos antes de cada pago?» si iOS nunca preguntó; «Activa las notificaciones» con «Ir a
Configuración» si se negó). Si dijo que sí al Panel, la sección Planificación enseña el widget de Pagos planificados. Al
cerrar: el paso queda hecho, guía «Tus pagos planificados viven en Más» y el mazo en el paso 5.

Fuera de alcance (ficha): «Cada N», los plazos de 2, 5, 7, 14 y 30 días y el gasto compartido (siguen en el editor).

Pruebas: `YalaTests/Bienvenida23PasosPlanificacionTests`, `YalaTests/Bienvenida23PasosPlanificacionGuardadoTests` y
`YalaUITests/Flows/Bienvenida23PlanificacionUITests#test_step4_paymentUtilities_monthly_reminder_thenDeckMovesToStep5`.
