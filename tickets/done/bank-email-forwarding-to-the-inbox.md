---
id: bank-email-forwarding-to-the-inbox
status: done
priority: high
area: "gateway, inbox, settings"
created: 2026-11-04
updated: 2026-11-04
source: "tablero · tablero-2-2-registrar-movimientos-desde-correos-3w7z (encargo S2 de la ola 2 de 2.3)"
---

# Registrar movimientos desde los correos de alertas del banco (reenvío)

## Qué cambia para la persona

Con los datos en la nube, Ajustes › «Correo del banco» le da su dirección `auto+<código>@yala-app.pe`, el cupo de
prueba (5 correos leídos sin Pro) y una guía por pasos para Gmail, Outlook e iCloud Mail. Reenvía los avisos de su
banco con un filtro o una regla; el gateway los lee con IA y el movimiento llega a la Bandeja por confirmar, con la
cuenta que nombra el aviso (banco o 4 dígitos) o la única en esa divisa. El código con el que Gmail confirma la
dirección aparece en el paso que lo pide.

## Cómo está hecho

- **Gateway** (`gateway/src/mail/`, migración D1 `0003_mail_forwarding.sql`): entrada `email` de Email Routing,
  dirección por cuenta, código de Gmail sin IA ni cupo, techo de 50 correos/día por dirección, 256 KB, el mismo aviso
  se lee una vez, Pro por cuenta (`account_entitlements`) o cupo de 5 con devolución si falla el proveedor. Lee con
  el adaptador de OpenAI existente y **su propio tope** (entrada 6.000 caracteres, salida 400 tokens), y registra su
  uso en `yala_ai_usage` como el resto de la IA (tarea `mail.read`). El movimiento
  queda en una cola de la cuenta hasta que la app lo recoge (`GET /mail/drafts`, `POST /mail/drafts/ack`), 30 días
  como mucho. El correo no se guarda. `/account/delete` borra todo lo del correo.
- **App**: `BankEmailClient` (attest vivo), `BankEmailDraftService` (al volver a primer plano y al abrir la pantalla;
  crea `InboxDraft` `.emailAlert`), `BankEmailForwardingView` + guías `YalaStepGuide`. Un borrador sin cuenta enseña
  la divisa del aviso (`InboxDraft.displayCurrencyCode` lee `cachedCurrencyCode` sin cuenta).

## Pendiente fuera de este ticket

- Reconciliada con el control del coste de la IA (S1) en el mismo PR: `bank-email-read-reconcile-with-the-ai-cost-control`.
- El 90 % de una semana de avisos reales: `bank-email-measure-a-week-of-real-peruvian-alerts`.
- Activar buzón, migración y Worker en producción: card de Jürgen «Activar el buzón auto@yala-app.pe».

## Criterios de aceptación

- [x] La dirección y la guía (Gmail, Outlook, iCloud Mail) en Ajustes, con el código de Gmail.
- [x] El cupo de 5 correos leídos se respeta (gateway `test/mail.test.ts`).
- [x] Un movimiento leído llega a la Bandeja con su cuenta y su divisa, también en dólares (`YalaTests/BankEmailTests.swift`).
- [ ] Prueba de punta a punta con un aviso real: espera al buzón (guion en el PR).
