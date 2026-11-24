---
id: 2026-11-24-textos-viejos-de-correo-del-banco-sin-uso
status: done
priority: low
area: "bank-email, l10n"
created: 2026-11-24
updated: 2026-11-24
source: "cierre de Correos del banco (tickets/done/2026-11-23-correos-del-banco-claridad-y-volver.md): las claves viejas de la guía quedaron sin uso"
---

# Textos viejos de la guía de Correos del banco, retirados

## Qué pasaba

La guía de «Correo del banco» pasó a su tabla propia (`CorreosBancoGuia.strings`) el 23-nov, y las claves `bankEmail.*`
de la guía vieja se quedaron en `Localizable.strings` y en `L10n+BankEmail.swift` sin que nadie las leyera.

## Qué cambió

- Medido con `git grep` (accesor y clave literal, fuera de los `.strings`): 15 claves sin ningún lector —
  `stepCopyTitle`, `stepCopyDetail`, `gmailAddTitle`, `gmailAddDetail`, `gmailConfirmTitle`, `gmailConfirmWaiting`,
  `gmailFilterTitle`, `gmailFilterDetail`, `ruleTitle`, `outlookRuleDetail`, `icloudRuleDetail`, `stepWaitTitle`,
  `stepWaitDetail`, `gmailConfirmCode` y `guideLine`—. Borradas en los 16 idiomas (240 líneas) y sus accesores.
- Las que siguen en uso no se tocan (título, dirección, cupo, «Copiar código», «Comprobar», etc.).
- `LocalizationParityTests` tenía una exención para `gmailAddDetail` y `outlookRuleDetail` (nombraban el menú de Gmail
  en portugués); con las claves fuera, la exención se retira.

## Pruebas

- `AvisosCorreosBancoRestosTests`: ninguna de las 15 vuelve en ningún idioma ni en el accesor.
- Paridad de idiomas, `CorreosDelBancoGuia*` y `BundleLocaleDriftTests` en verde.
