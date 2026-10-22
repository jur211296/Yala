---
id: paywall-inbox-routing-uitest-misses-the-held-paywall-in-a-batch
status: backlog
priority: low
area: "testing, routing"
owner: frank
created: 2026-10-01
updated: 2026-10-08
source: "gate de `superseding-intent-can-strand-the-sign-out-coordinator`"
---

# `PaywallInboxAlertRoutingUITests` no ve el paywall retenido cuando corre dentro de un lote

## Lo medido (2026-10-01, iPhone 17 Pro, iOS 27.0)

- **Dentro de un lote de seis clases** (con `InboxNewItemsModalUITests`, `RemoteWipeNoticeRoutingUITests`,
  `DeeplinkRoutingUITests`, `UpdateAvailableBannerUITests` y `ProConversionUpsellsUITests`): rojo en `:53`
  («El paywall retenido no se presentó al cerrar el alert»), tras agotar los 45 s de espera. Centinela limpio: nadie
  corrió encima.
- **Aislado, tres veces seguidas y con el mismo binario:** verde las tres, ~30 s cada una.
- El cambio que se estaba probando no corre en ese flujo: solo actúa cuando cambia la fase del cierre de sesión, y
  aquí no cambia.

`:53` ya era el punto de los rojos de esta suite en iOS 27.0 (latencia de desmontaje del cover, ver el comentario del
propio test). Lo nuevo es la dependencia del CONJUNTO: aislado pasa con margen.

## Qué falta

Repetir el lote de seis unas cuantas veces para ver si el rojo es del orden (qué corre antes) o del azar, y en qué
paso cae. Si es del orden, mirar qué deja puesto la clase anterior.

## Medido en 2.1 (triage 2026-10-08)

- `YalaUITests/Flows/PaywallInboxAlertRoutingUITests.swift` sin commits desde el 2026-10-01; el paso 2 sigue con `waitForExistence(timeout: 45)` sobre `trial_offer_dismiss`.
- Nadie ha repetido el lote de seis: falta la medición que pide «Qué falta».

Triage 2026-10-08: abierto · low → low · intermitencia de test dependiente del lote, sin medir aún si es del orden; no deja ciego al gate de nada que el test aislado no cubra.
