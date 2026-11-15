---
id: onboarding-2-3-permissions-inside-the-tutorial
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-permisos-dentro-del-tutor-pjrw (docs/onboarding-2-3/SPEC.md, Y23-17)
qa-status: not-replicable
qa-date: 2026-11-12
qa-notes: logica y efectos listos para los flujos de los pasos 1 a 4, que aun no existen; nada que probar a mano en este lote
---
# Bienvenida 2.3 · Permisos dentro del tutorial (Y23-17)

`TutorialPermissionMoments` reúne la regla de cada momento y su efecto, para que los lotes de los pasos 1 a 4 solo
pregunten qué toca:

- Voz o foto: primero el aviso de IA de Yala (una vez); en voz, después, el de iOS del micrófono. La cámara la pide iOS
  al elegir «Cámara». La fototeca no se pide nunca (medido: ningún `requestAuthorization` de fotos en la app).
- «Sí, recuérdame» (tarjeta del paso 1, aviso del presupuesto del paso 3): el aviso de iOS solo si nunca preguntó.
- Pagos planificados (paso 4): si iOS nunca preguntó, la hoja «¿Te avisamos antes de cada pago?» y luego iOS; si se
  negó, «Activa las notificaciones» con «Ir a Configuración» (`tutorialNotificationRetry`).

Además, el respaldo de las notificaciones al tercer registro se calla mientras Primeros pasos esté a medias: dentro del
tutorial se registran hasta cuatro de prueba y pediría sin que la persona eligiera un aviso.

Pruebas: `YalaTests/Bienvenida23BaseTests` (TutorialPermissions23Tests).
