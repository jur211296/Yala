---
id: multi-currency-accounts-2-card-view
status: backlog
priority: medium
area: "accounts, currency, panel, settings"
created: 2026-10-10
updated: 2026-10-10
source: multi-currency-accounts (entrega 2 de A1, decidida por Jürgen el 2026-10-09/10)
---

# Tarjeta multidivisa, entrega 2: la tarjeta con sus líneas en el Panel, la ficha, Ajustes y el formulario

## Qué cambia para el usuario

Su tarjeta «Visa BCP» sale una sola vez, con una línea por divisa («S/ −1.250», «US$ −80») y el total
en su divisa preferida («≈ S/ −1.548»). Puede añadir una línea en otra divisa a cualquier cuenta, y
unir dos cuentas que ya tenía partidas sin que ningún movimiento cambie.

Contexto y decisiones: [`multi-currency-accounts`](multi-currency-accounts.md) y
[`docs/multi-currency-accounts-impact-2026-10.md`](../../docs/multi-currency-accounts-impact-2026-10.md),
secciones 3 (A), 4-6.

## Alcance

1. **Carrusel del Panel.** Una tarjeta por cuenta principal con sus líneas dentro: saldo por línea en
   su divisa y total convertido a la preferida con la marca «≈» cuando hay conversión. Las líneas no
   salen como tarjetas propias. «Por pagar» (`PanelAccountCardLogic`) se evalúa por línea.
2. **Ficha de la cuenta.** Ficha agregada de la tarjeta, con el desglose por línea. Cada línea sigue
   siendo una cuenta de una divisa: sus cálculos (`AccountDetailCalculator`) no cambian de premisa.
3. **Ajustes.** La tarjeta sale una vez, con sus líneas anidadas debajo.
4. **Formulario de cuenta** (decisiones 3 y 4):
   - «Añadir línea en otra divisa»: **destacada en tarjetas de crédito y disponible en el resto de
     tipos**;
   - «Vincular cuenta existente»: elige otra cuenta de distinta divisa y la convierte en línea,
     **también si ya tiene movimientos**. Solo escribe el enlace: ningún movimiento cambia;
   - desvincular devuelve la línea a cuenta suelta, con su historial intacto;
   - la lógica pura de la entrega 1 decide qué se ofrece y qué se rechaza; la vista no repite reglas.
5. **Recordatorio y día de pago** solo en la principal. En una línea están apagados y no se ofrecen,
   o la notificación llegaría duplicada (`ScheduledPaymentNotificationService`).
6. **Archivar.** Archivar la principal pregunta qué hacer con sus líneas; archivar una línea no toca
   la principal.
7. **Capturas de antes y después** del Panel, la ficha, Ajustes y el formulario.

## Lo que deja la entrega 1 (medido el 2026-10-18)

- **Qué es cada cuenta lo decide `AccountLineLogic.resolve`** (`Yala/App/Logic/AccountLineLogic.swift`): principal, línea
  o suelta. Una línea rota (huérfana, principal archivada, misma divisa, segundo nivel, duplicada) se lee suelta. Las
  pantallas preguntan ahí, no repiten reglas.
- **Vincular ya existe sin pantalla:** `AccountLineService.link(_:to:in:)` valida con `linkRejection` y escribe solo
  `parentAccountID`. Los motivos de rechazo (`AccountLinkRejection`) son los textos que el formulario tendrá que decir.
- **Ajustes lista las cuentas con `billableUserAccounts`** (`AccountsSettingsListViewModel.activeAccounts`), y desde la
  entrega 1 ese predicado deja fuera las líneas válidas: en cuanto exista una, desaparece de la lista de Ajustes hasta
  que esta entrega la anide bajo su tarjeta. Lo mismo `DowngradeResolutionSheet` (no ofrece archivar una línea) y el
  recuento del Panel (bien: la tarjeta cuenta una vez).
- **Archivar la principal deja sus líneas sueltas** (regla de la lógica). El archivado en cascada es de esta entrega,
  **y tiene que alcanzar también a `DowngradeResolutionSheet`**: si en el downgrade se archiva una principal y no sus
  líneas, la línea pasa a contar y el sheet vuelve a salir en el siguiente arranque (review del 2026-10-18).
- **Reordenar en Ajustes borra la posición de las líneas**: `moveAccount` reescribe `accountsSortOrderNames` desde
  `orderedActiveAccounts`, que ya no las incluye, y el Panel las manda al final (review del 2026-10-18).
- **Dos líneas de la misma (tarjeta, divisa) no se desvinculan solas**: `resolve` lee la de menor `shortcutID` como línea
  y la otra suelta. La ficha tendrá que enseñar esa suelta como lo que es (una cuenta) y dejar desvincularla a mano.
- **`linkRejection` rechaza como principal una cuenta con cualquier `parentAccountID`, aunque su enlace esté roto**
  (huérfano): el formulario tendrá que ofrecer desvincularla antes.
- **En Modo Nube, un enlace solo sube con el teléfono en `v2`** (`SyncCapability`); antes se guarda en local y se
  reemite al subir de versión. No bloquea vincular.

## Fuera de alcance

Selectores, filtros, presupuestos y captura (entrega 3). Informes y export (entrega 4).

## Ficheros implicados

- `Yala/App/Views/Panel/AccountCardView.swift`, `Yala/App/Logic/PanelAccountCardLogic.swift`,
  `Yala/App/ViewModels/PanelViewModel.swift` (`accountBalances`)
- `Yala/App/Views/Panel/Sheets/AccountDetailSheet.swift`,
  `Yala/App/Logic/Calculators/AccountDetailCalculator.swift`
- `Yala/App/Views/Settings/AccountsSettingsListView.swift`,
  `Yala/App/ViewModels/AccountsSettingsListViewModel.swift`
- `Yala/App/Views/Accounts/AccountFormView.swift`,
  `Yala/App/ViewModels/Accounts/AccountFormViewModel.swift`
- `Yala/Services/ScheduledPaymentNotificationService.swift`
- Copy nuevo en los 7 idiomas (`.claude/rules/l10n.md`, `BRAND-VOICE.md`)
- `Yala/Seed/` — un perfil con una tarjeta de dos líneas para XCUITest y capturas
- `qa/coverage-index.json`: `accounts-crud`, `panel-dashboard-logic`

## Criterio de hecho

- [ ] Con el seed de tarjeta de dos líneas, el Panel enseña **una** tarjeta con dos saldos y un total
      «≈»; un XCUITest lo fija contando tarjetas.
- [ ] Ajustes enseña la tarjeta una vez y sus líneas anidadas; XCUITest.
- [ ] Añadir una línea en otra divisa desde una tarjeta de crédito y desde una cuenta de ahorro
      funciona; en la de crédito la acción está a la vista sin abrir menús.
- [ ] Vincular dos cuentas con movimientos: el número de transacciones, sus importes y sus divisas
      son idénticos antes y después (test sobre el store, no sobre la pantalla).
- [ ] Vincular dos cuentas de la misma divisa, o una cuenta que ya tiene líneas, se rechaza con un
      mensaje que dice por qué.
- [ ] Una línea no ofrece recordatorio ni día de pago, y una tarjeta con dos líneas genera una sola
      notificación.
- [ ] Copy nuevo en los 7 idiomas; `/l10n-check` en verde.
- [ ] Capturas `antes`/`después` de las cuatro pantallas, con Dynamic Type grande y modo oscuro.
- [ ] `/gate` en verde.

## Dependencias

- Depende de: [`multi-currency-accounts-1-model-and-sync`](multi-currency-accounts-1-model-and-sync.md).
- Puede ir en paralelo con la 3 y la 4, pero la función no se publica hasta que la 3 esté: sin ella
  los selectores enseñan las líneas como cuentas sueltas.
