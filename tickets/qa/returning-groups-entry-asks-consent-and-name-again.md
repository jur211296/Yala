---
id: returning-groups-entry-asks-consent-and-name-again
status: qa
priority: medium
area: groups, onboarding
created: 2026-10-19
updated: 2026-10-22
source: QA guiado 2026-10-19 (A · C6), card «Al volver a entrar por «Vengo por un grupo» con la misma cuenta, Yala pide otra vez el consentimiento de Grupos y tu nombre»
---

# Al volver a entrar por «Vengo por un grupo» con la misma cuenta, Yala pide otra vez el consentimiento y el nombre

## Qué pasaba

Cerrar sesión y volver a entrar por «Vengo por un grupo» con la misma cuenta enseñaba otra vez «Grupos en la nube» y
después el nombre, aunque la cuenta ya tenía su fila en `groups_consents` y su grupo. La lectura del consentimiento de
la cuenta (`GroupsConsentRegistrar.handleSignIn`) se lanzaba tras iniciar sesión sin esperarla, y la puerta decidía con
la caché local que el cierre de sesión había borrado.

## Hecho (2026-10-22)

- La puerta de Grupos guarda esa lectura y la espera (con techo de 10 s) antes de decidir el paso siguiente
  (`GroupsSignInSettle`, en el `onDismiss` del sign-in de `GroupsBackendInviteModifier`). Vale también para el invitado.
- En la rama del organizador espera además una pasada del canal de Grupos; si trae una fila activa de la cuenta con
  nombre, el alta se completa con ese nombre y aterriza en Grupos, sin el formulario del primer grupo
  (`ReturningGroupsMemberLogic`, caso `.presentName` de `ContentView`).
- Precio aceptado: entre cerrar la hoja de la cuenta y la pantalla siguiente hay una espera de hasta 10 s sin nada nuevo
  en pantalla (con red, lo que tarda una lectura y un tirón).

Tests: `ReturningGroupsMemberTests`. El recorrido real necesita una cuenta de nube y no se puede montar en el simulador.

## Device-QA (iPhone de QA, Yala Dev contra staging)

1. Instalación nueva › «Vengo por un grupo» › «Crear mi primer grupo» › Google › acepta «Grupos en la nube» › crea un
   grupo con tu nombre.
2. Perfil › «Cerrar sesión».
3. Vuelve a entrar por «Vengo por un grupo» con la misma cuenta: NO sale «Grupos en la nube» ni el formulario con tu
   nombre; aterrizas en Grupos con tu grupo.
4. En staging sigue habiendo una sola fila en `groups_consents` para esa cuenta.
