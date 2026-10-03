# Evidencia · cola-b-redesigns-must-hold-up-at-ipad-width (2026-10-03)

Los dos rediseños de Cola B que ya están en `2.1` —Ajustes como lista agrupada y Yala IA como mensajería— medidos en
el ancho del iPad y en los iPhone del carril. Ajustes tenía un fallo: junto a la columna de la lista, el ajuste
abierto arrancaba **pegado** a ella. Está arreglado. Yala IA ya cumplía.

## Cómo se sacaron

- Simuladores del carril, por UDID y de uno en uno (iOS 27.0): `YalaLane-Adapt-iPad-Pro-13` (`DE089C7E…`),
  `YalaLane-Adapt-iPad-mini` (`A7086B76…`), `YalaLane-Adapt-iPhone-SE` (`0D705C9A…`) y
  `YalaLane-Adapt-iPhone-ProMax` (`72EB411B…`). Vertical y girados; los iPhone con texto por defecto y con AX5.
- Un XCUITest temporal (borrado antes del commit) abre Perfil → Personalización → Personalizar resumen de IA, Divisa y
  Cambio, Privacidad y datos IA, Tutoriales y Vaciar datos, y luego Yala IA desde Registros. Semilla `minimal`, Pro.
  Barra de estado a las 9:41.
- Los bordes del bloque se midieron en los píxeles de la captura, en la fila «Solo gastos»: los marcos de celda que da
  XCUITest no sirven, porque antes del arreglo las celdas ocupaban todo el ancho y el sistema recortaba el bloque.
- «Antes» es `2.1` en `b474ce098`; «después», el árbol del PR.
- `comparativa-*.jpg`: antes a la izquierda, después a la derecha. `despues/`: todas las pantallas, versión final.
  Una pantalla que falta en `despues/` es una fila que el test no alcanzó a esa orientación, no un fallo de la app.

## Ajustes: el margen junto a la columna de la lista

Bloque de Personalización, en puntos. «Aire» es lo que queda entre el borde de la columna de la lista y el bloque.

| Aparato | Antes: bloque · aire | Después: bloque · aire |
|---|---|---|
| iPad Pro 13 vertical | 400–1000 (600) · **0** | 432–1000 (568) · 32 |
| iPad Pro 13 girado | 504–1238 (**734**, pasa de 700) · **0** | 538–1238 (700) · 34 |
| iPad mini girado | 400–1101 (701) · **0** | 432–1101 (669) · 32 |
| iPhone Pro Max girado | 446–894 (448) · **0** | 478–862 (384) · 32 |
| iPad mini vertical | 32–712 (680): la lista flota, no hay columna al lado | igual |

La causa, medida con una sonda: junto a la columna la lista tiene 400 pt de área segura a la izquierda (iPad mini
girado) y pedía 32 de margen; el sistema se quedaba con el mayor de los dos, no con la suma. Ahora cada lado recibe
área segura + margen legible.

## iPhone en vertical: sin cambios, salvo tres cabeceras

Las pantallas de ajustes del SE y del Pro Max en vertical salen **idénticas al píxel** (las diferencias que quedan son
la hora del chat, el destello del avatar y la línea «Última actualización»), con una excepción buscada: las tres
cabeceras sin márgenes propios (Personalización, Tutoriales, Divisa) llevan ahora 8 pt de aire a cada lado.

- **SE, Tutoriales**: el subtítulo **ya salía cortado en `2.1`** («‸prende a sacarle… a Yal‸»). Ahora pasa a dos
  líneas (`comparativa-se__06-tutoriales-v-cabecera.jpg`).
- **SE, Divisa**: «tipos» baja a la segunda línea.
- **Pro Max con AX5, Personalización**: el título, que iba de borde a borde, se parte con guion
  (`comparativa-promax-ax5__02-personalizacion-v-cabecera.jpg`).

Era el mismo fallo que apareció en el Pro Max girado con la celda más estrecha (384 pt): un texto que casi cabe en una
línea sale con los bordes de los glifos cortados.

## Yala IA: ya cumplía

En el iPad va en su columna a la derecha (~375 pt) y el hilo y la caja no pasan de 700; en iPhone, la hoja de siempre.
Ni tirador ni cierre dentro del hilo. Capturas `despues/*__08-chat-*`. Sin cambios de código.

## Red automática

- `AdaptiveNavigationUITests#test_settingsDetail_keepsItsMarginBesideTheListColumn_inWideWindow`: en el iPad Pro 13,
  del borde de la lista al texto de la primera fila de Personalización hay ≥ 56 pt. Verde con el arreglo (~70);
  **rojo con el mutante** que devuelve el margen de antes (36 pt). En el iPad mini en vertical se salta: la lista se
  aparta al abrir el ajuste y no hay columna al lado.
- `SettingsListLayoutTests`: tres casos nuevos del cálculo (`DS.Adaptive.readableListInsets`).

## Lo que se ve y no es de aquí

- **Registros con Yala IA abierto en el iPad**: «Elige un registro para verlo aquí» sale medio tapado por la lista
  (`despues/ipad-pro-13__08-chat-h.jpg`). Ticket `ipad-records-empty-detail-half-hidden-with-chat-open`.
- **Ajustes desde el Panel en el iPad Pro 13** sale con lista y ajuste lado a lado, no en la hoja de 810 pt con la
  lista flotando que describe `ipad-settings-sheet-size-depends-on-where-it-opens`. Anotado en ese ticket.
