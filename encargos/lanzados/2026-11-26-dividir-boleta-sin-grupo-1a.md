Yala
# Implementar dividir boleta sin grupo (maqueta 1A y ajustes)
---
toca: Yala/App/Views/DividirBoleta,Yala/App/Logic/DividirBoleta,Yala/App/Logic/ReceiptSplitLogic.swift,Yala/App/Services/ReceiptSplitService.swift,Yala/App/Views/Groups/Captura/GroupCaptureModel.swift,Yala/App/Views/Groups/GroupReceiptSplitView.swift,Yala/App/Views/Groups/GroupReceiptEntry.swift,Yala/App/Views/Groups/GroupShareableSummaryCard.swift,Yala/App/Views/Image/ImageSelectionView.swift,Yala/App/Views/Groups/GroupsContainerView.swift,Yala/Resources/de.lproj/DividirBoleta.strings,Yala/Resources/en-GB.lproj/DividirBoleta.strings,Yala/Resources/en.lproj/DividirBoleta.strings,Yala/Resources/es-419.lproj/DividirBoleta.strings,Yala/Resources/es-AR.lproj/DividirBoleta.strings,Yala/Resources/es-ES.lproj/DividirBoleta.strings,Yala/Resources/es.lproj/DividirBoleta.strings,Yala/Resources/fr.lproj/DividirBoleta.strings,Yala/Resources/it.lproj/DividirBoleta.strings,Yala/Resources/ja.lproj/DividirBoleta.strings,Yala/Resources/nl.lproj/DividirBoleta.strings,Yala/Resources/pl.lproj/DividirBoleta.strings,Yala/Resources/pt-BR.lproj/DividirBoleta.strings,Yala/Resources/pt-PT.lproj/DividirBoleta.strings,Yala/Resources/pt.lproj/DividirBoleta.strings,Yala/Resources/zh-Hans.lproj/DividirBoleta.strings,YalaTests/DividirBoletaSinGrupo,YalaUITests/DividirBoletaSinGrupo,tickets/backlog/2026-11-26-dividir-boleta-sin-grupo-1a.md,tickets/done/2026-11-26-dividir-boleta-sin-grupo-1a.md
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: si
---

Decisión de Jürgen (26-nov, 10:15 Lima): «Sobre la maqueta del recibo: 1 A ok. Pero no asumamos que siempre pague yo, puedo decidir quién pagó y la imagen debe decir quién le debe a esa persona y cuánto. Quizá permitir decidir solo resumen o con detalle, dos tipos de imagen. Pondría más de un diseño, todos con colores y logo de Yala en algún lugar. Luego dejar un «Listo» arriba a la derecha. Va en 2.3.»

## Contexto
- Propuesta elegida: `docs/propuestas/dividir-boleta-sin-grupo/` en `origin/2.3` (`NOTA.md`, `index.html`, capturas claro y oscuro; artifact https://claude.ai/artifact/CyoMRjwBhUNefJG9SdA59z). **Opción A** («Dividir una boleta») con la **imagen 1** («Me deben»). Lee `NOTA.md` y el `index.html` antes de empezar: ahí está lo medido en el código.
  - A: botón largo «Dividir una boleta» debajo de Cámara, Fotos y Archivo (`ImageSelectionView.sourceTiles`) y debajo de la fila de acciones de Grupos; foto de la boleta; nombres escritos al vuelo, sin grupo ni cuenta de Yala; repartir por igual o por líneas (una línea a una persona o dividida entre varias); propina, servicio e impuestos; en Yala completo, registrar mi parte como gasto personal o mandarla a la Bandeja; en «solo grupos», solo ver y compartir.
  - Medido: leer la boleta y calcular no dependen de un grupo (`ReceiptSplitService.readPhoto` / `readNote`, `ReceiptSplitLogic.shares`, céntimos enteros). La revisión sí pide miembros guardados (`GroupCaptureModel(members: [SplitMember])`, `SplitMember` es `@Model`): el cambio principal es aceptar personas temporales sin guardarlas. Propina, servicio e impuestos llegan sin incluir (`ReceiptExtraShare`, decisión del 5-nov). Imagen existente de referencia: `GroupShareableSummaryCard` (colores fijos, nada de `@Environment` dentro porque se rasteriza con `ImageRenderer`). Cupo del gateway: rutas `receipt.photo` / `receipt.voice`, 5 al día Free y 50 Pro.
- Card del tablero de Yala 2.3 que cubre esta sesión (búscala por título con `tablero listar --proyecto Yala`): «Dividir pago grupal escaneando un recibo». Al terminar, muévela a done con su «hecha cuando» cumplido.
- La opción C («cuenta del día» con quién ya pagó y enlace) queda para 2.4: no la construyas.

## Qué se pide
1. **Flujo A completo**, como en la maqueta: entrada desde personal y desde «solo grupos», nombres al vuelo (sin crear grupo ni guardar `SplitMember`), reparto por igual o por líneas, extras, y en Yala completo registrar mi parte o mandarla a la Bandeja. Sin cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen.
2. **Quién pagó (ajuste de Jürgen):** un selector «Quién pagó» con todas las personas de la boleta; por defecto «Yo», pero se puede elegir a cualquiera. Todo el cálculo y la imagen se arman desde quien pagó: «A <persona que pagó> le deben: X tanto, Y tanto». Si pagó otra persona, mi parte es lo que yo le debo a ella; si registro mi parte en Yala completo, va como mi gasto (y lo que debo, si aplica, se explica sin crear una deuda que no existe en un grupo; decide lo coherente y anótalo).
3. **Dos tipos de imagen (ajuste de Jürgen):** elegir «Solo resumen» (quién le debe cuánto a quien pagó) o «Con detalle» (además, línea por línea qué le tocó a cada uno, con extras).
4. **Más de un diseño (ajuste de Jürgen):** 2 o 3 estilos de tarjeta compartible para elegir en el momento, todos con los colores y el logo de Yala bien integrados (no solo un pie de texto). Colores fijos para que se vea igual en cualquier teléfono, contraste AA y sin `@Environment` dentro de lo que se rasteriza. Lista para WhatsApp, Instagram y el menú de compartir.
5. **«Listo» arriba a la derecha (ajuste de Jürgen)** para terminar el flujo limpio desde cualquier punto final (después de compartir o de registrar mi parte).
6. Textos nuevos solo en la tabla propia `DividirBoleta.strings` de los 16 `.lproj` (nunca en `Localizable.strings`), en español neutro latinoamericano en `es` y `es-419`. Nunca un botón debajo del otro si la maqueta no lo muestra así.
7. Pruebas unitarias en `YalaTests/DividirBoletaSinGrupo/`: reparto por igual y por líneas con céntimos, extras, quién pagó distinto de mí, contenido de las dos imágenes, y que no se guarda ningún `SplitMember`. Si agregas pruebas de interfaz, van en `YalaUITests/DividirBoletaSinGrupo/`.
- Código nuevo en carpetas propias (`Yala/App/Views/DividirBoleta/`, `Yala/App/Logic/DividirBoleta/`); cambios mínimos en los archivos compartidos de Grupos y de la captura, sin romper el reparto de recibo dentro de un grupo, que ya existe.

## Qué NO hay que tocar
- El reparto de recibo dentro de un grupo debe seguir igual (sus pruebas, en verde). Nada de esquemas, gateway ni cupos. No la opción C.
- Nada fuera de `toca:`; si necesitas tocar otro archivo, anótalo en «Saltado o asumido sin preguntar» con el motivo.

## Cómo se sabe que está bien
- En Yala completo y en «solo grupos», desde la foto de una boleta de 7 líneas con 4 personas escritas al vuelo: reparto por igual y por líneas correctos al céntimo, «Quién pagó» elegible, imagen «Solo resumen» y «Con detalle» en cada estilo, compartir funciona, «Listo» cierra; en Yala completo, mi parte queda como gasto o en la Bandeja.
- Ningún grupo ni miembro nuevo guardado.
- Capturas antes/después en `capturas/` del worktree (claro y oscuro, iPhone 14) y un artifact visual de Claude con el recorrido y las imágenes generadas, enlazado en el cierre.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Antes de diseñar, mira `~/Claude/referencias-ui/README.md`.
- Verificación: puedes usar el iPhone 14 por DeviceMCP (si Jürgen lo está usando, no lo toques) o, en la Max, un segundo simulador además del de otra sesión. En la Mini, un solo simulador. Apaga y limpia los simuladores que enciendas.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Cierre
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», las capturas y el link del artifact. `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones (resueltas en semiautónomo por Frank, 26-nov)

1. **Una lectura por boleta, al tocar «Repartir»**, con la frase de quién comió qué en la misma llamada (`receipt.photo`, un recibo del cupo). Leerla al elegirla obligaba a releer para la frase (dos recibos). Tras leer, la tira dice «Esto leí ✓» y volver no relee.
2. **Personas al vuelo sin `SplitMember`**: modelo propio (`DividirBoletaModel`) con personas de valor; reusa `ReceiptSplitService`, `ReceiptSplitDraftLogic`/`ReceiptPeopleMatcher`, `ReceiptSplitLogic` y `GroupCaptureModel.failure(for:)`. `GroupCaptureModel` y la revisión de Grupos no cambian. Sin esquema.
3. **«Por igual»** ignora asignados y esconde la frase; **«Por líneas»** es el reparto de Grupos. Extras llegan sin incluir.
4. **Quién pagó** en la pantalla final, por defecto «Yo». Si pagó otra persona: «Le debes a X», y mi parte se registra como mi gasto con la explicación de no registrarla otra vez al pagar. No se crea deuda.
5. **Registrar mi parte** (Yala completo): borrador de la Bandeja con mi parte y su editor empujado en la misma hoja (molde «Ver todo» de la foto personal); «o mándala a la Bandeja» lo deja ahí. Un borrador por boleta. En «solo grupos», solo ver y compartir.
6. **Imagen**: «Solo resumen» y «Con detalle»; tres diseños («Clara», «Yala», «Boleta») con colores fijos de marca y logo; contraste AA en test; sin `@Environment` en lo rasterizado; 4:5; menú de compartir del sistema.
7. **«Listo»** arriba a la derecha en la pantalla final; X a la izquierda antes.
8. **Si la IA no puede**, «Apuntarlo a mano» pide el total y lo reparte.
9. **Entradas**: botón largo bajo Cámara/Fotos/Archivo (fuera de la práctica guiada) y bajo la fila de acciones de Grupos. Desde la foto personal, «Listo» cierra también la hoja de foto.
10. Fuera: «Recientes» (clave nueva en disco + «Vaciar datos», fuera del `toca:`), «Guardar como grupo» (4b) y la opción C.
