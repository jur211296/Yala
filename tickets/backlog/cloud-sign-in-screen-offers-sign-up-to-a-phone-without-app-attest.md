---
id: cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest
status: backlog
priority: low
area: "modo-nube, attest, onboarding"
created: 2026-09-16
updated: 2026-09-16
source: "alcance de `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` (2026-09-16): el alta tiene dos puertas fuera del chooser"
---

# La pantalla de entrar a la nube ofrece crear una cuenta a un teléfono sin App Attest

## El problema, en lenguaje de usuario

Mi teléfono no tiene App Attest. En «Es mi primera vez» ya no me ofrecen la nube. Pero si toco «Ya tengo una cuenta», entro
con Google y no tengo cuenta, la app me dice «No encontramos una cuenta» y me ofrece «Crear mi cuenta». La creo, apunto mis
gastos y nada llega nunca a mi cuenta.

## Lo medido (leído en el código, sin ejecutar)

- Desde el 2026-09-16 la card «Tu cuenta en la nube» del chooser sale solo si el teléfono puede conseguir token
  (`WelcomeAccountChoiceLogic.visibleNewOptions` → `AttestSyncGate.shouldOfferCloudOnly`, con
  `AppAttestClient.canObtainSessionToken`). Cubre «Es mi primera vez», «Crear otra cuenta» y «Activar Yala completo».
- La pantalla de entrar (`WelcomeCloudSignInView`) tiene **dos salidas más al alta**, y las dos van a
  `switchToSignUp(with:)` sin consultar ningún gate:
  - `.notFound` → «Crear mi cuenta» (`notFoundContent`, `welcome_cloud_not_found_cta`).
  - `.providerMismatch` → «Crear cuenta con…» (`ProviderMismatchLogic.Exits.createWith`).
- Ninguna de las dos mira tampoco el kill del alta (`CloudRemoteFlags.cloudOnboardingChoiceEnabled`), que sí esconde la
  card del chooser. **Eso es anterior** al 2026-09-16.
- Las dos existen por decisión de Jürgen: el paso 6 del rediseño («el veredicto dejó de ser una pared», ADR 2026-09-09 §10)
  y el bloque [I] («No encontramos una cuenta» ofrece crearla a quien no tiene ninguna).
- Sin medir: cuántos teléfonos no tienen App Attest, y si alguien llega a crear una cuenta por aquí.

## Lo que hay que decidir (Jürgen)

1. **Una sola puerta del alta para todas las entradas**: las dos salidas obedecen el mismo gate que el chooser (App Attest
   y el kill del alta). Sin App Attest, «No encontramos una cuenta» se queda sin botón de crear y el mismatch con una sola
   salida, la de entrar con el método del faro.
2. **Solo el attest**: esconder las dos salidas cuando el teléfono no puede conseguir token, sin tocar lo del kill.
3. **Dejarlo**: la población está sin medir y quien cae tiene la salida de
   `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` a las 24 h.

## Un aviso para quien lo implemente

El montaje de device-QA de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` crea hoy su cuenta en el
simulador justo por «Crear mi cuenta». Si se cierra esta puerta, ese montaje necesita `YALA_DEV_SHARED_SECRET` para crear
la cuenta y quitarlo antes del paso 1.

## Relación con otros tickets

- `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` — la puerta del chooser, de donde sale.
- `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest` — la otra entrada a la nube que no mira el attest.
- `cloud-hydration-spinner-never-gives-up-without-attest` — lo que ve quien entra con una cuenta que ya existe.
