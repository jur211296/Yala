---
id: image-entry-end-to-end-redesign
status: in-progress
priority: high
area: "image"
created: 2026-10-04
source: encargo 2026-10-04-mejorar-el-registro-por-imagen-de-punta-a-punta · tablero tablero-mejorar-el-registro-por-imagen-de-punta-g5wl
---

# Rediseñar el registro por imagen de punta a punta

## Por qué está parado

~~Espera la decisión de Jürgen~~ — **Decidido por Jürgen (2026-10-04): propuesta C** (lienzo:
https://claude.ai/artifact/LGHvfUuCwQU4Fqzk4mF1eV). En construcción.

## Qué se ve hoy (recorrido del 2026-10-04, base `5a7f6f9e6`)

Capturas en `~/Claude/worktrees/_capturas/2026-10-04-mejorar-el-registro-por-imagen-de-punta-a-punta/`.

- **Entrar.** Panel «+» › Imagen abre una hoja a pantalla completa con un título «Imagen», un círculo decorativo,
  seis chips («Recibos de compra», «Capturas bancarias»…), tres ejemplos de texto y, abajo del todo, un botón
  circular que abre Fotos. **No hay cámara ni Archivo**: un PDF solo entra soltándolo en iPad.
- **Esperar.** Al elegir la foto, una cuenta atrás 3-2-1 («Analizando en 3…»), la misma que voz ya retiró.
  Después, «Procesando… 1/1 · Extrayendo datos de la imagen», **sin Cancelar** (leído en el código: en el
  simulador el servicio falla al instante y esta pantalla no llega a verse).
- **Confirmar.** Con un registro salta a otra hoja, «Editar borrador» (formulario largo, «Aprobar» /
  «Aprobar luego»). Con varios, una pantalla «N transacciones detectadas» y «Ir a bandeja»: no se revisan aquí.
- **Fallar.** Un alert «Error» del sistema. Un fallo del servicio se lee como «No se detectaron transacciones en
  la imagen» (ticket `image-entry-network-failure-reads-as-no-transactions`); con varias fotos, las que fallan
  desaparecen sin aviso (`image-entry-multi-photo-drops-failures-silently`).

## Las tres propuestas

Dos ejes: **cómo se captura** (hoja con Cámara/Fotos/Archivo, o la cámara directamente) y **dónde se confirma**
(el formulario de siempre, o la fila con píldoras en la misma hoja, como voz #351).

| | Captura | Confirmación | Tamaño |
|---|---|---|---|
| **A** | Hoja media: Cámara · Fotos · Archivo | Lee en la hoja; luego el formulario / la Bandeja de hoy | El más pequeño |
| **B** | La cámara abre directa (detecta el recibo y dispara sola); Fotos y Archivo en la cámara | «Esto leí» con píldoras sobre la foto | El más grande: cámara propia |
| **C** | Hoja media: Cámara · Fotos · Archivo | «Esto leí» con píldoras en la misma hoja; varias fotos, una fila cada una y «Guardar N» | Gemelo de voz C |

Común a las tres: sin cuenta atrás; leer con la foto a la vista y Cancelar; fallos en la hoja, en lenguaje de
usuario y con salida; color del tema.

## Hallazgos que salieron (con ticket propio)

- `image-entry-network-failure-reads-as-no-transactions` (high)
- `image-entry-multi-photo-drops-failures-silently` (medium)
- `share-extension-image-skips-pro-gate` (medium, pide decisión)
- `ipad-drop-unreadable-file-fails-silently` (low)

## Para quien implemente

- No existe seam del servicio de visión: para capturar y probar el resultado sin red hace falta uno tipo
  `-uitest-image-result one|incomplete|two|none`, con el molde de `-uitest-voice-result` (#351).
- `ImageOCRService` / `ImageClassifier` solo los usan tests: no son parte del flujo.
- Cámara y Archivo son entradas nuevas (`fileImporter` para PDF, reusando el render de la página 1 de
  `ReceiptDropHandler`). El modelo y el proveedor de visión no cambian.
