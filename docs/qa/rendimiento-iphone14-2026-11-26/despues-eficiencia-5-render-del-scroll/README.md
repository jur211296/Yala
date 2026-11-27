# Después del lote 5: scroll más liviano (cristal, sombras y recortes)

Medido el 2026-11-26 entre las 19:59 y las 21:20 (Lima) en el iPhone 14 de Jürgen, por cable a la Max. Mismo método que el
informe: copia de perfilado (Release-Dev optimizada con `DEBUG` encendido solo en la copia, `scripts/perfil.sh`), almacén
de pruebas `YalaModel-UITest` con 16.004 movimientos, abierto con `-uitest -uitest-skip-onboarding`, tema por defecto
(Liquid Glass). Pasada D del informe: 3 rondas de «irse 10 s, volver y scroll rápido» por ocho pantallas, con Hitches
(`scripts/pasadaD.sh`, que usa el conductor del informe, `../scripts/pantallas.sh`).

**El «antes» se midió hoy**, sobre `origin/2.3` en `7f719e47c` (con los lotes 1, 2 y 3 ya dentro). La traza D del informe
no sirve de comparación: con el hilo principal al 100 % el Panel casi no pintaba y su mediana salía de 1 pasada.

`scripts/pasadas.py` saca de cada traza la tabla `hitches-renders` (columna *Offscreen Passes*, un valor por fotograma del
servidor de render) y la tabla `hitches` (tirones de Yala, con su causa), y las corta por las ventanas de scroll del csv.

## Pasadas fuera de pantalla por fotograma durante el scroll (pasada D, 3 rondas)

| Pantalla | Antes: mediana | Antes: máx. | Después: mediana | Después: máx. |
|---|---|---|---|---|
| Panel | 33 | 97 | **23** | 63 |
| Registros | 68 | 115 | **19** | 58 |
| Estadísticas › Resumen | 20 | 88 | 19 | 22 |
| Estadísticas › Tendencias | 58 | 97 | **34** | 66 |
| Estadísticas › Distribución | 55 | 115 | **34** | 61 |
| Pagos planificados | 34 | 51 | 34 | 50 |
| Bandeja | 24 | 81 | 24 | 56 |
| **Todas** | **37** | **115** | **24** | **66** |

Grupos (sin grupos) no pinta fotogramas durante el gesto y sale en 1 en las dos.

**Objetivo del encargo: mediana < 20.** Cumplido en Registros (19) y Resumen (19); no en el conjunto (24). Ver «Lo que queda».

## Tirones por segundo de scroll

| | Antes | Después |
|---|---|---|
| Todos | 1,48 | 1,26 |
| Solo «render caro» (lo de este lote) | 0,22 | 0,31 |

**Objetivo: < 0,5.** Los tirones de render ya estaban por debajo antes y siguen por debajo (son 1-2 por pantalla en tres
rondas: la diferencia 0,22 → 0,31 es ruido de recuento). El total no baja de 0,5 porque **casi todos son «actualización de
la app»**: trabajo del hilo principal, no del render. Ese es el terreno de los lotes 1, 3 y 4 (recalcular al volver y el
cálculo del Panel), no de este. El 2,8 del informe venía de la pasada B2, con los congelamientos de 12-20 s que esos lotes
quitan.

## Qué pieza pesa: atribución con interruptores (`datos/atribucion_por_pieza.txt`)

Copia experimental con todos los cambios candidatos y un interruptor temporal por pieza (`-perfTempRenderViejo <pieza>`)
que la devolvía a como estaba. Ruta Panel + Registros, 3 rondas. Mediana de pasadas:

| Variante | Panel | Registros |
|---|---|---|
| Todo nuevo | 29 | 18 |
| Todo como antes | 44 | 68 |
| Botones flotantes sin contenedor de cristal | **37** | **32** |
| Píldoras de acción rápida con la sombra de vista | **36** (máx. 55 → 87) | 18 |
| Fila de Registros con recorte y sombra de vista | 32 | 19 |
| Tarjetas sólidas del Panel con recorte | 28 | 18 |
| Cabeceras de sección sin contenedor de cristal | 30 | 18 |
| Chips de cuentas sin contenedor de cristal | 30 | — |
| Burbujas de las tartas con sombra de vista | 30 | — |
| Barra de filtros de Registros sin contenedor | 30 | 18 |

**Los efectos no se suman.** Con solo los botones flotantes y las píldoras nuevos, Registros volvía a 52 aunque se quitara
el botón flotante entero (sonda `sinfab`); con la fila nueva además, 18. Lectura (inferida, no aislada): cada pieza de
cristal que se pinta encima del contenido le pide al sistema una copia de lo que tiene debajo, y si debajo hay sombras de
vista, cada copia las vuelve a calcular. Basta con quitar uno de los dos factores para que el producto caiga. Por eso el
conjunto final es fila + píldoras + botones flotantes, y da lo mismo que el conjunto completo (`p3-min`: Panel 31,
Registros 18, total 23).

Se revirtieron, por no mover nada medible: tarjetas sólidas sin recorte, contenedores de cristal en las cabeceras de
sección, en los chips de cuentas y en la barra de filtros de Registros, y la sombra de las burbujas de las tartas.

## Qué cambió

1. **Fila de lista** (`ListRowCardModifier`, Registros y el feed de Grupos): el fondo y la sombra se dibujan con la forma
   (`RoundedRectangle.fill(theme.card.shadow(.drop(…)))`), sin recortar el contenido ni poner la sombra a la vista. Mismos
   valores de sombra (`DS.ListRow`). En el tema claro, el contorno de `.thCard` ya se lo comía el recorte: va el color liso.
2. **Píldoras de acción rápida del Panel y de Registros** (`PanelQuickActionsRow`): la sombra pequeña del DS pasa del botón al
   relleno de la cápsula.
3. **Botones flotantes** (`FABStackView`, en el Panel, Registros y Estadísticas): los dos círculos de cristal van en un
   `GlassEffectContainer(spacing: DS.Spacing.xs)`. El espaciado queda por debajo del hueco entre botones (`md`), así que no
   se funden.

## Lo que se ve: igual

Capturas en el iPhone 14 del Panel arriba y de Registros arriba y bajado, en Liquid Glass, claro y oscuro, comparadas al
píxel con `magick compare -fuzz 2%`: 0,0002 % a 0,006 % de píxeles distintos (ruido de antialiasing) en todas las parejas
que pararon en el mismo sitio. Las que no: el saldo del Panel oscuro (la cifra iba a mitad de cálculo) y Registros bajado
en oscuro (el scroll paró en otra fila); comparadas a ojo, mismas filas y mismos botones. Capturas en
`~/Claude/entregas/2026-11-26-eficiencia-5-render-del-scroll/evidencia/`; guion en `scripts/capturas.sh`.

## Lo que queda

- **El suelo de ~20-35 pasadas en Panel, Tendencias, Distribución y Pagos** no sale de las piezas medidas aquí. Candidatos
  sin medir: la barra de pestañas y la barra de arriba (cristal del sistema), el cristal de los botones de las barras y las
  gráficas de Tendencias y Distribución. Cada sonda cuesta una compilación de perfilado (~6 min) y una pasada (~4 min).
- **Los tirones totales (1,26/s)** son de hilo principal: siguen en el lote 4 (recálculo del Panel) y en el coste de las filas
  de Registros al entrar en pantalla.

## Archivos

- `datos/D_antes_por_pantalla.txt`, `datos/D_despues_por_pantalla.txt`: por ronda y por pantalla. `datos/*.ciclos.csv`: las
  marcas del conductor.
- `datos/atribucion_por_pieza.txt`: las doce variantes de la atribución.
- `scripts/perfil.sh` (copia de perfilado), `scripts/pasadaD.sh` (pasada D con argumentos extra), `scripts/pasadas.py`
  (extractor), `scripts/capturas.sh` (capturas), `scripts/rutas-panel-registros.txt` (ruta corta de la atribución).
- Las trazas del antes y el después (`.trace`) no van al repo: quedan en
  `~/Claude/entregas/2026-11-26-eficiencia-5-render-del-scroll/trazas/` de la Max.
