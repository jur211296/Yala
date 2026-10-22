---
id: sync-runtime-safety-note-assumes-every-prod-device-is-icloud
status: backlog
priority: very-low
area: modo-nube
created: 2026-09-10
updated: 2026-10-08
source: "medido el 2026-09-10 al alinear el percent de la elección nube"
---

# El argumento que justifica tener el motor de sync encendido dice «todos los devices de producción son .icloud», y ya puede no ser verdad

## Qué pasa

`Yala/Services/CloudSync/CloudSyncFlags.swift:225-235` sostiene el encendido de
`syncRuntimeEnabled = true` (ya encendido, I14/P1) con tres puntos. El segundo, medido el
2026-09-10:

```swift
///  (b) TODOS los devices en producción son `.icloud` → el guard de `storageMode` de `start()` (P0)
///      corta ANTES de cualquier red/mutación;
```

Esa frase describía el parque de julio. Desde que producción sirve
`CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT = 100` (medido el 2026-09-09), el Welcome ofrece el alta
born-cloud y **un usuario nuevo puede nacer `.cloud` en producción**. La clase de usuario que el
punto (b) declaraba inexistente ya puede existir.

## Por qué importa, y por qué NO es un bug

El comportamiento es el correcto: un usuario born-cloud **debe** tener el runtime corriendo. Lo que
caducó es el **argumento**, no el código.

El daño es de lectura: este bloque es de los que se abren en mitad de un incidente para decidir si
el motor puede estar tocando datos. Quien lo lea hoy puede concluir que en producción el runtime
nunca pasa del primer guard, y eso ya no se sostiene solo. El punto (a) tiene un precedente idéntico
anotado en el propio comentario: «Antes de D-R1 paso 1 este punto era más fuerte… Ya no».

## Lo que hay que hacer

- [ ] Re-escribir (b) diciendo lo que hoy es verdad: los devices **migrados o nuevos por la card
      born-cloud** son `.cloud`, y para ellos el guard de `storageMode` NO corta — que es el diseño.
- [ ] Decir de qué depende hoy la seguridad de tenerlo encendido para el resto del parque.
- [ ] Comprobar si hay ALTAS born-cloud reales en producción (requiere mirar el backend; no se hizo
      aquí). El número cambia el tono de la nota, no su corrección.

## Fuera de alcance

Apagar `syncRuntimeEnabled` o cambiar el percent. Esto es una premisa mal escrita, no una decisión
de rollout.

## Relacionados

- `wrangler-prod-onboarding-choice-percent-drift`

## Medido en 2.1 (triage 2026-10-08)

- El texto sigue intacto y se movió: el punto (b) está en `CloudSyncFlags.swift:588`, dentro del docblock de `syncRuntimeEnabled` (`:585-593`).
- Ninguno de los commits de `CloudSyncFlags.swift` desde el 2026-09-10 reescribe ese bloque.
- Por qué very-low: es un comentario de mantenimiento. El comportamiento es el correcto.

Triage 2026-10-08: abierto · medium → very-low · El punto (b) del docblock de syncRuntimeEnabled sigue diciendo que todos los devices de producción son .icloud; es un comentario, no un fallo de código
