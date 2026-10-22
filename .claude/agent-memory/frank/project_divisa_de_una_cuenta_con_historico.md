---
name: divisa-de-una-cuenta-con-historico
description: PR #118 — cambiar la divisa de una cuenta ya no deja el histórico atrás; la review cazó SEIS defectos del arreglo y deja 5 tickets. Falta device-QA (sí simulable, pero el selector no acepta taps sintéticos).
metadata:
  type: project
---

**Cambiar la divisa de una cuenta con movimientos ya no desempareja su histórico** (PR #118,
2026-09-09). Decisión de Jürgen: **prohibir, y ofrecer convertir cuando se puede**. Descartó
«avisar y seguir» — deja vivo el desemparejamiento y mantiene roto el round-trip de exportación.

**Why:** era «la ruta más productiva de desemparejamientos de la app»: las de creación producen una
fila, ésta el histórico entero de una cuenta de una vez.

**How to apply:**

- **Es el PRIMER sitio del repo que reescribe el `amount` crudo de filas ya persistidas.**
  `CurrencyChangeService` (divisa PREFERIDA) barre el corpus entero pero solo toca las cuatro
  derivadas, que tienen reparador; la columna cruda no lo tiene. Si vuelves a tocar esta zona, ése
  es el listón: confirmación explícita, tasas ANTES, y si falta cobertura **no se convierte nada**.
- **Tres clases de fila bloquean el cambio ENTERO, y no por prudencia: su conversión NO SE
  SOSTIENE.** Medido: el re-bridge **pisa el `amount`** de un gasto de grupo en cada pasada
  (`GroupTransactionBridge:393`) y, en cuanto su divisa deja de casar con la del gasto, **BORRA la
  transacción** y deja un draft (`:391`, `:410-422`) — convertirla la destruye. Una liquidación se
  recrea entera desde el settlement (`:1069-1083`). Y una pata de transferencia codifica la tasa
  junto a su pareja: `bulkUpdateAmount` ya bloqueaba por eso mismo.
- **Dos premisas del ticket salieron falsas al medirlas.** El grupo `money` de `tx_items` tiene
  **cinco** columnas, no cuatro, y `currency_code` **no es una de ellas**. Y lo INFERIDO sobre
  CloudSync apuntaba al applier de `tx_items`; la rama que propaga el daño es la de **`accounts`**.
- **Device-QA pendiente y sí simulable, pero con una trampa cara:** el selector de Moneda del
  formulario de cuenta es un `NavigationLink` y **no responde a los taps sintéticos** (medido el
  8-sep con cuatro técnicas; el control cruzado descarta que sea bug de la app). Dos de los cuatro
  pasos del guion se recorren a mano. El seam del seed se llama `-uitest-seed-foreign-account <ISO>`
  — **no** como su fichero (`DevSeedForeignCurrencyAccount.swift`).
- **Deja cinco tickets**, ninguno del alcance: `cloudsync-account-currency-orphans-receiver-history`,
  `account-currency-change-leaves-scheduled-and-favorites-stale` (el alquiler programado de 3.500
  soles nace como 3.500 dólares), `account-currency-conversion-overlay-has-no-ceiling`,
  `save-error-alert-lies-when-the-context-autosaves`,
  `bridge-virtual-only-currency-mismatch-is-silent`.
- **Un efecto que ninguna pantalla avisa:** un CSV exportado ANTES de la conversión deja de poder
  importarse a esa cuenta, y el fallo aborta el fichero entero.

Relacionado: [[review-adversarial-caza-lo-mio]] (seis de seis hallazgos eran del arreglo),
[[el-alert-de-swiftui-compite-con-su-propio-boton]] y [[divisa-del-chat-vs-cuenta]] (el hueco que
este ticket cerraba).
