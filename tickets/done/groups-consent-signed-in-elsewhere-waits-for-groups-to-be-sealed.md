---
id: groups-consent-signed-in-elsewhere-waits-for-groups-to-be-sealed
status: done
area: groups
priority: low
created: 2026-10-21
updated: 2026-10-23
source: review adversarial del lote decidido 2.2 · 13 (L12-4)
---

# Un consentimiento aceptado sin sesión espera a Grupos o a un arranque para registrarse si se entra por otra puerta

## Qué pasa

Desde L12-4 el paso 3 del educativo acepta el consentimiento de Grupos antes de iniciar sesión (snapshot sin
sello). Se sella y se registra contra la cuenta en el arranque en frío, al entrar por la hoja de Grupos y, desde
este lote, al abrir la pestaña Grupos con sesión. Si la persona cancela la hoja de cuenta, entra por Ajustes o el
Welcome y cierra sesión (con subida de grupos) antes de volver a Grupos o relanzar, `clear()` borra el snapshot y
la cuenta se queda sin la fila del consentimiento.

## Por qué no se cerró en el lote

Sellar en cualquier `CloudAuthService.signIn` rompe el invariante del bloqueo [I] («el bloqueo no escribe
NADA»: una cuenta rechazada no puede quedarse con un consentimiento). Hace falta sellar en el punto en que la
sesión ya está aceptada por cada puerta.

## Hecho (2026-10-23, card m387)

El consentimiento se sella en el punto en que cada puerta da la sesión por buena, con
`GroupsConsentRegistrar.sealAfterSessionAccepted()` (el mismo `handleSignIn` de siempre, sin bloquear):

- **Bienvenida**: al entrar en una cuenta solo-grupos, en el adopt que pasó el guard cross-cuenta y en el alta en la nube
  (que desde R2 no relanza sobre un montaje neutro).
- **Ajustes**: «Activar la nube en este dispositivo» cuando el adopt llega al claim, «Migrar a la nube» pasado el claim
  (un claim rechazado cierra antes la sesión que abrió y no sella) y volver a entrar desde el aviso de sincronización con
  la cuenta dueña.
- Las tres que ya sellaban siguen igual: la hoja de Grupos (detrás del bloqueo [I]), la pestaña y el arranque.

Nunca en `CloudAuthService.signIn`: lo fija `GroupsConsentSealDoorsWiringTests`, con un caso por puerta y los negativos
del bloqueo [I] (la cuenta rechazada por datos ajenos, la de «No encontramos una cuenta», la del aviso de sincronización
que no es la dueña). El aviso de sesión nuevo de la pestaña de Grupos (card nve0) solo repinta: con las seis páginas
montadas oye también los inicios de sesión que una puerta rechaza después.

Fuera, a propósito: «Volver a iCloud» que pide entrar para seguir. No acepta una sesión nueva para Grupos: sale de la nube.
