---
id: 2026-11-20-captura-cuenta-automatica-y-reglas-maquetas
status: done
priority: medium
area: "captura, cuentas, foto, apple-pay, ia"
created: 2026-11-20
updated: 2026-11-20
source: "encargo 2026-11-20-captura-cuenta-automatica-y-reglas-maquetas"
---

# Maquetas: la cuenta se elige sola al leer una captura, y reglas de cuenta

Sesión de diagnóstico y diseño: no cambia código de la app. Entrega: artifact «Cuenta sola al leer»
(https://claude.ai/artifact/SLKNr8yEwSrW156erj6EEj) y su copia en `docs/maquetas/captura-cuenta-automatica-y-reglas/`.
Implementación: `tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas.md`.

## Qué decide Jürgen (con la recomendación)

Ocho preguntas en la base del artifact (colección `decisiones`, un documento por pregunta con `valor` y `nota`):
enfoque (**A, Yala decide en tu teléfono**, frente a B, la IA elige con tus cuentas, y C, solo reglas), aviso al elegir
sola, varias coincidencias, nombres parecidos, dónde viven las reglas, condiciones, choques y si se parte en dos.

## Medido (2.3, 20-nov)

- Simulador iOS 27.2, Debug-Dev, semilla `ficha` (tres cuentas en soles: «Cuenta Principal», «Efectivo», «Tarjeta de
  crédito»), `-uitest-image-result one`, temas 1 y 2. Una foto leída sale con «Selecciona cuenta» y «Guardar» apagado.
  Para verlo hubo que desactivar en local el relleno de cuenta del seam (`UITestDemoAccountLogic` en
  `ImageSelectionView.uiTestDrafts`); el parche no se commitea:
  `~/Claude/entregas/2026-11-20-captura-cuenta-automatica-y-reglas-maquetas/parche-foto-sin-cuenta-demo.patch`.
- La premisa del encargo no era la ruta real: `ImageOCRService` (y sus `Screenshot*Extractor`) no tiene llamador de
  producción. La foto va por `ImageVisionService` → `VisionDraftFactory`, que elige cuenta solo si hay **una** en la
  moneda leída (`DraftBuilder.findAccount(byCurrency:)`).
- El prompt de visión le prohíbe al comercio ser el banco, la billetera o la tarjeta, y no hay campo para el medio de
  pago. El gateway valida `photo.read` con un esquema cerrado (`gateway/src/ai/routes.ts`, `PHOTO_SCHEMA`).
- Apple Pay: la acción recibe solo importe y comercio (`QuickExpenseIntent`). La automatización de Wallet entrega
  además la tarjeta (reportes de usuarios, sin documentación de Apple).
- Avisos del banco: `BankNoticeParser.last4` lee los últimos 4 dígitos y nadie los usa.
- Voz, Siri y chat ya cruzan el medio de pago dictado con el nombre de las cuentas
  (`PaymentMethodAccountLogic`); la foto, Apple Pay y los avisos del banco no pasan por ahí.
- `Account.accountNumber` («Número de cuenta» en el formulario) existe y no se usa para reconocer nada.
- La Bandeja no recuerda cuenta por comercio; `LastUsedAccountStore` es un valor global que solo escribe Nuevo
  registro.

## Encontrado

- `ImageOCR` es código sin uso en producción (solo sus pruebas lo llaman). Anotado en «Fuera de alcance» del ticket.
