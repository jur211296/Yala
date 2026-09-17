---
id: restore-beacon-may-not-have-synced-yet-on-a-fresh-install
status: backlog
priority: medium
area: "welcome, restore, beacon"
created: 2026-09-17
source: "review adversarial de `reinstall-without-network-has-no-cloud-door` (lente de reglas de área), 2026-09-17"
---

# Reinstalar CON red: el faro puede no haber llegado todavía, y Restaurar vuelve a negar los datos

## El problema, en lenguaje de usuario

Reinstalo Yala con buena conexión. La pantalla de Restaurar busca en iCloud, no encuentra nada —mis
datos están en la cuenta de Yala, no en CloudKit— y me dice **«No encontramos tus datos»**. Un minuto
más tarde, con el mismo móvil y la misma red, el mensaje sería el correcto.

## Medido (2026-09-17)

Los tres desenlaces de una búsqueda vacía (`WelcomeRestoreEmptyOutcome.resolve`) se deciden con dos
señales que llegan por **canales distintos**:

- El **snapshot de remote-config** lo sirve nuestro gateway, y `resolveEmptyState` lo FUERZA antes de
  decidir (`refreshIfDue(force: true)`), así que con red llega.
- El **faro** vive en el iCloud-KV y se lee con `store.bool(forKey:)` crudo
  (`CloudBeacon.isCloudAccountLinked`): nadie lo fuerza, y `NSUbiquitousKeyValueStore` entrega cuando
  iOS quiere, por `didChangeExternallyNotification`. `synchronize()` no baja datos, solo programa.

⇒ ventana real: con red, `cloudConfigKnown == true` y `beaconLinked == false` todavía ⇒ `.notFound`,
que afirma que no hay datos. Es el mismo bug que cerró
`reinstall-without-network-has-no-cloud-door`, un paso a la derecha.

## Por qué no se cerró ahí

Aquel ticket cerró el caso **sin red** (opción 2, decisión de Jürgen del 17-sep), donde las dos
señales están en blanco. Este caso tiene una señal buena y otra en camino, y distinguirlo pide esperar
o reintentar el faro — trabajo distinto. El hueco es **anterior**: el `.cloudPaused` del kill-switch
tenía exactamente el mismo problema desde el 2026-09-06.

## Lo que hay que decidir (Jürgen)

1. **Esperar al faro con tope** antes de decidir el desenlace, igual que se fuerza el config.
2. **Repintar al llegar**: suscribir la pantalla a `didChangeExternallyNotification` y re-resolver.
3. **No hacer nada** y dejar que lo cubra el botón «Reintentar», aceptando que el primer mensaje puede
   ser el equivocado.

## Criterios de aceptación

- [ ] Decidido si el desenlace espera al faro, se repinta al llegar, o se acepta el primer mensaje.

## Relación con otros tickets

- `reinstall-without-network-has-no-cloud-door` — cerró el gemelo sin red; de ahí sale este.
- `beacon-routes-only-never-blocks` — el faro en la otra rama del Welcome.
- `reentry-killswitch-closes-both-doors` — el `.cloudPaused` que arrastra el mismo hueco.
