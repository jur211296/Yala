---
id: onboarding-2-3-bank-email-step
status: qa
priority: high
area: onboarding, gateway
created: 2026-11-12
updated: 2026-11-13
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

## Hecho el 2026-11-13 (buzón activo)

- **Prueba del servidor, de punta a punta, en staging.** Desde la Mac se mandó por SMTP al MX de Cloudflare un aviso de
  Interbank reenviado (S/ 23.50 en Tambo) a la dirección real de una cuenta de prueba (`auto-staging+<código>@yalainbox.com`,
  sacada de `POST /mail/address`). `wrangler tail` de `yala-gateway-staging`: `Email … - Ok` y `[mail] outcome=draft`;
  `GET /mail/drafts` devolvió el movimiento con importe, divisa, comercio, fecha, banco y últimos 4 dígitos correctos.
  El enrutado de Cloudflare (subdirección `auto-staging+`) funciona sin tocar nada.
- **Paso 7 con el correo.** `.mail` entre `share` y `siri`; parte «Tu correo, en automático» en la página corta y mini
  tutorial «Tu dirección de Yala» con la dirección real (`BankEmailModel`, la de Ajustes), «Copiar», tres pasos del filtro,
  la nota de Gmail, «Pronto: conectar Gmail y Outlook directamente, sin filtros.» y «Listo». Solo con datos en la cuenta de
  Yala (`BankEmailEntryLogic.showsRow`, fijado al aparecer el paso); sin ella, cuatro maneras. Textos en los 16 idiomas.
- Tests: `Bienvenida23FinalTests` (cuatro o cinco maneras, la regla, el orden y la cuenta) y el XCUITest
  `test_step7_withTheYalaAccount_teachesTheMailAsTheFourthOfFive`.

## Pendiente: la llegada a la Bandeja con una cuenta real (device-QA)

No se pudo cerrar el 2026-11-13: con la cuenta de staging de Jürgen el iPhone 14 no pasa de «Conectando con tu cuenta…
60 %» por el bug de la card «Entrar desde un teléfono nuevo en una cuenta con grupos se bloquea 15 min»
(`tickets/backlog/adopt-lineage-block-shows-connecting-for-fifteen-minutes.md`). Jürgen pidió cerrar y priorizar ese bug.

Guion, cuando el teléfono entre en una cuenta (o con una sin grupos, que no dispara el bloqueo):

1. Yala Dev en el iPhone 14, sesión iniciada y datos en la nube. Ajustes › Correo del banco: anotar la dirección
   `auto-staging+<código>@yalainbox.com`.
2. Desde la Mac, con `wrangler tail yala-gateway-staging` abierto, mandar un aviso de banco a esa dirección (receta: SMTP
   directo a `route2.mx.cloudflare.net:25`, remitente `@yalainbox.com`, cuerpo con el aviso reenviado). Esperar
   `[mail] outcome=draft`.
3. Volver a primer plano en Yala: el movimiento aparece en la Bandeja como borrador, con importe, divisa, comercio y fecha
   del aviso. Captura.
4. Primeros pasos, paso 7: con esa cuenta salen cinco maneras y el correo enseña la misma dirección. «Copiar» la copia.
