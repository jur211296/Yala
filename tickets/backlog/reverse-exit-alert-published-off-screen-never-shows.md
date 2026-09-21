---
id: reverse-exit-alert-published-off-screen-never-shows
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` (2026-09-21), lente del aviso"
---

# El aviso de la vuelta que termina con la pantalla cerrada no sale al abrirla

## El problema, en lenguaje de usuario

La vuelta a iCloud se rinde mientras estoy en otra parte de la app, o durante el arranque. Cuando entro en «Dónde viven
tus datos» no me sale ningún aviso: solo la nota pequeña de la tarjeta, que es fácil no ver.

## Por qué pasa (medido el 2026-09-21)

`StorageSettingsView` observa el aviso así:

```swift
.onChange(of: controller?.lastError) { _, newValue in
    showError = (newValue != nil)
}
```

**Sin `initial: true`**. Quince líneas antes, el aviso hermano —el bloqueo de identidad— lo lleva, y con el porqué
escrito al lado: «un aviso publicado mientras la persona no tenía esta pantalla delante sale al volver a ella».

`resume()` corre también desde el arranque (`resumeIfNeeded`), así que el techo puede vencer ahí: el aviso se publica,
nadie lo ve, y al abrir Almacenamiento después no sale. Además `lastError` se queda pegado con un texto que ya nadie va
a enseñar.

## Por qué no se arregló de paso

El aviso del techo **hereda** una decisión escrita del aviso del rechazo del claim: «la alerta vive en la pantalla de
Almacenamiento y solo sale con ella delante, así que fuera de ella queda solo la nota». Los dos escriben el mismo
`lastError`, así que poner `initial: true` cambia el comportamiento de los dos y reabre esa decisión. Eso es una
decisión de producto, no un arreglo.

## Qué habría que decidir

1. **Si un aviso de la vuelta debe esperar a la persona**, o si la nota de la tarjeta basta cuando no estaba delante.
   La respuesta puede no ser la misma para los dos avisos: el del claim deja la tarjeta con su nota y nada más; el del
   techo tampoco deja efectos, así que la nota es igual de todo lo que hay.
2. **Si la respuesta es que sí**, hay que decidir cuánto dura ese aviso guardado: uno de hace tres días saliendo al
   abrir la pantalla sería peor que no tenerlo.

## Criterios de aceptación

- [ ] Decidido 1 y 2 antes de tocar código.
- [ ] Lo que se decida vale para los DOS avisos que escriben `lastError`, o se separan explícitamente.
- [ ] Si se pone `initial: true`, un aviso ya cerrado por la persona no vuelve a salir al re-entrar.

## Relacionado

- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el aviso nuevo que hereda la asimetría.
- `reverse-claim-rejection-has-no-way-out-in-the-client` — de donde viene la decisión escrita.
