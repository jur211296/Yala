---
id: scheduled-payments-show-subscription-logos
status: qa
priority: medium
area: "planning, scheduled-payments"
created: 2026-11-06
updated: 2026-11-06
card: tablero-logos-de-suscripcion-en-pagos-planificad-9nn7
source: "encargo lote de productividad 2.3 (hormiga, logos, sugerencias)"
---

# Logos de suscripción en los pagos planificados

## Qué cambia para la persona

Al escribir el nombre de un pago conocido (Netflix, Spotify, Disney+, iCloud+… 40 servicios), el editor propone su
**logo**: las iniciales del servicio sobre su color de marca. La fila nueva **Logo** deja cambiarlo por otro servicio,
quitarlo («Sin logo») o volver al automático. El logo se ve en la **lista**, en la **línea de tiempo** (delante del
nombre) y en el **calendario** (un círculo con la inicial y un aro del color del estado: pagado, vencido, pendiente).
Los pagos de antes con un nombre conocido lo muestran solos.

No son imágenes de las marcas: es un distintivo propio de Yala (licencia de marcas).

## Qué queda fuera

- Los widgets de inicio y el widget de pagos del Panel siguen con el icono de la subcategoría.
- Logos reales (imágenes de las marcas): Jürgen los quiere (2026-11-06), pero van en su propio ticket
  (`scheduled-payments-real-brand-logos`) porque antes hay que revisar licencias. Aquí se queda el distintivo propio.
- El logo elegido a mano no viaja por el modo Nube entre aparatos (el automático por nombre sí se ve en todos).
- **Antes de publicar 2.3**: desplegar a producción el campo nuevo `CD_brandLogoID` de `CD_ScheduledPayment` en iCloud
  (ya está en los cuatro `.ckdb`).

Código: `SubscriptionBrandCatalog`, `SubscriptionBrandBadge`; tests `SubscriptionBrandCatalogTests` y `ProductividadLote23UITests`.

## Guion de QA para Jürgen (iPhone de pruebas, Yala Dev)

1. Ve a **Planificación › Pagos planificados** y toca **Nuevo pago planificado**.
2. Escribe «Netflix» en el nombre: a la izquierda aparece una **N** roja y debajo la fila **Logo · Netflix (automático)**.
3. Toca **Logo** y elige **Sin logo**: la N desaparece. Vuelve a tocar **Logo** y elige **Spotify**: aparece la S verde.
4. Completa monto, cuenta y categoría y guarda.
5. Mira la lista, luego **Línea de tiempo** y **Calendario** (botones a la derecha de «Este mes»): el pago lleva su logo en las tres.
6. Responde: **¿se ve bien el logo en las tres vistas? (sí / no)** y si echas de menos algún servicio en la lista.
