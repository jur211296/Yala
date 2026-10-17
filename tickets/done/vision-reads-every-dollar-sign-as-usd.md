---
id: vision-reads-every-dollar-sign-as-usd
status: done
priority: medium
area: image, ai
created: 2026-10-07
updated: 2026-10-15
qa-status: passed
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H4)
qa-date: 2026-10-15
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

## Hecho en la sesión 2 (2026-10-07)

La app pasa al prompt la divisa principal y las de las cuentas (`VisionCurrencyContext`): «$» a secas es la divisa principal si se escribe con «$» y `null` si no. Tests: `VisionCurrencySession2Tests` (MXN → MXN; PEN → no decide) y `gateway/test/ai.bench.test.ts`. Device-QA: paso 5 del guion de `ai-every-call-sends-its-task-and-passes-the-bench`.

## Barrido de QA · 2026-10-15

Cerrado en el barrido de QA 2026-10-15: probado en el simulador (Yala Dev, iPhone 17 Pro, iOS 27.0, `8cd693cb6`, lectura real contra staging): con la divisa principal en PEN, el ticket «Taquería Don Pepe» de «$ 250.00» sale como borrador de 250.00 sin divisa y pidiendo cuenta («Falta: Cuenta, Subcategoría»), no en USD. El caso MXN (cuenta en MXN → 250 MXN en esa cuenta) lo fijan `VisionCurrencySession2Tests` y el banco de `gateway/test/ai.bench.test.ts` (100 %). Captura `~/Claude/worktrees/_capturas/2026-10-15-barrido-qa-2-1/b3-1-dolar-a-secas-en-soles-sin-divisa.png`.
