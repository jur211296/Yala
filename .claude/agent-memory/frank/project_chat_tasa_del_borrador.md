---
name: chat-tasa-del-borrador
description: PR #99 — el chat ya guarda la tasa que usó; falta device-QA y NO es simulable. Deja cuatro tickets, uno high (el chat pierde el signo del gasto y el saldo sube).
metadata:
  type: project
---

**El chat ya guarda la tasa que usó al convertir, no un 1,00 plantado.** PR #99, ticket
`chat-assistant-plants-exchange-rate-one` → `qa`.

**Why:** la ruta pasaba `exchangeRate: 1.0` literal mientras el monto convertido de al lado sí salía
de una conversión real. No se curaba solo: con tasa exacta —el caso normal— el flag de provisionalidad
queda `false` y la fila sale del `#Predicate` del reparador, así que el número falso se sellaba.

**How to apply:**

- **Falta device-QA y NO es simulable con los seeds de hoy.** Ninguno es multi-divisa: para ver el
  número en el detalle hace falta una cuenta en otra divisa y el chat contra el LLM real. Es la misma
  limitación que [[fx-pnl-card]] y [[fx-escrituras-a-mano]] — si alguna vez se siembra un seed
  multi-divisa, estos tres device-QA se desbloquean juntos.
- **El umbral `abs(monto) > 0.0001` NO se toca en un solo sitio.** El reparador tiene el mismo, y
  romper la paridad hace que la fila cambie de número al repararse. Está en
  `fx-rate-derivation-threshold-reseals-one-to-one` por eso, no por olvido.
- **Lo que dejó abierto, y el primero urge más que este ticket:**
  `chat-draft-drops-the-expense-sign` (**high**) — `saveDraft` no usa `draft.isExpense` para firmar el
  monto, así que un gasto dictado al chat **suma** al saldo. Las listas cuadran (clasifican por
  categoría) y el saldo no (suma en crudo). Detalle incómodo: hasta este PR el 1.0 plantado era la
  señal visible de que esa fila no era de fiar, y arreglarlo se la quitó.
  Los otros tres: `chat-rows-sealed-before-the-fix-have-no-repair-path`,
  `exchange-rate-detail-shows-zero-for-low-denomination-currencies` (`%.4f` enseña VND→USD como
  «0,0000») y el del umbral.
- **Dos premisas medidas que conviene no volver a discutir.** (1) El barrido legacy
  (`fxOneToOneRepairSweep.v1`) es one-shot por dispositivo y su flag se marca **aunque no haya
  candidatas**; por eso lo ya escrito no se cura. (2) `needsRepair` pide `1.0` **Y** divisa distinta:
  estas filas eran candidatas legítimas, no falsos positivos como decía el ticket.

Relacionado: [[fx-escrituras-a-mano]] (de ahí salió este ticket) · [[mi-docblock-tambien-es-una-premisa]]
(escribí una justificación inventada para el umbral) · [[review-adversarial-caza-lo-mio]] (las tres
lentes cazaron seis defectos en mi propio test).
