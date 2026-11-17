---
id: 2026-11-17-pagos-que-se-repiten-banner-y-hoja
status: done
priority: medium
area: "scheduled-payments, recurring-proposals"
created: 2026-11-17
updated: 2026-11-17
source: "Jürgen, 17-nov 15:52 Lima, captura de TestFlight 2.3"
---

# Pagos que se repiten: banner, hoja grande y formulario completo

A Jürgen no le gustaba la tarjeta «Pagos que se repiten» con la lista entera arriba de Pagos planificados.

## Qué cambia para quien usa la app

1. Arriba de Pagos planificados sale un **banner** de una frase: «Encontramos 3 pagos que se repiten. Puedes agregarlos
   a tus pagos planificados.» (plural correcto en los 16 idiomas). Desaparece cuando no queda nada por responder.
2. Al tocarlo se abre una **hoja grande** titulada «Pagos que se repiten» con todos los casos: nombre, cada cuánto y qué
   día, cuenta, moneda y monto, como antes.
3. Tocar un caso abre el **formulario completo de «Nuevo pago planificado»** (el mismo de «+ Nuevo pago planificado»),
   prellenado: nombre, monto, moneda, cuenta, categoría, cada mes o cada semana, el día, suscripción si es una marca
   conocida y «monto variable» si cambia de un cobro a otro. Al guardar, el caso sale de la lista y sale el aviso de
   siempre con «Ver».
4. **Descartar** se hace deslizando la fila o desde su menú: «No es fijo» y «Ahora no», como antes. «Ajustes de las
   propuestas» pasa al menú «···» de la hoja. Si no queda nada, la hoja se cierra sola.

## Decidido sin consultar

- El formulario completo vive fuera de `toca`: su prellenado gana cuatro campos opcionales (frecuencia, día,
  suscripción, monto variable) y enseña la moneda que va a guardar (antes, la de la cuenta aunque guardara la del
  prellenado: una suscripción en dólares en una tarjeta en soles decía «PEN» y guardaba USD).
- El aviso del pago queda en lo que propone el formulario (3 días antes), no en el «1 día antes» de la hoja vieja.
- La hoja propia de la propuesta se retiró con sus textos.

## Hecho cuando

Banner, hoja y formulario prellenado en el iPhone 14 con un historial de cobros mensuales, en claro, oscuro y girado.
Tests: `YalaTests/PagosRecurrentesBanner/`.
