# Barrido de QA de la 2.3 tras el Flujo de caja nuevo — 19-nov-2026

Build barrida: **TestFlight 2.3 (4)**, archivada desde `origin/2.3` en `96d404d7f` (solo cambia el número de build).
El barrido corrió Yala Dev compilado desde ese mismo commit, en simuladores iOS 27.2 de la Max, con la semilla
`realista` y el período «Este mes». La «proyección inteligente» de Flujo de caja se mergeó a 2.3 durante el barrido,
después de la build 4: no está en ella y estas cifras son las de antes de ese cambio.

Resultado: **nada grave**. Las cifras de cierre de mes cuadran en las cuatro superficies y los cuatro aparatos. Tres
cards nuevas: una de texto al máximo (media) y dos de coherencia (bajas). Nada que medir contra la 2.2 publicada,
porque ningún hallazgo es grave. Informe visual: https://claude.ai/artifact/TBJrg89iossRaaskHQsBSN (privado: la
organización no permite compartir con enlace).

## Cifras: Flujo de caja, Panel, Tendencias y widget

«Al 30 de noviembre» leído en el mismo arranque de cada pantalla. El widget de Saldo se calculó desde la foto que la
app deja en el App Group (saldo de «Este mes» + lo proyectado por día hasta el 30), como lo hace el widget.

| Aparato | Sin plan: Panel · Tendencias · widget | Con plan: Flujo de caja · Panel · Tendencias · widget |
|---|---|---|
| iPhone 17 Pro, claro | 68,536.30 · 68,536.30 · 68,536.30 | 68,112.77 · 68,112.77 · 68,112.77 · 68,112.77 |
| iPhone 17 Pro, oscuro | 68,536.30 · 68,536.30 · — | 68,112.77 · 68,112.77 · 68,112.77 · 68,112.77 |
| iPhone SE, texto al máximo | 68,536.30 · 68,536.30 · — | 68,112.77 · 68,112.77 · 68,112.77 · — |
| iPad Pro 11, oscuro | 68,536.30 · — · — | 68,112.77 · 68,112.77 · 68,112.77 · — |
| iPhone Duo cerrado, oscuro | 68,536.30 · — · — | no recorrido |

El cierre del mes en Flujo de caja suma: empezaste con 64,345.15 + entró 12,529.30 − salió 5,757.00 − falta salir
2,815.53 − ajustes 189.15 = 68,112.77. Saldo de hoy 70,928.30 en todas las pantallas.

## Recorrido

| Pantalla | 17 Pro claro | 17 Pro oscuro | SE texto máx. | iPad | Duo cerrado | Resultado |
|---|---|---|---|---|---|---|
| Panel (saldo, tarjetas, salud, Tendencias con «Ver proyectado») | sí | sí | sí | sí | sí | Bien |
| Hoja de cuenta del Panel (tarjeta arriba) | sí | sí | sí | sí | sí | Bien |
| Tu salud financiera | sí | sí | sí | sí | sí | Bien |
| Estadísticas › Tendencias, sin plan y con plan | sí | sí | sí | sí | — | SE: cifra y eje cortados (card) |
| Flujo de caja: crear plan, mes, detalle de línea, cambiar límite | sí | sí | sí | sí | — | SE: detalle se sale (card); propuesta variable (card) |
| Comparativa | sí | sí | sí | — | — | Bien |
| Perfil como tarjeta y «Detalles personales» | sí | sí | sí | sí | — | Bien |
| Pagos planificados (logos) y asistente «Nuevo pago» | sí | sí | — | — | — | Bien |
| Presupuestos y asistente «Nuevo presupuesto» | sí | sí | — | — | — | Bien |
| Cuentas y asistente «Nueva cuenta» | sí | sí | — | — | — | Bien |
| Estadísticas › Registros | sí | sí | — | — | — | Bien |

**No recorrido** (decisión de Jürgen del 19-nov: no seguir tras el tope de 30 min de pruebas de interfaz): en el
iPhone SE con texto al máximo, Pagos, Presupuestos, Cuentas y Registros; en el Duo, Flujo de caja y la postura
abierta. Motivo técnico: con texto al máximo la pestaña «Pagos planificados» queda fuera de la pantalla y el conductor
de capturas no la alcanza; en el Duo cerrado la barra va en vertical y «Más» no se ve sin desplegarla. Un dedo llega a
las dos.

## Hallazgos

| Card | Prioridad | Qué | Evidencia |
|---|---|---|---|
| Texto al máximo en el SE: el detalle de una línea se sale y dos cifras se cortan (`tablero-texto-al-maximo-en-el-iphone-se-el-detal-b5ip`) | media | El detalle de una línea del Flujo de caja es más ancho que la pantalla y corta «Límite de noviembre» y el monto por la izquierda; «Ver proyectado» corta la cifra; la cabecera «Ingresos» se parte en sílabas; el eje de Tendencias se pisa | `evidencia/11`, `12`, `13` |
| Panel y Flujo de caja cuentan distinto el comienzo del mes (`tablero-panel-y-flujo-de-caja-cuentan-distinto-e-29j7`) | baja | El Panel parte del cierre del día 1 (con el sueldo dentro, «−2.8 %») y Flujo de caja de antes del sueldo («Empezaste con 64,345»): el mes baja en una pantalla y sube en la otra | `evidencia/02`, `03` |
| «Crear mi plan» propuso distinto con los mismos datos (`tablero-crear-mi-plan-propuso-distinto-con-los-m-wsj4`) | baja | Hogar › Otros salió en tres corridas y faltó en la primera, con la misma semilla y la misma fecha | `evidencia/16`, `17` |

Descartado tras mirarlo: las filas del plan con y sin decimales («S/ 238.00 de S/ 212.17» frente a «S/ 0 de S/ 395») son
a propósito (`BudgetSpentLine` recorta los decimales cuando no caben).

## Para el iPhone de Jürgen (build 4 de TestFlight)

Solo lo que el simulador no monta. Sin cambios de esquema de datos desde la build 3, así que no hay migración nueva que
probar.

1. **Tu plan de antes, al actualizar encima** (2 min). Instala la build 4 sobre la 3 sin borrar. Abre Más › Flujo de caja
   con el plan que ya tenías. Esperado: abre sin errores, y «Terminas con» del mes en curso es la misma cifra que «Al 30
   de noviembre tendrías» del Panel (Tendencias › Saldo › «Ver proyectado»). Por qué el iPhone: el motor nuevo lee un plan
   hecho con versiones anteriores, y el simulador solo crea planes nuevos.
2. **Cambiar un límite y que se guarde en iCloud** (3 min). En Flujo de caja, toca una línea › Cambiar › «Desde noviembre
   en adelante», pon otro monto y Guardar. Cierra Yala del todo y ábrela: el límite sigue. Si tienes el iPad con la misma
   cuenta, mira que llegue. Por qué el iPhone: la sincronización con iCloud no existe en el simulador.
3. **Widget de Saldo con «Mostrar proyectado»** (1 min). Añade el widget Saldo con «Mostrar proyectado» encendido. El punto
   final del mes tiene que ser la cifra de «Al 30» del Panel. Por qué el iPhone: el barrido midió la cifra del widget
   desde sus datos, no pintado en la pantalla de inicio.

## Cómo se hizo

Un conductor XCUITest temporal (no va en el PR; copia en `~/Claude/entregas/2026-11-19-barrido-qa-2-3-post-flujo/scripts/`)
recorrió cada sección relanzando la app sin borrar datos, y escribió capturas y cifras. Tiempo de pruebas de interfaz:
~26 min reales (17 Pro 10,4; SE 9,8; iPad 3,4; Duo 2,2). Capturas completas (79) en
`~/Claude/entregas/2026-11-19-barrido-qa-2-3-post-flujo/capturas/`; aquí, una selección reducida en `evidencia/`.

Pase de estrés: lo cubren el iPhone más pequeño (SE) con el texto al máximo y el modo oscuro con la semilla realista
(≈2.300 registros). Lo barato no se pudo arreglar aquí: todos los ficheros tocados están reservados por encargos
pendientes; va en la card de texto al máximo.
