---
id: 2026-11-20-oferta-pro-primeros-pasos-mas-beneficios-maquetas
status: done
priority: medium
area: "onboarding, primeros-pasos, pro"
created: 2026-11-20
updated: 2026-11-20
source: "encargo 2026-11-20-oferta-pro-final-primeros-pasos-mas-beneficios-maquetas"
---

# Maquetas: la oferta Pro del final de Primeros pasos, con más beneficios y «Ver todos»

Sesión de maquetas: no cambia código de la app. Entrega: artifact «Oferta Pro: más beneficios»
(https://claude.ai/artifact/62MFq13V23S7oVQY83gnWu, público) y su copia en `docs/maquetas/oferta-pro-primeros-pasos/`
(página, 28 capturas y el parche del arnés).

## Qué decide Jürgen (con la recomendación)

**Opción de la hoja**: **A cuatro bloques en una tarjeta (recomendada)** · B rejilla de ocho fichas · C lo probado y
«Y además». La elección se guarda en la base del artifact (colección `decisiones`, documento `opcion`: `opcion` y
`nota`). El destino de «Ver todos los beneficios» es el mismo en las tres: una página nueva «Qué incluye Yala Pro»
(Gratis frente a Pro) empujada dentro de la hoja. Implementación: `tickets/backlog/2026-11-20-oferta-pro-primeros-pasos-mas-beneficios.md`.

## Medido

- Simulador iOS 27.2, build Debug de 2.3, con `-uitest -uitest-skip-onboarding -uitest-seed cuenta-con-movimientos
  -uitest-show-setup-deck -uitest-setup-deck-at 8 -uitest-fake-prices eligible` y `-userTheme 1|2`. Las variantes, con
  el arnés `-mockOffer A|B|C` (`-mockOfferAll` empuja la página). iPhone SE 3.ª gen., 17 Pro y 17 Pro Max.
- Borde de abajo de cada pieza frente al de arriba del botón fijo, en pt de pantalla:

  | | SE (botón 605) | 17 Pro (778) | Pro Max (860) |
  |---|---|---|---|
  | Hoy · beneficios / planes / fechas | 417 / 602 / 636 | 435 / 620 / 654 | 439 / 624 / 658 |
  | A | 419 / 600 / 630 | 459 / 640 / 670 | 463 / 644 / 674 |
  | B | 523 / 708 / 742 | 555 / 740 / 774 | 554 / 739 / 773 |
  | C | 540 / 726 / 760 | 558 / 743 / 777 | 562 / 747 / 781 |

  En el SE, A deja los dos planes a la vista, como hoy (necesitó filas de 6 pt de aire y 4 pt en la cabecera; con 8
  el mensual quedaba 3 pt bajo el botón). B y C dejan el anual a medias y el mensual fuera.
- A AX3 (17 Pro) la oferta A se desplaza y no corta nada; el icono de cada bloque se queda a la izquierda.
- Las ocho puertas Pro salen de `FeatureGateService.ProFeature`, `AppTheme.isPro` y `AppIconOption.isPremium`.

## Encontrado

- La web promete en Pro tres cosas que la app no tiene: `tickets/backlog/2026-11-20-web-promete-beneficios-pro-que-la-app-no-tiene.md`.
- En el SE, el título de hoy se parte en «Prueba Yala Pro 1 / mes gratis» (el «1» queda solo al final de la línea).
  Lo resuelve la opción A, que usa un título más pequeño.
