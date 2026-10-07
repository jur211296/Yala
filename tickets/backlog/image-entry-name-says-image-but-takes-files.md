---
id: image-entry-name-says-image-but-takes-files
status: backlog
priority: medium
area: image, copy, l10n
created: 2026-10-07
updated: 2026-10-07
source: Jürgen, sesión gpt-4-1-nano-shuts-down-on-october-23 (2026-10-07)
---

# «Registro por imagen» acepta PDF: el nombre confunde

> **Grupo: para Jürgen** (nombre de una función). Su pregunta del 2026-10-07: «entonces el nombre "registro por
> imagen" podría cambiar? Para no confundir».

## Qué pasa

La entrada acepta una foto de la cámara, una imagen de Fotos y un **archivo** (imagen o PDF). Pero se llama «Registrar
con imagen» o «Registro por imagen», así que quien tiene su estado de cuenta en PDF no piensa en buscarla ahí.

## Dónde aparece el nombre (es, medido el 2026-10-07)

Son 11 claves en `Localizable.strings`, cada una en los 16 `.lproj` de la app:

- **Hoja:** `image.entry.title`.
- **Accesos directos:** `shortcut.imageEntry.title`, `shortcut.imageEntry.shortTitle` y
  `shortcut.imageEntry.opening`.
- **Control del Centro de control:** `control.imageEntry.label`, `control.imageEntry.displayName` y
  `control.imageEntry.intentTitle`.
- **Paywall:** `featureGate.imageInput`.
- **Consejo de Pro:** `tipkit.pro.imageInput.title`.
- **Siri:** `siriShortcuts.shortcut.image` y `siriShortcuts.phrase.image`. **Ojo:** cambiar la frase de Siri rompe la
  costumbre de quien ya la dice. Valorar mantener la vieja como sinónimo.

La ficha de la App Store y las capturas también lo nombran, pero son de Lola (`marketing/`): avisarle, no tocarlas desde
aquí.

## Propuestas (elegir una)

| | Nombre | A favor | En contra |
|---|---|---|---|
| A | **«Registrar con foto o archivo»** | Dice exactamente lo que acepta | Largo para el control y el atajo (≈ 28 caracteres) |
| B | **«Escanear»** | Corto; es como la gente llama a leer un recibo | En algunos idiomas suena a cámara, y no cubre «subir un PDF» |
| C | **«Leer un comprobante»** | Habla del resultado (recibo, captura, extracto) y no del formato | «Comprobante» es muy de Perú: hay que traducirlo por idea en los 10 idiomas |

Recomendación: **A** en la hoja y el paywall, donde hay sitio, y una forma corta (**«Foto o archivo»**) en el control y
el atajo. Leer `BRAND-VOICE.md` antes de escribir el copy final.

## Hecho cuando

- Las 11 claves dicen el nombre nuevo en los 10 idiomas de la app (sus 16 `.lproj`), con la batería de paridad de l10n en verde.
- La frase de Siri vieja sigue funcionando, o se decide expresamente retirarla.
- Lola tiene el aviso para la ficha y las capturas.
