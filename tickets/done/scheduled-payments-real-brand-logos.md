---
id: scheduled-payments-real-brand-logos
status: done
priority: medium
area: "planning, scheduled-payments, legal"
created: 2026-11-06
updated: 2026-11-17
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

## Resuelto (2026-11-17)

Jürgen decidió el 17-nov no revisar licencias marca por marca: es uso nominativo para identificar un pago de la persona
(como Copilot, Rocket Money o los bancos). Reglas: el logo no se deforma ni se recolorea, nada sugiere patrocinio, y
ningún logo de terceros va en la ficha del App Store ni en publicidad. Y solo soluciones gratuitas.

- **Banco de comercios** (`Yala/App/Logic/MerchantLogos/MerchantCatalog.json`): 666 comercios con nombre, formas de
  escribirlo y dominio, prioridad Perú y Latinoamérica (bancos y cajas, fintech, telcos, luz/agua/gas, gimnasios,
  retail, delivery, streaming, educación, seguros, software, IA…). Los 40 servicios de antes siguen con su id.
- **Logos empaquetados**, no descargados: `scripts/merchant_logos.py` baja una vez, en la Mac, el icono que cada
  comercio publica en su web (respaldo: iconos públicos de Google y DuckDuckGo y el de su app en el App Store), y los
  deja en `MerchantLogos.xcassets` (2,1 MB). 598 con logo, revisados a ojo; 21 marcados `noLogo` porque el icono no era
  el de la marca. El teléfono no hace ninguna petición.
- **Casado tolerante**: «SmartFit J1», «Interbank Crédito», «Tarjeta de crédito BCP», «Rímac Seguros S.A.C.».
- **Dónde se ve**: lista, línea de tiempo, calendario, editor, «Pagos que se repiten» y su tarjeta. En el editor, el
  logo se elige en una hoja con buscador sobre todo el banco. Sin campo nuevo de iCloud (`brandLogoID` de siempre).
- **Fuera**: Registros y Panel → `tickets/backlog/records-and-panel-merchant-logos.md`.

Probado: `MerchantCatalogTests` (12), `SubscriptionBrandCatalogTests`, `MerchantLogosUITests` (3) y el caso de
logos de `ProductividadLote23UITests`; en el iPhone 14 (editor, hoja con buscador, elegir a mano, línea de tiempo).
