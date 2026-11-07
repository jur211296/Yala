# Revisión por vistas 2.3 · Nuevo registro: gasto, ingreso, transferencia, favoritos, voz y foto

**Qué es.** Revisión de UX de la zona 32 del mapa de cobertura, sobre `origin/2.3` del 7-nov-2026. No cambia la app y
no elige: deja siete problemas priorizados, cuatro alternativas maquetadas para cada uno y una recomendación. Decide
Jürgen.

**Cómo abrirla.** `index.html` en el navegador (las páginas enlazan entre sí y las capturas van en `capturas/`). Desde el
móvil, `revision-nuevo-registro.pdf`, con lo mismo.

**El caso.** Ana apunta un café de S/ 4.50 pagado con su Cuenta Principal (soles) en el menor número de toques; después
un ingreso, una transferencia de S/ 380 a sus Ahorros USD, repite su favorito «Café», y apunta un almuerzo por voz y otro
desde la foto del recibo; con el teclado abierto y con texto grande. Datos ficticios en las maquetas; semillas de prueba
en las capturas.

## Vistas cubiertas

| Vista | Capturas |
|---|---|
| `NewTransactionView` | abre sin teclado, con teclado, completo, una cuenta, sin favoritos, ingreso, descartar, fecha, guardar como favorito, AX3, iPad |
| `TransactionTypeSelectorView` | gasto, ingreso, transferencia, AX3 |
| `TransactionAmountInputView` | **no se usa** en ninguna parte (código muerto): sin captura |
| `TransferAmountInputView` | soles → dólares, con teclado, tasa, AX3, iPad |
| `TransactionSuccessView` | «¡Listo!», «Registrar otro», aviso tras el cuarto registro, iPad |
| `FavoritesListView` + `FavoriteRowView` + `FavoriteEditorView` | vacía, con datos, deslizar, «Ver todos», nuevo favorito, AX3, iPad |
| `VoiceRecordingView` | escuchando, entendido, sin categoría, dos registros, prueba agotada, Free, consentimiento, micrófono denegado, AX3, iPad |
| `ImageSelectionView` (recibo) | elegir, leyendo, leído, siete registros, sin importe, una foto falló, límite del día, Free, AX3, iPad |

Sin conexión: el formulario no cambia (la tasa se queda como estaba, sin aviso); la pantalla «Sin conexión» de voz y
foto va reconstruida del código para no cortar la red de la máquina. Cámara: no existe en el simulador.

## Problemas y recomendación

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Con el teclado abierto, lo que falta y «Guardar» quedan debajo: el café cuesta 6 toques + 4 teclas | Alta | **G1** · barra sobre el teclado con lo que falta y «Guardar» |
| 2 | Para un café hay que adivinar la categoría: sin recientes al empezar y «café» no encuentra nada | Alta | **C2** · las 3 categorías más usadas a la vista (+ C3, palabras en el buscador) |
| 3 | Con texto grande, la zona fija de «Guardar» se monta sobre el formulario; 2.2 ya lo arregló y 2.3 no lo tiene | Alta | **Z2** · el botón dice lo que falta, sobre **Z1** · traer el arreglo de 2.2 |
| 4 | El importe escrito en soles pasa a dólares al elegir la cuenta, sin aviso | Media-alta | **M1** · decirlo con palabras (+ M4, la cuenta en soles primero) |
| 5 | Cuando voz o foto fallan, «a mano» empieza de cero; el muro de Pro promete «a mano» sin botón | Media-alta | **V1** · «Apuntarlo a mano» trae lo entendido (+ V3, el botón del muro) |
| 6 | Transferencia entre monedas: dos importes sin nombre y las cuentas lejos | Media-alta | **T1** · cada importe con su cuenta (+ T2, «¿cuánto llegó?») |
| 7 | Repetir un favorito no es «un toque»: rellena 12.00 y hay que borrarlo; solo vive en el formulario | Media | **F1** · el importe del favorito viene seleccionado (+ F2, favoritos en el Panel) |

Si hay que empezar por lo barato: **Z1** (traer a 2.3 el arreglo de 2.2), **V3**, **F4**, **M1** y **C3** son cambios
pequeños que no cierran la puerta a lo demás.

**Ojo:** `origin/2.3` no tiene seis arreglos de 2.2 que tocan esta zona (zona fija y cifras con texto máximo, formulario
a medias que sobrevive al cierre, chip de cuenta y hoja de varios registros con texto máximo, tarjeta de doble línea).
La revisión es de 2.3 tal como está; ver «Perfiles y eficiencia».

## Decisiones para Jürgen

1. ¿Barra sobre el teclado (G1)? ¿El formulario abre con el teclado en el importe por defecto (hoy «No abrir»)?
2. ¿Fila de categorías frecuentes (C2)? ¿Cuáles son las 3 de arranque para quien empieza?
3. ¿El botón dice lo que falta (Z2, reabre L2-2)? ¿Cuándo se integra 2.2 en 2.3 (trae el arreglo de la zona fija, Z1)?
4. ¿Aviso al cambiar de moneda (M1) y la hoja de cuentas con la moneda principal primero (M4)?
5. ¿«Apuntarlo a mano» precarga lo entendido (V1)? ¿Y el muro de Pro suma ese botón (V3)?
6. ¿Importes con su cuenta en la transferencia (T1) y «¿cuánto llegó?» (T2)?
7. ¿Importe seleccionado al aplicar un favorito (F1)? ¿Fila de favoritos en el Panel (F2)?

## Qué es medido y qué no

- **Medido:** capturas del simulador (iPhone 17 Pro, iOS 27.2, Yala Dev de `origin/2.3`; iPad Air 11), los gestos del
  café (6 toques + 4 teclas con la cuenta puesta), lo que tapa el teclado (297 de 874 pt), dónde queda «Ver todos»
  (x = 792 pt en 402) y que «café» da cero categorías.
- **Leído en el código:** cada cita con fichero y línea.
- **Hipótesis:** los siete perfiles (simulados, no entrevistas), la causa del solape de «Guardar» y las notas de
  rendimiento sin medir (recarga del formulario al cerrar cada hoja, foto en el hilo principal, onda de voz sin tope).
- Lo decidido en la auditoría 2.2 para el formulario (lote 2, L2-1 a L2-22) está implementado y no se repropone; las
  alternativas que lo reabren lo dicen (M2 → L2-16, Z2 → L2-2, Z4 → L2-20).

## Archivos

`index.html` · `01-estado-actual.html` · `02-revision.html` · `11-teclado-y-guardar.html` … `17-repetir-favorito.html` ·
`estilo.css` · `capturas/` · `revision-nuevo-registro.pdf` · `fuente/` (generador: `python3 build.py`; `--todo X.html`
para el PDF).
