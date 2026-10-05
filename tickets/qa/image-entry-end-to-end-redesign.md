---
id: image-entry-end-to-end-redesign
status: qa
priority: high
area: "image"
created: 2026-10-04
updated: 2026-10-04
qa-status: needs-testing
source: encargo 2026-10-04-mejorar-el-registro-por-imagen-de-punta-a-punta · tablero tablero-mejorar-el-registro-por-imagen-de-punta-g5wl
---

# Rediseñar el registro por imagen de punta a punta

## Estado

**Decidido por Jürgen (2026-10-04): propuesta C** (lienzo: https://claude.ai/artifact/LGHvfUuCwQU4Fqzk4mF1eV).
Construida el mismo día. Falta el device-QA de abajo: cámara, Fotos y el modelo de verdad no se prueban en el
simulador.

## Lo construido

- Una hoja a media altura con **Cámara · Fotos · Archivo** (imagen o PDF, su primera página). La cámara solo sale si
  el aparato la tiene; es un permiso nuevo (`NSCameraUsageDescription`, 16 idiomas).
- **Sin cuenta atrás**: al elegir, lee con la foto a la vista, una línea del color del tema que la recorre, el paso
  («Buscando el importe» / «Foto 1 de 3») y Cancelar.
- **«Esto leí» en la misma hoja**, con la fila de voz C (`VoiceDraftReviewCard`): lo que falta en ámbar, Guardar
  apagado hasta completarlo, «Guardar N» con varias. Guardar va por `DraftService.approveDraft`, como la Bandeja.
  «Otra foto» descarta lo pendiente y vuelve a elegir; cerrar deja los borradores en la Bandeja.
- **Varias fotos**: las que no se leen se avisan («1 foto no se pudo leer · Reintentar») y se reintentan sin perder
  lo leído.
- **Fallos en la hoja, sin alert**: sin conexión (Reintentar con las mismas fotos), sin importe, imagen ilegible,
  permiso de cámara (Abrir Configuración), servicio no disponible y el genérico «No pude leerla esta vez».
- **Compartir una foto a Yala pide Pro** como el resto de entradas.

## Guion de device-QA (iPhone físico, build de TestFlight)

1. Panel › botón de imagen. **Esperado:** hoja a media altura con Cámara, Fotos y Archivo.
2. Cámara (primera vez): **esperado** el aviso de permiso con el texto de Yala. Acepta, fotografía un recibo real.
   **Esperado:** «Leyendo tu foto…» con la foto y la línea moviéndose; luego «Esto leí» con comercio, importe y
   categoría.
3. Guardar. **Esperado:** la fila pasa a «Registrado» y el disponible del Panel baja ese importe.
4. Fotos › elige tres recibos. **Esperado:** «Foto 1 de 3…», luego una fila por registro y «Guardar 3».
5. Archivo › un PDF de un recibo. **Esperado:** lo lee como una foto (su primera página).
6. Modo avión › elige una foto. **Esperado:** «Sin conexión» con Reintentar; quita el modo avión y Reintentar lee.
7. Ajustes de iOS › Yala › Cámara apagada › vuelve y toca Cámara. **Esperado:** «Yala no puede usar la cámara» con
   «Abrir Configuración».
8. Desde Fotos, compartir un recibo a Yala con una cuenta sin Pro. **Esperado:** el aviso de Pro, no la lectura.

## Evidencia (simulador, 2026-10-04)

`~/Claude/worktrees/_capturas/2026-10-04-mejorar-el-registro-por-imagen-de-punta-a-punta/`: `antes-0…4` y
`despues-1-elegir`, `-2-leyendo`, `-3-lo-leido`, `-4-guardado`, `-5-una-foto-fallo`, `-6-sin-importe` (seam
`-uitest-image-result`). Guardar bajó el disponible exactamente S/ 251,81.

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
