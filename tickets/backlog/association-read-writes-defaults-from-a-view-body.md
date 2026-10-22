---
id: association-read-writes-defaults-from-a-view-body
status: backlog
priority: low
area: "groups, modo-nube"
created: 2026-09-11
source: "review adversarial de `cloud-killswitch-hides-the-only-door-to-detach-groups`, lente de estados"
updated: 2026-10-08
---

# Leer la cuenta de grupos asociada puede ESCRIBIR en preferencias, y se lee desde un body

## Lo medido (2026-09-11)

`GroupsAccountAssociation.readLocal()` borra la clave cuando el payload no se puede decodificar
(`GroupsAccountAssociation.swift:132-147`, la escritura está en `:144`):

```swift
} catch {
    defaults.removeObject(forKey: Self.localKey)   // ← escritura desde un body de SwiftUI
    return nil
}
```

Ese `read()` se llama ahora desde el body de dos vistas (la sección de Grupos y, vía
`GroupsAssociationPresence`, la fila de Ajustes). Y `AppPreferences` tiene un observer de
`UserDefaults.didChangeNotification` sobre ese mismo store (`AppPreferences.swift:971-978`) que dispara
`loadFromDefaults()` en el MainActor.

**No es un bucle** —verificado: `loadFromDefaults` no escribe y la clave desaparece tras el primer
borrado— pero es un efecto secundario en un body que SwiftUI evalúa N veces y en cualquier orden. Es la
clase de escritura que este repo ya pagó una vez (el «lavado» documentado en `AppPreferences.swift:997`).

**Y el coste de lectura no es cero para el segundo móvil:** sin espejo local, `read()` cae a
`readICloud()` y son hasta **6 accesos a `NSUbiquitousKeyValueStore.default` por evaluación del body**
(`:163, 166, 167, 170, 171, 172`), sin caché.

## Lo que se espera

1. Sacar el borrado del camino de LECTURA (marcar el payload corrupto y limpiarlo en un punto de
   escritura, o no limpiarlo: el decode ya devuelve `nil` y el iCloud-KV es la copia autoritativa).
2. Valorar una caché corta para la lectura del iCloud-KV, o que el `read()` de la fila salga del mismo
   tick que el de la sección.

## Medido en 2.1 (triage 2026-10-08)

- `GroupsAccountAssociation.readLocal()` (`Yala/Services/CloudSync/GroupsAccountAssociation.swift`, se mudó desde `Services/Groups`) sigue con `defaults.removeObject(forKey: Self.localKey)` en el `catch` del decode.
- `GroupsAssociationSection.accountDisplayName`, una computed property del body, sigue llamando a `GroupsAccountAssociation.shared.read()`, y `read()` sigue cayendo a `readICloud()` sin caché.

Triage 2026-10-08: abierto · low → low · la escritura en el camino de lectura y la lectura desde el body siguen; sin efecto visible medido, es higiene.
