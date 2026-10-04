---
id: chat-draft-card-redesign
status: backlog
priority: medium
area: chat
created: 2026-10-04
source: encargo 2026-10-04-improve-new-record-cards-in-yala-ai (tablero-mejorar-cards-de-registros-nuevos-en-yal-rdfd)
---

# Rediseño de la card de registro que propone Yala IA

## Qué espera de Jürgen

**Elegir una de las tres propuestas** (o una mezcla). Están en el lienzo, con el estado actual al lado y los
mismos datos en todas: https://claude.ai/artifact/N4DsKVRoqKaupAqwg8Feic

| | Qué es | A favor | En contra |
|---|---|---|---|
| **A · Fila de registro** *(recomendada)* | La card es la misma fila que luego se ve en Registros (icono de categoría, nota, subcategoría, importe), con píldoras tocables debajo: cuenta, fecha, etiqueta. Lo que falta va primero y en ámbar. | Al guardar no hay salto: se queda la fila con ✓. Dos registros caben en media pantalla. | Nota y etiquetas solo se editan en «Detalles». |
| **B · Recibo** | El importe grande y centrado; cuenta y fecha a la vista; etiquetas y nota plegadas; «Guardar» a todo lo ancho. | Lo más importante (cuánto) manda. | Más alta que A: con 3+ registros obliga a desplazar, y al guardar cambia de forma. |
| **C · Compacta + hoja** | Cada registro es una fila con ✕ y ✓. Tocarla abre una hoja sobre el chat con todos los campos. | La más corta; escala a muchos registros. | Cambiar la cuenta cuesta un toque más. |

Por qué A: el estado guardado de hoy (`compactRow`) **ya es** esa fila, así que la card pendiente y la guardada
pasan a ser la misma pieza; y se lee igual que el resto de la app.

## Lo que comparten las tres (y por eso no es parte de la elección)

- **El importe con su símbolo y dos decimales** (`S/ 120.50`), no `120.5 PEN`.
- **«Gasto» sin rojo.** El chip rojo tiñe el caso normal; la regla de `.claude/rules/swiftui-ds.md` es colorear la
  excepción (el ingreso).
- **«Guardar» apagado se ve apagado.** Medido el 2026-10-04 en el simulador: con la subcategoría sin elegir el botón
  está `disabled` (`canSave` falso) pero se pinta idéntico al activo, porque su fondo y su texto son explícitos y
  `disabled` no los atenúa. El usuario lo pulsa y no pasa nada.
- **«Editar»/«Detalles» no saca del chat.** Hoy `onEdit` + `dismiss()` cierran la hoja de Yala IA y abren el
  formulario: se pierde la conversación de vista. A y C lo resuelven dentro del chat (hoja encima); B mantiene un
  enlace al formulario completo. **Esto es decisión de Jürgen** si quiere conservar el salto al formulario.

## Lo medido (2026-10-04, en este árbol)

- La card vive en `Yala/App/Views/Chat/ChatTransactionDraftCard.swift`. **Ya tiene** editar en línea (monto, cuenta,
  subcategoría, fecha, etiquetas, nota), «Descartar» y «Editar». El encargo pedía esas funciones; no faltaba ninguna.
- `ChatDraftPreviewCard` (onboarding de Yala IA) es una copia decorativa que «replica el layout» de la real: el
  rediseño tiene que tocar las dos.
- Para verla sin red: `-uitest-chat-draft` (junto a `-uitest-ai-chat-ready -uitest-seed grupos`) abre el chat con
  dos borradores, uno completo y otro sin subcategoría.
- Capturas del antes: `capturas/antes-1.png` y `antes-2.png` del PR del encargo.

## Fuera de esto

Dictado, voz, imagen y vistas en grupos van después (encargo). Nada de proveedor ni coste de IA.
