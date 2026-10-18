---
id: chat-consent-does-not-mention-this-months-largest-expenses
status: backlog
priority: medium
area: "ia, privacidad, l10n"
created: 2026-10-18
updated: 2026-10-18
source: "Sesión partir-ia-nube-o-privado (hallazgo), medido sobre origin/2.2 9e341a461"
card: tablero-yala-ia-en-privado-el-aviso-no-dice-que-mhwf
---

# El aviso del chat no dice que también se envían los gastos más grandes del mes

## El problema, en lenguaje de usuario

Antes de usar el chat, Yala avisa de qué manda al servicio de IA: «un resumen de tus últimos 13 meses: saldos y nombres
de tus cuentas, totales por categoría, comercios frecuentes, presupuestos y pagos recurrentes»
(`aiConsent.chatMessage`, y en el onboarding de Yala IA `yalaAI.onboarding.l14.consent.readsBody`).

Además de eso, cada pregunta manda **los gastos más grandes del mes en curso, uno a uno**: hasta 10 por subcategoría en
las 10 subcategorías con más gasto, con fecha, importe, comercio y cuenta. Pasa en los dos modos (iCloud privado y nube)
y desde antes de 2.2.

Medido en `Yala/Services/Chat/FullFinancialContextBuilder.swift`: `buildTopTxBySubcategory(tx: currentMonthExpenseTx, …)`
entra en `FullFinancialContext.topTxBySubcategory` (`top_tx_by_subcategory` en el JSON del prompt).

## Qué hay que decidir

Card `tablero-yala-ia-en-privado-el-aviso-no-dice-que-mhwf`. Opciones y textos en los 16 idiomas en
`docs/ai-cloud-vs-private-2026-10.md` §5 (b) y anexo P1:

1. **(Recomendada)** Corregir el texto: añadir «y tus gastos más grandes de este mes».
2. Lo anterior y, además, una línea en Ajustes › Privacidad de la IA sobre lo que cambia en la nube.
3. Dejarlo.

## Hecho cuando

El aviso del chat (y su gemelo del onboarding de Yala IA) dice lo que se manda, en los 16 idiomas, sin nombrar al
proveedor (`AIConsentProviderNameTests`), o Jürgen decide dejarlo.
