---
id: image-reading-sends-the-full-resolution-photo
status: backlog
priority: medium
area: image, ai, cost
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H14)
---

# El registro por imagen sube la foto a resolución original

> **Grupo: para Jürgen.** Cambia coste y puede cambiar la calidad de lectura de un recibo largo.

## Qué pasa

`ImageVisionService.analyze` (`Yala/App/Services/ImageVision/ImageVisionService.swift:151-160`) convierte
la foto a JPEG al 80 % **sin reducirla** y la manda con `detail: auto`. Una foto de 12 MP son varios
megas en base64 que suben por datos móviles contra un timeout de 20 s
(`ProxyClientFactory.swift:27`). Se manda una petición por foto.

## Lo confirmado en fuente (https://developers.openai.com/api/docs/guides/images-vision, 2026-10-07)

- Los tokens de imagen se cuentan en parches de 32×32 px por un multiplicador del modelo:
  `gpt-4.1-nano` ×2,46, `gpt-4.1-mini` ×1,62, la familia 5.x ×1,2.
- En `gpt-4.1-mini`, `low`, `high` y `auto` usan el **mismo** tamaño (máx. 2 048 px y 6 144 parches):
  «low does not always use fewer tokens than high».
- En `gpt-5.6-luna`, `low` reduce a 512×512.
- Los límites de tamaño de `gpt-4.1-nano` ya no están publicados.

Cálculo propio para una foto de 1 536×2 048: ≈3 072 parches → ≈4 977 tokens en `gpt-4.1-mini`; en
`gpt-5.6-luna` con `high`, 3 000 tokens; con `low`, ≈231.

Ojo: `gpt-4.1-nano` se apaga el 23-oct (`gpt-4-1-nano-shuts-down-on-october-23`); este ticket se decide
**después** de ese, porque el modelo elegido cambia qué opción ahorra.

## Opciones

| | Qué se hace | A favor | En contra |
|---|---|---|---|
| **A** | Reducir en la app a 2 048 px de lado mayor antes de subir | Sube menos megas (menos fallos por timeout). Sin pérdida para el modelo: él reduce a ese tamaño igualmente | No baja tokens con `gpt-4.1-mini`; sí ahorra datos móviles |
| **B** | A + `detail: low` en el modelo que lo aproveche (familia 5.x) | Coste de imagen casi nulo en capturas de notificaciones bancarias | Un recibo largo o un extracto con muchas filas puede leerse peor; hay que probarlo con fotos reales |
| **C** | OCR en el iPhone (el código existe en `Yala/App/Services/ImageOCR/` y hoy no se usa) y mandar **texto** al modelo | Sin imagen en la petición: lo más barato y lo más privado | Pierde la disposición visual (columnas, totales); más código que mantener |

## Recomendación

**A siempre** (es barato y mejora la fiabilidad), y **B** si se migra a la familia 5.x, decidido con una
prueba de 20-30 fotos reales (recibos, capturas, extractos). C solo si el modo privado lo pide (card de
partir la IA por modo).

## Medido el 2026-10-07 (banco de la sesión gpt-4-1-nano-shuts-down-on-october-23)

Resolución y `detail` se midieron como parte de la elección del modelo de `photo.read`: resultados y el `maxEdge` elegido
en `docs/ai-model-bench-2026-10.md`. El reescalado en la app es el paso 6 de
`ai-every-call-sends-its-task-and-passes-the-bench`.

## Hecho cuando

- Decisión anotada aquí.
- Si A: test que fija el lado mayor ≤ 2 048 px en la imagen que se manda.
