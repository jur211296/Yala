---
id: 2026-11-16-ci-simulador-runner
status: done
priority: high
area: ci
created: 2026-11-16
updated: 2026-11-16
source: encargo «CI: el script del simulador vuelve a encontrar un destino válido en el runner»
qa-status: not-replicable
qa-notes: es del CI, sin camino en un iPhone; lo vigila el banco ci-simulador-test.sh en coverage-index y cada corrida del job tests
---

# El CI crea el simulador en un runtime que el Xcode del runner ya no ofrece como destino

## Qué pasó

La corrida de `2.3` del 2026-11-16 (run 43807611829) cayó en «Build for testing» con exit 70:
`Unable to find a device matching … id:<UDID>`. `ci-simulador.sh` había creado el iPhone 17 Pro en el
runtime iOS 27.0 (24A434) sin error, pero `xcodebuild` con el esquema «Yala Dev» solo listaba
iPhones de iOS 27.1 y 27.2.

Medido en los logs: la imagen de ese run era `xcode-27-arm64` **20261112.0361.1**. Los runs verdes
de antes y de después (43795639979, 43811798736, 43818274245, 43833403596) cayeron en la
**20261104.0337.1**, con el mismo runtime 27.0 (24A434) y el mismo Xcode 27.1 (27A9275). GitHub
despliega la imagen nueva poco a poco: el rojo vuelve cada vez que un job cae en ella.

## Qué se hizo

- `qa/scripts/ci-simulador.sh`: elegido o creado el device, lo valida con
  `xcodebuild -showdestinations` del esquema. Si no lo ve, excluye ese runtime y busca otra vez con
  el orden de siempre (hoy: crea el iPhone 17 Pro en el 27.2, con aviso de «más nuevo que el SDK»).
  Si no queda ninguno, falla con la lista de destinos iOS que xcodebuild sí ve. Si
  `-showdestinations` no contesta, avisa y sigue.
- `qa/scripts/ci-simulador-test.sh`: el `xcodebuild` falso contesta `-showdestinations`; casos 18-22.
  Con la validación apagada, los cinco caen.
- `qa.yml`: solo el comentario del job `tests`.

## Lo que queda abierto

- En la imagen 20261112, el job `ui` (modo estricto) no tendrá runtime válido: el 27.2 no carga el
  paquete de UI con Xcode 27.1 y el 27.0 no se ve. Fallará con el motivo en vez de correr cero
  tests. La salida es subir el CI de Xcode, que va con la release (regla `ci-qa.md`).
