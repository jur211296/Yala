---
id: 2026-11-25-oferta-pro-mes-gratis-y-mazo-centrado
status: done
priority: medium
area: "onboarding, primeros-pasos, pro, panel"
created: 2026-11-25
updated: 2026-11-26
source: "encargo 2026-11-25-oferta-pro-mes-gratis-en-final-y-mazo-centrado-con-saludo"
---

# El mes gratis de Pro dentro de «¡Primeros pasos completos!» y el mazo centrado con «Hola, <nombre>»

Decisión de Jürgen del 25-nov («C y B») sobre las maquetas de
`docs/propuestas/maquetas-oferta-pro-y-mazo-centrado-2026-11-25/`.

## Qué cambia para quien usa Yala

- **Oferta (C):** con derecho a la prueba, la tarjeta «¡Primeros pasos completos!» lleva dentro «YALA PRO · 1 MES GRATIS»,
  «Para seguir: prueba Yala Pro 1 mes gratis», los tres beneficios en una fila, «Empezar mi mes gratis» (abre la hoja
  «Prueba Yala Pro 1 mes gratis» con los planes), «Hoy no pagas · te avisamos antes de cobrar», y «Ahora no» (pliega la
  oferta) junto a «Cerrar» (quita la tarjeta). La hoja ya no sube sola encima al completar, y la tarjeta de Pro del Panel
  no sale a la vez. Sin derecho, todo como antes.
- **Tarjeta de Pro de los días siguientes:** con derecho, el texto de la maqueta A («1 MES GRATIS», «Prueba Yala Pro
  gratis 1 mes», «Empezar mes gratis»); el botón abre lo mismo que antes.
- **Mazo (B):** en el paso 1, el mazo va centrado con «Hola, <nombre>» y «Siete pasos cortos para dejar Yala a tu
  medida.»; sin nombre, «Hola». Al crear (u omitir) la cuenta, el saludo se funde y el mazo sube. Igual en «Solo gastos».

## Cómo se probó

- Unit: `YalaTests/OfertaProMazoCentrado/` (derecho, «Ahora no», hoja al completar, texto de A, nombre, centrado y los 16
  idiomas) más las suites de Primeros pasos y Pro que tocan estos ficheros.
- Interfaz: `YalaUITests/OfertaProMazoCentrado/` con `-uitest-fake-prices` (Yala Dev no tiene precios).
- Capturas antes/después en un simulador de iPhone 14, claro y oscuro.

## Lo que no se pudo ver

La oferta con derecho real solo sale con precios de la App Store (TestFlight o producción). En Yala Dev se vio con precios
fingidos.
