---
id: restore-unverified-message-depends-on-a-single-gateway-host
status: backlog
priority: low
area: "welcome, remote-config, gateway"
created: 2026-09-17
source: "review adversarial de `reinstall-without-network-has-no-cloud-door` (lente de poblaciones), 2026-09-17"
---

# La guarda de «no pudimos comprobar» mide Supabase y el fetch va al Worker

## El problema

`RemoteFlagDecisionLogic.isConfigKnown` falla ABIERTO —trata la ausencia de snapshot como «no hay nada
que comprobar»— cuando `CloudBackendConfig.isConfigured` es `false`. Ese testigo es **Supabase**
(`supabaseURL` + `anonKey`), pero el fetch del config va a **`ProxyConfig.baseURL`**, el Worker de
Cloudflare. Son dos servicios distintos.

⇒ si el gateway se retira, se renombra o cambia de host **con Supabase configurado**, la guarda no se
abre y todo el que reinstale lee «No pudimos comprobar tus datos» indefinidamente — exactamente el
daño que esa guarda dice estar previniendo.

## Medido (2026-09-17)

- `CloudBackendConfig.isConfigured` es `true` en los dos schemes: URL y anon key son literales no
  vacíos en ambas ramas. **La rama fail-abierto no protege a nadie hoy**; existe para el día que
  alguien vacíe uno de los dos.
- `RemoteConfigClient.refreshIfDue` se gatea con `isConfigured` y fetchea `ProxyConfig.baseURL`.
- El subdominio del Worker ya fue provisional una vez (su propio comentario habla de reemplazarlo).

## Lo que hay que decidir

1. **Dejarlo como está** y aceptar que un gateway muerto es un incidente que rompe también IA, tipos
   de cambio y Grupos, no solo este mensaje.
2. **Añadir un testigo del host del gateway** (una constante que diga si está configurado) y usarlo
   en la guarda, en vez del de Supabase.
3. **Acotar por tiempo**: si el snapshot lleva ausente más de N días con la app abierta muchas veces,
   dejar de decir «no pudimos comprobar» y volver al mensaje de siempre.

## Criterios de aceptación

- [ ] Decidido y escrito qué testigo gobierna el fail-abierto de `isConfigKnown`.

## Relación con otros tickets

- `reinstall-without-network-has-no-cloud-door` — introdujo la guarda.
- `gateway-has-no-telemetry` — sin telemetría, una caída del gateway no se ve.
