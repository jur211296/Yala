---
id: groups-guest-currency-from-region
status: backlog
priority: medium
area: groups
created: 2026-08-08
updated: 2026-08-26
source: YalaWiki/Backlog/groups-invitado-moneda-region-red-muerta.md
---


# El invitado con moneda «adivinada por región» ya no recibe la moneda del grupo — ¿hueco o limpieza?

## El problema, en lenguaje de usuario

Cuando alguien entra a Yala POR una invitación de grupo (sin pasar por el onboarding completo), su
moneda puede quedar «adivinada» por la región del teléfono. Existía una red que, al confirmarse su
entrada al grupo, le re-aplicaba la **moneda del grupo** en vez de la adivinada. **Esa red murió con
la Fase 3 y hoy no existe para nadie del canal backend**: si el caso es alcanzable, hay invitados
quedándose con una moneda que no eligieron.

## Contexto técnico (VERIFICADO 2026-08-08, HEAD `3fdeb57a`)

- El escritor `PendingJoinStore.updateRegionFallbackCurrency` (`:145`) tiene **cero call-sites de
  producción** — el único que queda es `PendingJoinStoreTests:169`. El escritor real murió con B1
  (`2f96ad84`); C6 (`ae7065a5`) solo lo hizo visible.
- Cadena completa muerta en la práctica: `entry.regionFallbackCurrency` siempre `nil` ⇒
  `GroupJoinReconcileLogic.shouldApplyGroupCurrency` (`:119-125`, abre con `guard let
  regionFallbackCode`) devuelve **siempre `false`** ⇒ `applyGroupCurrencyIfNeeded`
  (`GroupJoinReconciler:269`, call-sites `:141` y `:222`) es un **no-op permanente**.
- `GroupBackendInviteEntryHandler:100` **conserva** el campo al reconstruir la entry — pero nadie lo
  escribe.

## La pregunta de producto (es UNA, y es binaria)

**¿Puede el alta por invitación backend dejar a alguien con la moneda adivinada por región, sin
haberla elegido explícitamente?**

- **Si SÍ** → es un hueco de usuario: hay que re-cablear el ESCRITOR en el flujo backend (el sitio
  natural es `GroupBackendInviteEntryHandler`, que ya conserva el campo), y la red vuelve a
  funcionar sola — lectores y decisión pura están intactos y testeados.
- **Si NO** (la moneda siempre pasa por una elección explícita en el alta por invite) → la red es
  código muerto con promesa: borrar la cadena entera (`regionFallbackCurrency` del store y del
  handler, `updateRegionFallbackCurrency`, `shouldApplyGroupCurrency`, `applyGroupCurrencyIfNeeded`
  y sus tests) en un commit sustractivo.

## Al abrir el ticket

1. Trazar el flujo de alta por invitación backend end-to-end y responder la pregunta: ¿dónde queda
   fijada la moneda del usuario y quién la elige? (Buscar también quién llamaba al escritor en el
   mundo CloudKit — murió con el transporte — para entender qué caso cubría.)
2. Decidir con el owner según la respuesta (re-cablear vs borrar).
3. En ambos casos: el veredicto va MEDIDO, no inferido (la lección de esta familia), y el commit
   lleva su pin.

migrated from YalaWiki Backlog/groups-invitado-moneda-region-red-muerta.md @ 1934e8ad
