---
id: image-note-uses-bank-template-instead-of-merchant
status: done
priority: high
area: "image, pdf, ai, inbox"
created: 2026-10-10
updated: 2026-10-10
source: reporte de Jürgen (2026-10-10 08:48) con un caso real; card tablero-la-lectura-de-imagen-pone-en-la-nota-tex-tkun
---

# La lectura de imagen pone en la nota texto del banco en vez del comercio

## Qué le pasaba al usuario

Leía una alerta de su banco con la cámara o desde Fotos y el registro salía con la nota «GROK XAI - Consumo con tarjeta
de crédito BCP». Tenía que ser «Grok (xAI)». La plantilla del banco, el número de operación o la tarjeta enmascarada
acababan en la nota, y la memoria de comercios aprendía esa nota fea.

## Qué cambia

- **La nota es el comercio limpio**: la marca conocida si se reconoce («Grok (xAI)», «Uber», «Netflix», «Amazon»),
  mayúsculas normales («WONG SAN ISIDRO» → «Wong San Isidro») y, si aporta, sucursal o ciudad. Nunca la plantilla del
  banco, el banco, números de operación, códigos de terminal ni asteriscos.
- **Vale para foto y PDF** (los dos pasan por `VisionDraftFactory.buildNote`).
- **Dos capas.** El prompt de la foto pide el comercio sin banco y la nota null o útil. `VisionNoteCleaner`
  (`Yala/App/Logic/`) limpia de forma determinista lo que el modelo deje pasar. Si todo es plantilla, conserva lo leído
  sin códigos: una nota con palabras de más es mejor que vacía.
- **Lo que no se toca:** las líneas de extracto sin comercio («Retiro cajero Miraflores», «Internal Transfer», «Abono
  haberes») se quedan enteras.

## Fuera

- **Voz y chat no**: su nota sale de lo que dice el usuario y una limpieza de plantilla se comería «pago de luz».
- **`ScreenshotSingleExtractor` y `ScreenshotListExtractor` no**: no los llama nadie fuera de sus tests.
- **Gateway sin cambios ni deploy**: el prompt vive en la app y el esquema ya trae `merchant` y `note`.

## Medido

Banco de IA, `gpt-6-luna` (la fila de producción), 50 imágenes con 12 alertas nuevas de BCP, Interbank, BBVA,
Scotiabank, Yape y Plin, 2 repeticiones: nota buena del **59 % al 96 %**; en las alertas de banco, de 11 a 24 sobre 24.
Monto, fecha y divisa siguen al 100 %. Un primer prompt más largo inventaba movimientos y se descartó. Informe:
`gateway/bench/results/2026-10-10-nota-despues-v2/REPORT-nota.md`.

## Device-QA (Jürgen)

Necesita un build con este cambio (TestFlight o Xcode con el scheme `Yala`).

1. Abre Yala y toca el botón de la cámara → **Fotos**.
2. Elige una captura real de una **alerta del BCP** de consumo con tarjeta (como la de Grok).
3. En la hoja de lo leído, mira la nota: tiene que ser el comercio («Grok (xAI)», «Wong San Isidro»…), **sin**
   «Consumo con tarjeta de crédito BCP», sin número de operación y sin asteriscos.
4. Repite con una **constancia de Yape** («¡Yapeaste!»): la nota tiene que ser el nombre de la persona, sin «Yape» ni
   el número de operación.
5. Si puedes, una tercera de otro banco (Interbank, BBVA o Scotiabank) o una página de PDF de tu estado de cuenta.
6. Pasa si las 2 o 3 notas nombran el comercio o la persona y no traen texto del banco. Si alguna sale mal, una captura
   de la alerta y de la nota basta para el siguiente ajuste.

## Barrido de QA (2026-10-10)

Cerrado en el barrido de QA 2026-10: el banco de IA alcanza: 24/24 alertas de banco con la nota limpia, el caso de Grok incluido, sin empeorar importe, fecha ni divisa (gateway/bench/results/2026-10-10-nota-despues-v2/REPORT-nota.md).
