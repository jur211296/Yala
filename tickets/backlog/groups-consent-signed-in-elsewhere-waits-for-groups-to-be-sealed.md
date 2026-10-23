---
id: groups-consent-signed-in-elsewhere-waits-for-groups-to-be-sealed
status: backlog
area: groups
priority: low
created: 2026-10-21
updated: 2026-10-21
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
