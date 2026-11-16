---
id: onboarding-2-3-first-account-questions
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-1-crear-la-primera-c-1771 (docs/onboarding-2-3/SPEC.md, Y23-07)
qa-status: passed
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - página corta, tipo, moneda, nombre, saldo, cierre, pago, recordatorio y ¡Lista! recorridos por XCUITest con capturas; tarjeta en soles y dólares con su línea y su saldo, por test unitario
---
# Bienvenida 2.3 · Paso 1 · Crear la primera cuenta (Y23-07)

«Crea tu primera cuenta» del mazo abre la página corta «qué son las cuentas» (tres partes cada 3,4 s, quietas con
Reducir movimiento o VoiceOver; «Crear mi primera cuenta» siempre a la vista) y después preguntas con la tarjeta de la
cuenta llenándose arriba: tipo (Efectivo, Cuenta corriente, Ahorros, Tarjeta de crédito, Todo junto) → moneda (la del
alta ya puesta y «+ Añadir moneda», hasta 4, ANTES de guardar) → nombre (lo escribe en corriente, ahorros y tarjeta;
en efectivo y Todo junto se propone «Efectivo» / «Mi dinero») → saldo por moneda (signo + / − fuera de tarjeta, «No sé,
ayúdame a sacarlo», «Empiezo en 0» / «No debo nada») → en tarjeta, día de cierre, día de pago («No lo sé» / «Prefiero no
decirlo») y recordatorio 0/1/3/5 días o «No me lo recuerdes» (sin día de cierre, solo el mismo día; sin día de pago se
salta) → ¡Lista! con «Ver mi Yala» y «Crear otra cuenta».

Se guarda con las piezas de la app: cuenta principal, saldo inicial, una línea por cada otra moneda (`parentAccountID`)
con su saldo, y en tarjeta los días y el recordatorio (lo programa `CreditCardReminderScheduler`). El permiso de
notificaciones se pide solo si se eligió un recordatorio (Y23-17).

Fuera de alcance (ficha): número de cuenta y «Excluir de las estadísticas» siguen en Editar cuenta.

Pruebas: `YalaTests/Bienvenida23PasosTests` (FirstAccountFlowLogicTests), `YalaTests/Bienvenida23PasosCuentaTests` y
`YalaUITests/Flows/Bienvenida23PasosUITests#test_step1_card_withDaysAndReminder_thenDeckMovesToStep2`.
