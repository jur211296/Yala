---
id: chat-draft-card-redesign
status: qa
priority: medium
area: chat
created: 2026-10-04
updated: 2026-10-04
source: encargo 2026-10-04-improve-new-record-cards-in-yala-ai (tablero-mejorar-cards-de-registros-nuevos-en-yal-rdfd)
---

# Rediseño de la card de registro que propone Yala IA

## Decidido (Jürgen, 2026-10-04)

- **Propuesta A.** La card es la fila del registro con píldoras tocables.
- **«Detalles» abre una hoja a media altura sobre el chat**, que sube a grande al arrastrarla o con el teclado. El
  formulario completo queda como enlace al pie de la hoja.
- **Cada dato se elige con el MISMO selector que Nuevo registro**, en la card y en la hoja: subcategoría con su
  rejilla de iconos, cuenta, calendario y etiquetas. «Que la experiencia sea la misma».

Implementado en la rama `encargo/2026-10-04-chat-draft-card-a`. Una consecuencia de usar el calendario de Nuevo
registro: la fecha ya no puede ser futura, igual que allí (antes el selector de la card lo permitía).

## Guion de QA en el iPhone

1. Abre Yala IA y escribe «Gasté 45 en un taxi y 120 en el súper».
2. Comprueba que cada registro sale como una fila (icono, nota, importe `S/ 45.00`) con píldoras debajo.
3. Si alguno sale sin subcategoría: su «Guardar» se ve apagado y hay una píldora ámbar. Tócala: se abre la rejilla
   de subcategorías de Nuevo registro. Elige una; la píldora desaparece y «Guardar» se enciende.
4. Toca la píldora de la cuenta: sale el selector de cuentas de Nuevo registro. Elige otra con otra divisa y mira
   que el importe cambia de símbolo.
5. Toca la fecha: sale el calendario de Nuevo registro.
6. Toca «Detalles»: hoja a media altura con el chat detrás. Cambia la nota y la fecha desde ahí; «Listo» cierra y
   la card refleja los cambios.
7. Desde «Detalles», «Abrir en el formulario completo»: se cierra el chat y abre Nuevo registro relleno.
8. Pulsa «Guardar» en una card: queda la misma fila con «✓ Registrado».

## Propuestas que se valoraron

| | Qué es | A favor | En contra |
|---|---|---|---|
| **A · Fila de registro** *(recomendada)* | La card es la misma fila que luego se ve en Registros (icono de categoría, nota, subcategoría, importe), con píldoras tocables debajo: cuenta, fecha, etiqueta. Lo que falta va primero y en ámbar. | Al guardar no hay salto: se queda la fila con ✓. Dos registros caben en media pantalla. | Nota y etiquetas solo se editan en «Detalles». |
| **B · Recibo** | El importe grande y centrado; cuenta y fecha a la vista; etiquetas y nota plegadas; «Guardar» a todo lo ancho. | Lo más importante (cuánto) manda. | Más alta que A: con 3+ registros obliga a desplazar, y al guardar cambia de forma. |
| **C · Compacta + hoja** | Cada registro es una fila con ✕ y ✓. Tocarla abre una hoja sobre el chat con todos los campos. | La más corta; escala a muchos registros. | Cambiar la cuenta cuesta un toque más. |

Por qué A (la recomendada): el estado guardado de hoy (`compactRow`) **ya es** esa fila, así que la card pendiente y la guardada
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
