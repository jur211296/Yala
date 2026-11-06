---
id: scheduled-payments-real-brand-logos
status: backlog
priority: medium
area: "planning, scheduled-payments, legal"
created: 2026-11-06
updated: 2026-11-06
card: tablero-pagos-planificados-logos-reales-de-las-m-so2o
source: "decisión de Jürgen sobre el lote de productividad 2.3 (PR #824)"
---

# Pagos planificados: logos reales de las marcas

## Qué se decidió

Jürgen, 2026-11-06: los pagos planificados deben llevar los **logos reales** de las marcas (imágenes), no solo el
distintivo propio de Yala (iniciales sobre el color de marca) que salió en el PR #824. Va en esta card y no en aquel
PR porque antes hay que **revisar licencias**: usar la marca de un tercero dentro de la app puede pedir permiso o
seguir sus guías de uso.

## Qué falta

1. Revisar, servicio por servicio del catálogo (40), si su guía de marca permite mostrar el logo en una app de
   terceros y con qué condiciones. Lo que no se pueda, se queda con el distintivo propio.
2. Decidir de dónde salen las imágenes: empaquetadas en la app o descargadas.
3. Sustituir el distintivo por la imagen donde se permita: lista, línea de tiempo, calendario y editor.

## Punto de partida

`SubscriptionBrandCatalog` (ids estables) y `SubscriptionBrandBadge`. El campo `ScheduledPayment.brandLogoID` guarda
el id de catálogo, no la imagen: no hace falta otro campo de iCloud.

## Hecho cuando

Los servicios con licencia revisada enseñan su logo real, los demás siguen con el distintivo, y la revisión de
licencias queda escrita en el ticket.
