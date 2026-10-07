---
id: vision-reads-every-dollar-sign-as-usd
status: backlog
priority: medium
area: image, ai
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H4)
---

# El registro por imagen lee todo «$» como dólares

> **Grupo: autónomo.** Mejora de prompt acotada. No cambia modelo ni proveedor.

## Qué le pasa al usuario

Un usuario en México fotografía un ticket de «$250». La app lo propone en USD y, si tiene una cuenta en
dólares, se la asigna. Lo mismo en Colombia, Chile, Argentina o Uruguay, que también escriben «$».

## Lo medido (2026-10-07, en este árbol)

- `ImageVisionService.swift:103`: `"$" symbol alone or "US$" → "USD"`. El prompt solo conoce USD,
  EUR, PEN y GBP.
- `VisionDraftFactory.swift:73-75` usa esa divisa para elegir la cuenta
  (`DraftBuilder.findAccount(byCurrency:)`).
- La app soporta 54 divisas (`CurrencyUtils.swift`), varias con «$».

## Qué hay que hacer

1. Pasar al prompt la divisa principal del usuario y las divisas de sus cuentas activas.
2. Regla: «$» solo → la divisa principal si usa «$»; si no, `null`. «US$», «USD» o «dólares» → USD.
3. Dejar el resto de reglas como están.

## Hecho cuando

- Test de prompt puro: con divisa principal MXN, el prompt dice que «$» es MXN; con PEN, que «$» solo
  no decide.
- Device-QA: ticket mexicano con «$» y cuenta en MXN → borrador en MXN y en esa cuenta.
