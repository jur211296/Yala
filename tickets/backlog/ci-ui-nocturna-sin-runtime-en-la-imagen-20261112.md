---
id: ci-ui-nocturna-sin-runtime-en-la-imagen-20261112
status: backlog
priority: medium
area: ci
created: 2026-11-16
updated: 2026-11-16
source: encontrado al arreglar el simulador del job tests (tickets/done/2026-11-16-ci-simulador-runner.md)
---

# La UI nocturna no tiene simulador válido en la imagen 20261112 del runner

## Qué pasa

En la imagen `xcode-27-arm64` 20261112.0361.1, el Xcode 27.1 del CI ya no ofrece el runtime iOS 27.0
como destino. El job `tests` lo resuelve cayendo al iOS 27.2 (modo tolerante: los unit corren ahí).
El job `ui` va en modo estricto (`SIM_HASTA_SDK=si`) porque con Xcode 27.1 el paquete de UI no carga
en el 27.2 (`.claude/rules/ci-qa.md`). En esa imagen no le queda ningún runtime: cada tanda fallará
en «Simulador del runner» con la lista de destinos que xcodebuild sí ve. No hay verde falso, pero la
suite de UI no corre esa noche.

Inferido, no medido: la nocturna aún no ha caído en esa imagen con el script nuevo.

## Salidas

1. Pasar el CI a Xcode 27.2 (`qa/scripts/ci-xcode.sh`). El 27.2 casa con el runtime 27.2 completo.
   Cambia el compilador de los unit que frenan el merge, así que según la regla va con la release:
   decisión de Jürgen.
2. Descargar en el paso del simulador un runtime que este Xcode vea (`xcodebuild -downloadPlatform iOS
   -buildVersion …`). Hay que medir cuánto tarda en el runner.

## Hecho cuando

La nocturna en la imagen 20261112 corre la suite de UI entera, o se decide de forma explícita
aceptar la pérdida hasta la release.
