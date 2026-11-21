---
name: project-cuenta-sola-al-leer-parte-2-espera
description: Qué espera la parte 2 (reglas de cuenta) de «la cuenta sola al leer» y por qué la capa B de la foto solo va en la nube
metadata:
  type: project
---

Parte 1 hecha el 2026-11-20 (A + B). La parte 2 (`tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas-parte-2.md`)
espera dos cosas de Jürgen antes de valer la pena encolarla:

- **Qué texto entrega el dato «Tarjeta» de Wallet** en un pago real en el iPhone 14 (necesita su tarjeta y su mano). Si no
  distingue tarjetas, la regla «Paga con Apple Pay» se cae.
- **Si los nombres de cuentas viajan también en iCloud privado.** Lo dejé solo en la nube porque el permiso de foto en
  privado solo promete «la foto»; extenderlo exige versionar `aiConsent.processingMessage` (es suya la decisión).

**Why:** el encargo pedía A + B sin distinguir modos; tomé la opción más segura en nocturno.
**How to apply:** al retomar, pregunta las dos antes de diseñar; no muevas la capa B a privado sin la versión del permiso.

Relacionado: [[feedback-cuando-la-app-pregunta-al-usuario]].
