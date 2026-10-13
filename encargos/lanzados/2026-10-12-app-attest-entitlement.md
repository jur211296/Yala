# Declarar el entitlement de App Attest ahora que el App ID lo tiene (g8rc)

## Contexto
Card g8rc («Declarar el entitlement de App Attest después de activarlo en el App ID»). Ticket: `tickets/backlog/release-plist-leftovers-widget-build-faceid-appattest.md` (punto 3). Va antes de la subida a TestFlight (c59v).

El PR #447 dejó App Attest sin declarar porque el App ID no tenía la capacidad. Jürgen activó App Attest el 2026-10-12 en developer.apple.com para `com.jurgenschmidt.yala` y `com.jurgenschmidt.yala.dev`. El gateway (`gateway/src/attest/`, `gateway/wrangler.toml`) ya exige: producción `ATTEST_ENV=production` + bundle `com.jurgenschmidt.yala`; staging `development` + `com.jurgenschmidt.yala.dev` (+ bypass `DEV_SHARED_SECRET` solo staging). El backend no se toca.

PR #475 (barrido QA) acaba de cerrar y está en cola de auto-merge a 2.1: no esperes su CI; arranca desde `origin/2.1` y, justo antes de abrir tu PR, `git fetch origin && git rebase origin/2.1`.

Brief en Mini: `~/Claude/tmp-frank/app-attest-entitlement.md` (léelo entero).

## Qué se pide
1. Añadir `com.apple.developer.devicecheck.appattest-environment`: `production` en `Yala/App/Yala-Release.entitlements`, `development` en `Yala/App/Yala-Debug.entitlements`. Widgets y Share no atestan: no lo llevan (compruébalo con grep de `DCAppAttestService`).
2. Comprobar que un build firmado lo lleva: con firma automática (`-allowProvisioningUpdates`), build de Release para `generic/platform=iOS` o archive, y `codesign -d --entitlements :- <Yala.app>` mostrando el entitlement con su valor, también para Debug. Si la firma falla porque el portal aún no propagó la capacidad o el perfil no se regenera, PARA y repórtalo (no desactives la firma, no toques el portal).
3. Riesgo del Debug del scheme `Yala`: usa el bundle de producción (`com.jurgenschmidt.yala`) y quedaría con `development`, que el gateway de producción rechaza. Mide qué configuración/bundle/URL de gateway usa cada scheme (`Yala`, `Yala Dev`) en Debug y Release y decide la forma robusta (o documenta limitación). Justifícalo en el PR.
4. Mueve el punto 3 del ticket a hecho (o el ticket a in qa si quedan los otros puntos ya cerrados por #447). Al cerrar, mueve la card g8rc a in qa o done según toque.

## Qué NO tocar
Gateway, wrangler, secretos, Supabase, App Store Connect, el portal de Apple. Nada de deploy.

## Reglas de build y Mini
Pipeline serie Yala: limpiar → `xcodebuild -jobs 2` sin sim booteado → boot 1 sim si hace falta → tests → apagar/limpiar. Nunca más de un simulador; al terminar `xcrun simctl shutdown all`. DerivedData de esta sesión y cachés XcodeBuildMCP de worktrees muertos se borran sin preguntar.

## Cómo se sabe
Build firmado de Release con `appattest-environment = production` verificado con codesign; Debug con `development`; el riesgo del Debug de `Yala` resuelto o documentado; build y tests verdes; nada desplegado. `/cerrar-total` autónomo en modo cola.

## Paso 0

- **Criterio del entorno de attest: sigue al bundle, igual que el gateway** (prod = `production` + `com.jurgenschmidt.yala`; staging = `development` + `.dev`). Medido: Debug y Release usan el bundle de producción; Debug-Dev y Release-Dev, `.dev`.
- **El Debug de `Yala` lleva `production`.** Apple permite declarar `production` en un build de desarrollo, y el perfil generado admite los dos valores (`embedded.mobileprovision`: `[development, production]`). Es la forma robusta: un build de Xcode del scheme `Yala` deja de dar 401 contra producción.
- **Cómo:** `Yala-Release.entitlements` lleva el literal `production`. `Yala-Debug.entitlements` lo comparten Debug, Debug-Dev y Release-Dev, así que lleva `$(APP_ATTEST_ENVIRONMENT)`, con valor por configuración en el target Yala. Descartado un tercer fichero de entitlements: duplicaría los otros diez keys y divergiría.
- **Fuera:** Release-Dev habla con el gateway de PRODUCCIÓN (no define `DEV_BUILD`) con bundle `.dev`, así que el gateway lo rechaza por bundle sea cual sea el entorno. Es previo a este encargo y no se toca: se anota en el PR.
- **Ticket:** los puntos 1 y 2 ya están en el árbol, así que el ticket pasa a `qa` con un guion de device.
