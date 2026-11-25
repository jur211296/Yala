Yala
# Esto leí: moneda editable, descripción con más peso y sin hueco arriba
---
toca: Yala/App/Views/Voice/VoiceDraftReviewCard.swift,Yala/App/Views/Image/DraftNoteInlineEditor.swift,Yala/App/Views/Chat/ChatDraftFieldSheet.swift,YalaUITests/EstoLei/,YalaTests/EstoLeiAjustesCard/,docs/qa/esto-lei-ajustes-2026-11-25/,capturas/,tickets/backlog/2026-11-25-esto-lei-moneda-descripcion-sin-hueco.md,tickets/done/2026-11-25-esto-lei-moneda-descripcion-sin-hueco.md
esfuerzo: medium
cierre: cierra-sola
---

## Contexto
Jürgen probó la hoja «Esto leí» que aparece después de leer una foto (25-nov, 8:04 Lima). Dijo que «está muchísimo mejor esta vista», pero pidió tres ajustes. Su captura está en la Mini: `~/Claude/flota/compartido/yala/esto-lei-2026-11-25/captura-jurgen.png`. Ábrela antes de empezar.

En la captura se ve una tarjeta centrada con:
- el comercio «Claro», en letra fina y gris claro;
- el monto S/ 113.96;
- el chip de categoría, con «Personal · Esencial» debajo;
- los chips «Hoy», «BCP Crédito» y «#».

Arriba a la derecha está el botón «Ver todo», que deja un hueco vacío arriba a la izquierda.

La tarjeta es `VoiceDraftReviewCard` (`Yala/App/Views/Voice/VoiceDraftReviewCard.swift`): el `seeAllButton` va en `overlay(alignment: .topTrailing)` y el `padding(.top, DS.Spacing.xxxxl)` le reserva sitio. La descripción usa `DS.Typography.body` con `.secondary`, o `DraftNoteInlineEditor` cuando se edita ahí mismo. Hoy la moneda es `AmountCurrencyCapsule` con `options: []`, sin menú: la moneda es la de la cuenta. Nuevo registro (`NewTransactionView`, `AmountCurrencyCapsule` cerca de la línea 1299) sí deja elegir la moneda, y `AccountSelectorSheet` recibe `currencyScope: viewModel.amountCurrencyCode` (línea ~655) para acotar las cuentas. Desde la tarjeta, la cuenta se elige con `ChatDraftFieldSheet`, que hoy llama `AccountSelectorSheet` sin acotar por moneda.

## Qué se pide (lo que pidió Jürgen, en este orden)
1. **Moneda editable.** S/ se puede tocar, igual que en Nuevo registro: mismas opciones de moneda y la misma cápsula. Al elegir una moneda, la lista de cuentas del chip de cuenta muestra solo las cuentas de esa moneda, con el mismo `currencyScope` y el mismo comportamiento de respaldo que Nuevo registro. Si la cuenta elegida no es de la nueva moneda, haz lo mismo que hace Nuevo registro en ese caso. Reusa lo que ya existe; no armes un selector nuevo.
2. **Más peso a la descripción.** «Claro» hoy se ve muy fina y clarita. Súbele el peso y el contraste (por ejemplo, `.primary` y semibold o `headline`, con la jerarquía de Nuevo registro). Que se vea también cuando se edita ahí mismo (`DraftNoteInlineEditor` centrado). El monto sigue siendo lo más grande.
3. **Quitar el hueco de arriba a la izquierda.** Jürgen dio estas ideas: «Podemos hacer una o todas»:
   - rellenarlo de forma bonita;
   - alinear la tarjeta a la izquierda en vez de centrada;
   - sacar «Ver todo» de ahí y poner un chevron a la derecha, centrado en vertical en la tarjeta, para liberar esa primera fila.

   **Por defecto, haz la tercera:** el chevron a la derecha centrado, que abre lo mismo que «Ver todo» (`onOpenDetails`), y saca el padding superior extra. El chevron tiene un objetivo de toque de 44 pt como mínimo y conserva el `accessibilityIdentifier("esto_lei_ver_todo")` y la etiqueta de accesibilidad de «Ver todo». Si al verla en el iPhone combinarla con otra idea se ve claramente mejor, hazlo. En «Decidido sin consultar» anota qué elegiste y por qué, con capturas.

Antes de diseñar, mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración (no copies marcas ni pantallas).

Tickets: crea `tickets/backlog/2026-11-25-esto-lei-moneda-descripcion-sin-hueco.md` y, al cerrar, muévelo a `tickets/done/`. Las pruebas unitarias nuevas van en `YalaTests/EstoLeiAjustesCard/`, que es una carpeta nueva. Actualiza las pruebas de interfaz de `YalaUITests/EstoLei/` que dependan del botón «Ver todo» en su sitio actual.

## Presupuesto de pruebas de interfaz
- Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
- Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
- Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
- Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva); nada de bucles de 10 min ni comandos que se pasen del límite y queden en segundo plano a ciegas.
- Antes de compilar en iOS mira la carga: si otra sesión compila con xcodebuild en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.
- Dispositivo: tienes permiso para usar el iPhone 14 conectado por DeviceMCP. Un segundo simulador solo si estás en la Max; en la Mini, como máximo uno. Pipeline serial: limpiar, compilar con `xcodebuild -jobs 2` sin simulador encendido, encender uno, probar y apagarlo. Al cerrar, apaga y borra los simuladores que usaste, tu DerivedData y las cachés de XcodeBuildMCP de los worktrees retirados, sin preguntar.

## Dependencias
La sesión arranca sobre `origin/2.3` y no espera el CI ni el merge del PR anterior. Justo antes de abrir el PR, haz `git fetch` y un solo rebase sobre 2.3. Después compila y prueba en el simulador una vez. Solo hay que esperar un merge si otra sesión toca el mismo archivo.

## Qué NO hay que tocar
- Nada fuera de `toca:`. Nunca `Yala/`, `YalaTests/`, `YalaUITests/` ni `tickets/` enteros, y nunca `Yala/Resources`.
- No toques la lista de varios borradores (`MultiDraftReviewList`), salvo que comparta código con la tarjeta.
- No toques la lógica de lectura ni la elección automática de cuenta.
- Si hace falta un texto nuevo en `L10n` o un ajuste mínimo en `AccountSelectorSheet` o `NuevoRegistroB1Pieces`, que están fuera de `toca:`, hazlo mínimo y anótalo en «Decidido sin consultar». Si puedes, reusa los textos que ya existen.

## Cómo se sabe que está bien
- En el iPhone 14, con una foto que tenga un solo borrador, se cumplen estas cuatro cosas:
  - al tocar S/ se puede elegir otra moneda;
  - el chip de cuenta muestra solo las cuentas de esa moneda;
  - «Claro» se lee con claridad;
  - ya no queda el hueco arriba a la izquierda, y el chevron abre el editor completo.
- Las pruebas unitarias nuevas pasan, y también las de interfaz de `EstoLei` que tocaste.

## Cómo entregar
- Un PR contra 2.3, sin firma de IA. Deja el auto-merge activado y cierra; no esperes al CI.
- Deja `capturas/antes.png` y `capturas/despues.png`.
- **Entrega final:** artifact visual público de Claude con el antes y el después en el iPhone 14 de los tres ajustes, y la opción elegida para el hueco con su motivo. Tiene que facilitar decidir: nada de Markdown, PDF ni documento de puro texto. El link va en «Qué salió».
- Al cerrar, mueve la card del tablero «Esto leí: moneda editable, descripción con más peso y sin hueco arriba» a done con `tablero mover tablero-esto-lei-moneda-editable-descripcion-con-oefq --a done --agente frank`.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Todo texto en español neutro latinoamericano.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada». Usa el prefijo `BLOQUEANTE:` solo si algo de verdad impide seguir.

## Paso 0 — decisiones

> Resueltas en autónomo (modo semi, sin nadie delante): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué cambia al elegir otra moneda en la tarjeta?** → La cuenta del borrador, como en Nuevo registro y la Bandeja: la misma si ya está en esa moneda, la línea de su tarjeta en esa moneda, o la primera cuenta en esa moneda (`AmountCurrencyMenuLogic.target`). Se guarda en el borrador al momento.
Por qué: en Yala la moneda del monto es la de la cuenta; el borrador no guarda moneda propia. Alternativa descartada: una moneda suelta en el borrador sin cuenta, que no existe en el modelo y obligaría a migrar.

**D2 · ¿Qué monedas ofrece?** → Las de las cuentas activas y propias (sin archivadas ni de sistema), la actual primero; con una sola moneda la cápsula no abre nada, igual que Nuevo registro.
Por qué: mismo componente y misma lógica (`AmountCurrencyCapsule` + `AmountCurrencyMenuLogic.options`).

**D3 · ¿Cómo se acota el chip de cuenta?** → `ChatDraftFieldSheet` recibe `currencyScope` opcional (por defecto `nil`) y lo pasa como `currencyScope` y `routingCurrency` al `AccountSelectorSheet`; solo la tarjeta de «Esto leí» lo pone. Sin cuentas en esa moneda, el selector enseña todas con su aviso (respaldo de Nuevo registro).
Por qué: los otros que usan `ChatDraftFieldSheet` (chat, varios borradores) no cambian.

**D4 · Peso de la descripción** → `DS.Typography.headline` (17 semibold) en `.primary`, en el texto y en el editor centrado. El editor de la lista de varios (no centrado) no cambia.
Por qué: sube peso y contraste sin competir con el monto (40 pt). `title` de Nuevo registro sería demasiado en una tarjeta.

**D5 · El hueco de arriba** → Opción 3 por defecto: chevron a la derecha centrado en vertical, objetivo de toque de 44 pt, mismo id y etiqueta de «Ver todo»; fuera el relleno superior extra. El contenido gana un margen igual a cada lado (20 pt) para seguir centrado. Si en el iPhone se ve claramente mejor combinada, se decide con capturas.
Por qué: es la que pidió por defecto el encargo y libera la fila entera.

**D6 · ¿Chevron también en la tarjeta guardada?** → No: guardada no abre el editor (como antes «Ver todo»), y el margen lateral se mantiene para que guardar no mueva el contenido.

**D7 · Referencias de UI** → Revisadas (`kargul`, `threads`): ninguna aplica directo a una fila de detalle con chevron; se sigue el patrón de disclosure de iOS.

### Ajustes de Jürgen en vivo (25-nov, viendo el iPhone 14)

**D8 · Chip de cuenta** → Dice «Cuenta» (texto que ya existía, `transaction.account`) en vez de «Selecciona cuenta», que se cortaba. VoiceOver sigue oyendo «Selecciona cuenta».

**D9 · Hoja de varios (Jürgen la eligió en esta sesión: «como B1»)** → La fila desplegada es la misma tarjeta (`EstoLeiCardStyle.row`), centrada y sin fondo propio, con el chevron de «Ver todo» a la derecha. Check y chevron centrados en vertical. Borde de la fila abierta en el acento (índigo), no ámbar. Despliegue animado. La fila cerrada se despliega con un toque en cualquier parte; la descripción se edita ya desplegada. Descripción en dos líneas. Fuera de `toca:` por pedido directo de Jürgen.

**D10 · Cápsula de moneda** → Centrada en vertical con el monto (antes, alineada por la línea de base, quedaba baja).

**D11 · Fondo de la hoja de varios** → Sigue la altura real de la hoja (`sheetTop`): si se queda a media altura, glass; arriba, sólido. Jürgen la vio a media altura con fondo sólido. Fuera de `toca:` (`ImageSelectionView`, `ImageEntrySheetHeight`) por pedido directo. Por qué no subió a grande no se reprodujo con la semilla: queda en «Encontrado».

**D12 · Esqueleto lento al entrar** → No se toca aquí: card en el tablero, a medir sin semilla.

**D13 · Cápsula centrada en los formularios** → Jürgen pidió Nuevo registro, aprobación de la Bandeja y Nuevo gasto de grupo. Decidido sin consultar: también el editor de favoritos, Saldar y el cierre de un borrador de grupo, para que la misma cápsula no quede distinta según la pantalla. Reversible.

**D14 · Check de lo incompleto (Jürgen, en vivo)** → Un registro pendiente sin monto, cuenta o categoría no cuenta como marcado: check vacío y apagado. «Guardar» aprueba lo completo y lo incompleto se queda en la Bandeja. Al completarlo se marca solo, salvo que la persona lo hubiera quitado (la selección guarda su intención; `MultiDraftReviewLogic.marked` filtra por `isMarkable`). La fila incompleta no se atenúa (tiene que verse para completarla). «Marcar todos» no sale si no hay nada completo. Cambia la regla anterior («todo sale marcado; Guardar apagado si hay incompletos marcados»).
