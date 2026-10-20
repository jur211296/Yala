---
id: welcome-fresh-install-neutral-mount-lasts-one-launch
status: backlog
priority: low
area: "onboarding, modo-nube"
created: 2026-10-19
updated: 2026-10-19
source: "encontrado en `invite-on-a-fresh-install-mounts-the-icloud-mirror-after-a-relaunch` (2026-10-19)"
---

# El montaje neutro del Welcome en una instalación nueva dura un solo arranque

## En lenguaje de usuario

Reinstalo Yala, la abro y, en el Welcome, la cierro antes de elegir nada. Al abrirla otra vez, Yala ya está bajando los datos privados de mi iCloud aunque no elegí «privado».

## Lo medido (2026-10-19, leído en el código)

- `isFreshInstallForNeutralMount` exige que no exista el archivo del store; el propio montaje neutro lo crea. Sin `neutralMountArmed` (que solo arma el cierre de sesión) ni el neutro solo-grupos, el segundo arranque cae en `.iCloudMirror`.
- La entrada por enlace se arregló en `invite-on-a-fresh-install-mounts-the-icloud-mirror-after-a-relaunch` armando el neutro durable. El Welcome no se tocó: no lo pidió la card y su efecto no está medido en un aparato.

## Lo que habría que decidir

Si el primer arranque de una instalación nueva arma el neutro durable siempre (caduca al elegir en el Welcome), o se deja.
