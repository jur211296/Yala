---
id: onboarding-2-3-bank-email-step
status: blocked
priority: high
area: onboarding, gateway
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-correo-automatico-i9d8 (docs/onboarding-2-3/SPEC.md, Y23-19)
---
# Bienvenida 2.3 · Correo automático en el paso 7 (Y23-19)

**Bloqueado por infraestructura, no por código.** La feature del correo por reenvío ya está programada (ticket
`bank-email-forwarding-to-the-inbox`: dirección por persona, gateway que lee con IA, borrador a la Bandeja y Ajustes ›
«Correo del banco»), pero no está lista de verdad:

- `gateway/RUNBOOK.md`: «Nada desplegado» — migración D1 `0003_mail_forwarding.sql`, Worker y Email Routing sin activar.
- Dominio: decisión de Jürgen del 10-nov, `yalainbox.com` (card «Correo del banco: dirección auto+<código>@yalainbox.com»);
  lo compra Dan y configura Email Routing. Sin comprar a 12-nov.
- La prueba de punta a punta con un aviso real y la medida del 90 % (`bank-email-measure-a-week-of-real-peruvian-alerts`)
  esperan al buzón.

Mientras tanto el paso 7 enseña **cuatro maneras** (criterio de Y23-16 y Y23-19) y el mini tutorial «Tu dirección de Yala»
con «Copiar» no se construye: no hay servidor contra el que probarlo.

## Cuando el buzón esté activo

1. Añadir `.mail` a `HomeScreenTutorialLogic.Method` entre `share` y `siri` (orden de la ficha) y su parte de la página
   corta («Tu correo, en automático»).
2. Mini tutorial: «Tu dirección de Yala» con la dirección real (`BankEmailClient`, la misma de `BankEmailForwardingView`)
   y «Copiar», los tres pasos del filtro, «Pronto: conectar Gmail y Outlook directamente, sin filtros.» y «Listo». Solo
   con datos en la cuenta de Yala (`BankEmailEntryLogic.showsRow`); sin ella, cuatro maneras.
3. Prueba: reenviar un aviso real y verlo llegar a la Bandeja como borrador.
