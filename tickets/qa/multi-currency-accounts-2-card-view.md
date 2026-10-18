---
id: multi-currency-accounts-2-card-view
status: qa
priority: medium
area: "accounts, currency, panel, settings"
created: 2026-10-10
updated: 2026-10-18
source: multi-currency-accounts (entrega 2 de A1, decidida por Jürgen el 2026-10-09/10)
---

# Tarjeta multidivisa, entrega 2: la tarjeta con sus líneas en el Panel, la ficha, Ajustes y el formulario

## Qué cambia para el usuario

Su tarjeta «Visa BCP» sale una sola vez, con una línea por divisa («S/ −1.250», «US$ −80») y el total
en su divisa preferida («≈ S/ −1.548»). Puede añadir una línea en otra divisa a cualquier cuenta, y
unir dos cuentas que ya tenía partidas sin que ningún movimiento cambie.

Contexto y decisiones: [`multi-currency-accounts`](../backlog/multi-currency-accounts.md) y
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

- [x] Con el seed de tarjeta de dos líneas, el Panel enseña **una** tarjeta con dos saldos y un total
      «≈»; un XCUITest lo fija contando tarjetas.
- [x] Ajustes enseña la tarjeta una vez y sus líneas anidadas; XCUITest.
- [x] Añadir una línea en otra divisa desde una tarjeta de crédito y desde una cuenta de ahorro
      funciona; en la de crédito la acción está a la vista sin abrir menús.
- [x] Vincular dos cuentas con movimientos: el número de transacciones, sus importes y sus divisas
      son idénticos antes y después (test sobre el store, no sobre la pantalla).
- [x] Vincular dos cuentas de la misma divisa, o una cuenta que ya tiene líneas, se rechaza con un
      mensaje que dice por qué.
- [x] Una línea no ofrece recordatorio ni día de pago, y una tarjeta con dos líneas genera una sola
      notificación.
- [x] Copy nuevo en los 16 idiomas; `/l10n-check` en verde.
- [x] Capturas `antes`/`después` de las cuatro pantallas, con Dynamic Type grande y modo oscuro.
- [x] `/gate` en verde.

## Dependencias

- Depende de: [`multi-currency-accounts-1-model-and-sync`](../done/multi-currency-accounts-1-model-and-sync.md).
- Puede ir en paralelo con la 3 y la 4, pero la función no se publica hasta que la 3 esté: sin ella
  los selectores enseñan las líneas como cuentas sueltas.

## Entregado (2026-10-18, PR contra 2.2)

- **Panel:** una tarjeta (y un chip, plegada) por principal; dentro, un saldo por línea en su divisa y «Total ≈» en la
  preferida. «Por pagar» se evalúa por línea; una línea en 0 no decide el rótulo.
- **Ficha:** cabecera agregada y selector de línea (PEN / USD); la cuenta del período, la curva y los movimientos son de
  la línea elegida. «Editar» abre esa línea; «Filtrar» filtra la tarjeta (su principal).
- **Ajustes:** la tarjeta una vez con sus líneas anidadas; reordenar guarda cada línea justo detrás de su principal. Los
  altos de fila escalan con el tamaño de texto.
- **Formulario:** «Otras divisas» a la vista en tarjetas de crédito (y en cualquier cuenta con líneas); en el resto, al
  final. Añadir línea (divisa + saldo opcional; hereda tipo, color e icono; se llama «Nombre · ISO»), vincular (lista con
  el porqué bajo cada cuenta que no se puede), desvincular (pide Pro si ya estás al límite Free). Una línea tiene la
  divisa fija y no tiene recordatorio. Una principal no puede pasar a la divisa de una de sus líneas.
- **Archivar** una tarjeta con líneas pregunta: también las líneas, o solo la tarjeta. El downgrade archiva en cascada.
- **Recordatorio:** una sola notificación por tarjeta (las líneas se saltan).
- Seed `-uitest-seed tarjeta-dos-lineas`. Tests: `AccountLinesUITests` (5), `AccountCardLogicTests`,
  `AccountLineCardViewTests`.

Decidido por la sesión (Jürgen fuera): ver el Paso 0 del encargo `encargos/lanzados/2026-10-18-tarjeta-varias-divisas-entrega-2.md`
y el cuerpo del PR.

Queda abierto, con nota: borrar una principal deja sus líneas sueltas (como en la entrega 1); «Solo la tarjeta» al
archivar puede dejar más cuentas contando que el límite Free; desarchivar la tarjeta no desarchiva sus líneas.

## Guion de QA en el iPhone (Jürgen)

1. Instala el build de 2.2 con este PR. En Ajustes › Cuentas, abre una tarjeta de crédito tuya.
2. En «Otras divisas», toca «Añadir línea en otra divisa», elige USD y toca «Añadir». Vuelve al Panel: la tarjeta sale una
   vez, con S/ y US$ y «Total ≈».
3. Toca la tarjeta: arriba los dos saldos; cambia PEN ↔ USD y mira que los movimientos cambian.
4. Si tienes otra cuenta en dólares con movimientos, vincúlala desde «Vincular cuenta existente» de otra tarjeta y
   comprueba en Registros que sus movimientos siguen iguales.
5. En el formulario de la línea USD: no hay recordatorio de pago; «Desvincular de la tarjeta» la devuelve a cuenta suelta.
6. Con el recordatorio de la tarjeta encendido, el día de pago llega **una** notificación.
7. Mira las capturas del PR y di si el diseño de la tarjeta te vale.
