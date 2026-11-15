---
id: onboarding-2-3-getting-started-complete-and-pro-trial
status: qa
priority: high
area: onboarding, pro
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-final-primeros-pasos-comp-l1c5 (docs/onboarding-2-3/SPEC.md, Y23-18)
qa-status: partial
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - tarjeta «¡Primeros pasos completos!» con chispas, la oferta a los 1,6 s con el anual preseleccionado y la línea de tiempo, «Seguir con la versión gratis» sin Pro y la compra fingida con «¡Listo! Tienes Pro» y Voz/Foto/Yala IA sin candado; XCUITest y unit. Falta con la App Store de verdad (TestFlight + Sandbox): la hoja de pago real y el aviso del día antes del cobro
---
# Bienvenida 2.3 · Final · Primeros pasos completos y prueba de Pro (Y23-18)

- Con el mazo resuelto desaparece y queda «¡Primeros pasos completos!» con chispas y «Cerrar».
- A los 1,6 s (0,2 s con Reducir movimiento) sube la oferta por el router de siempre, con su diseño propio
  (`SetupCompleteTrialOfferSheet`): título con la duración real, los seis beneficios de la app (títulos `uxpro.feature.*`),
  Anual preseleccionado con «El más elegido» y «Sale más barato por mes», Mensual, precios reales de StoreKit, línea de
  tiempo Hoy · <día del aviso> · <día del cobro>, «Empezar mi mes gratis» y «Seguir con la versión gratis».
- Solo la hoja de pago de Apple da Pro (3.1.2). Con la compra confirmada: «¡Listo! Tienes Pro» con hasta cuándo va la
  prueba (la fecha de Apple) y, si quedó agendado, «El … te avisamos, antes de cualquier cobro»: un aviso local dos días
  antes del cobro a las 10:00.
- **Sin permiso de avisos no se promete el aviso** (decisión de Jürgen del 12-nov, opción A): la línea de tiempo quita ese
  paso y el «¡Listo!» dice solo hasta cuándo va la prueba. El permiso de iOS se sigue pidiendo solo al elegir «sí,
  recuérdame» (Y23-17), sin provisional: el provisional apagaba después la pregunta de los avisos de pagos y presupuestos.
- El aviso prometido se repone si un borrado de datos o un cierre de sesión lo quitan, y se retira si la prueba se cancela
  o termina (se reconcilia con cada cambio de la suscripción). «Restaurar compras» no promete prueba ni aviso.
- «Seguir con la versión gratis» no regala nada; los momentos de valor (Voz con candado, límite de presupuestos) siguen
  como estaban. La oferta de tras guardar un registro sigue con su hoja de 2.2.

**Aviso: la ficha dice «30 días» y la app dice «1 mes».** La prueba de la App Store es de un mes (P1M; Apple no admite
30 días exactos) y Jürgen confirmó el 12-nov su decisión D21: se anuncia «1 mes» con las fechas reales. Así, «Día 28 /
Día 30» del prototipo pasa a ser la fecha del aviso y la del cobro.

## Guion de QA en el iPhone 14 (TestFlight, cuenta Sandbox, instalación nueva)

Yala Dev no activa Pro con una compra real, así que esto va con el build de TestFlight.

1. Ajustes del iPhone › App Store › Cuenta de Sandbox: entra con el tester de Sandbox del iPhone 14.
2. Borra Yala, instala el build de TestFlight y entra. Resuelve los siete pasos de Primeros pasos (puedes omitirlos).
3. Al resolver el último: tarjeta «¡Primeros pasos completos!» y, un segundo y medio después, «Prueba Yala Pro 1 mes
   gratis» con Anual marcado y precios en tu moneda. Revisa que las dos fechas de la línea de tiempo cuadren con hoy + 1
   mes.
4. Toca «Empezar mi mes gratis»: tiene que salir la hoja de pago de Apple. Ciérrala sin confirmar: no debe haber Pro
   (Voz sigue con candado).
5. Vuelve a tocar y confirma: «¡Listo! Tienes Pro»; «Empezar a usarlo»; Voz y Foto sin candado. En Sandbox un mes dura
   5 minutos, así que la fecha de «va hasta el …» sale con la de hoy: es lo esperado.
6. Al confirmar no debe salir el diálogo de permisos de iOS. Con los avisos sin permitir, la línea de tiempo no trae el
   paso del aviso. El aviso de antes del cobro no se puede ver en Sandbox (su fecha ya pasó); lo cubren los tests.

Pruebas: `YalaTests/Bienvenida23FinalTests` (offer_*, reminder_*) y
`YalaUITests/Flows/Bienvenida23FinalUITests#test_final_offer_keepFree_closesWithoutPro` /
`#test_final_offer_confirmedPurchase_showsProIsOn`.
