---
id: full-activation-onboarding-signal-never-reaches-the-apple-id-kv
status: backlog
priority: low
area: "sesiones, sync"
created: 2026-09-30
updated: 2026-10-08
source: "residual de `full-activation-local-state-never-reaches-the-apple-id-kv`"
---

# La señal «onboarding terminado» de «Activar Yala completo → privado» no llega al iCloud del Apple ID

## El síntoma, en lenguaje de usuario

Activo Yala completo en privado desde solo-grupos. Mis otros dispositivos del mismo Apple ID no se enteran
de que ya terminé el alta: si uno de ellos tenía pendiente un «Vaciar datos» procesado, no recibe el «otro
dispositivo terminó el onboarding» que normalmente le cierra el Welcome.

## Lo medido (2026-09-30)

- `OnboardingView.completeOnboarding` llama a `PreferenceSyncService.signalOnboardingCompleted()` dentro de
  `.persistOnboarding`, con el eje todavía en `false`. Su `setDouble` de `lastOnboardingTimestamp` lo tira la
  puerta (`OwnerKeyValueStore`: las dos señales se LEEN con la puerta cerrada, pero escribirlas sigue cerrado).
  La marca local (`lastKnownOnboardingTimestamp`) sí se escribe.
- `PrivateBirthKeyValueHandover` (el arreglo del ticket padre) sube las preferencias y el espejo del interruptor
  maestro al nacer la sesión privada, y NO esta señal: la decisión de Jürgen nombraba esas dos cosas.
- Consumidores de la señal: el «Caso B» de `PreferenceSyncService.checkForRemoteWipeSignal`,
  `ContentView.handleRemoteOnboardingCompleted` y `RestoreOfferGate` (`WelcomeRestoreView`).

## Qué hay que decidir

Si la subida al nacer la sesión privada reemite también la señal (con la hora de la activación), o se acepta.
Ojo con el ticket hermano `remote-onboarding-signal-ignores-the-session-axis`: el receptor de esa señal todavía
no mira el eje de sesión.

## Medido en 2.1 (triage 2026-10-08)

- `PreferenceSyncService.signalOnboardingCompleted` sigue escribiendo `lastOnboardingTimestamp` por el KV con la puerta cerrada, y `OwnerKeyValueStore` lo documenta hoy como hueco conocido («la señal de onboarding de esa activación, que tampoco llega»).
- `PrivateBirthKeyValueHandover` sube las preferencias y el espejo del interruptor maestro; la señal sigue fuera.
- **Decisión pendiente (Jürgen).** A) El handover reemite la señal con la hora de la activación. B) Se acepta y se documenta. **Recomendada: A**, pero junto con `remote-onboarding-signal-ignores-the-session-axis` (low), porque el receptor todavía no mira el eje de sesión.

Triage 2026-10-08: abierto · low → low · la señal sigue sin llegar (OwnerKeyValueStore lo documenta como hueco) y solo afecta a otro dispositivo con un vaciado pendiente.
