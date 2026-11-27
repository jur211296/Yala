# Lote 6 · Memoria por vuelta, y pasada final del plan de eficiencia — iPhone 14

Medido el 26 y 27-nov-2026 entre las 23:14 y las 00:00 (Lima) en el iPhone 14 de Jürgen («iPhone de JURGEN», iOS
27.2.1), por cable a la Max, desbloqueado y cargando. La misma copia de perfilado que el informe y los lotes 1-5
(`Release-Dev` optimizada con `DEBUG` encendido solo en la copia, `scripts/perfil.sh`) y el mismo almacén
`YalaModel-UITest` de 16.004 movimientos, abierto con `-uitest -uitest-skip-onboarding`.

**La build medida es el final del plan**: `origin/2.3` en `0011b0658` (lotes 1 a 4) fusionada en local con la rama del lote
5 (`cbc41f905`, en cola de auto-merge a esa hora). El lote 5 entró en `2.3` a las 23:48 (`09910cfa0`) y su árbol es el
mismo, byte a byte, que el medido (`bad37a747`). Este lote no cambia código de la app, así que es también la build que
queda.

**El «antes» son las cifras del informe de origen** (`../README.md`), medidas la mañana del 26-nov sobre `b5c6e98c5`.

## 1. La memoria ya no sube por vuelta

Activity Monitor (huella física de Yala), 10 ciclos «irse a otra app 5-30 s y volver» con scroll, Yala abierta normal
(sin Instruments enganchado al arrancar), como la pasada F del informe.

| Ciclo | Antes (F, informe) | Después | Después, forzando la recarga completa en cada vuelta |
|---|---|---|---|
| 1 | 238 MiB | 108 MiB | 100 MiB |
| 2 | 241 | 108 | 105 |
| 3 | 266 | 108 | 105 |
| 4 | 319 | 108 | 105 |
| 5 | 340 | 109 | 107 |
| 6 | — (iOS cerró la app, 363 antes del cierre) | 109 | 107 |
| 7 | — | 109 | 107 |
| 8 | — | 109 | 104 |
| 9 | — | 109 | 106 |
| 10 | — | 110 | 109 |

Mejora esperada del encargo: estable (± 10 MiB) tras el ciclo 2. **Cumplida**: +2 MiB del ciclo 2 al 10, y +4 MiB
forzando la recarga.

**¿Las recargas completas dejan vivas las filas de SwiftData?** No. Para comprobarlo hizo falta provocarlas, porque desde
el lote 1 volver ya no recarga si nada cambió: una copia de medición con un interruptor temporal
(`-perfTempRecargaAlVolver YES`, `scripts/forzar_recarga_al_volver.py`, solo en la copia, no en el PR) recarga el Panel
entero y reconcilia Spotlight en cada vuelta. La consola confirma un `PERF panel-calculo completo` de ~6 s en cada vuelta,
y la memoria sigue plana (columna de la derecha).

**Por qué subía antes** (inferido, sin aislar en la build vieja): cada vuelta lanzaba el recálculo entero del Panel y la
lectura de Spotlight en el hilo principal, de una vez y sin ceder (16-25 s seguidos), y el siguiente ciclo empezaba con
el anterior todavía en vuelo. Con el hilo bloqueado, lo que esa vuelta creaba no se soltaba hasta que el bucle principal
volviera a girar. Los lotes 1 (no recalcular al volver), 3 (Spotlight por tramos en contextos que mueren con el tramo, y
cortar al irse) y 4 (cálculo por tramos que ceden el hilo) quitaron las tres cosas. El ciclo 1 también bajó: 238 → 108 MiB.

**Allocations**: no se corrió. Con la huella plana en 10 ciclos, en uso normal y forzando la recarga, no había nada que
aislar; el encargo lo pedía para encontrar qué crecía.

**Test que lo fija**: `YalaTests/EficienciaMemoriaPorVuelta/MemoriaPorCicloTests.swift`. Ocho recargas completas del Panel y
ocho lecturas de Spotlight sobre un almacén en disco de 4.000 movimientos, con la huella física del proceso tras cada
ciclo: no puede crecer más de 4 MiB del ciclo 2 al último. Medido en el simulador (iPhone 17 Pro, iOS 27.2):

| Caso | Huella del ciclo 2 al 8 | Resultado |
|---|---|---|
| Panel, código de hoy | 70,5 → 70,3 MiB (−0,2) | verde |
| Spotlight, código de hoy | 70,9 → 70,5 MiB (−0,4) | verde |
| Control: un contexto nuevo por ciclo que nadie suelta, con sus filas | 72,0 → 97,6 MiB (+25,6) | verde (tiene que crecer) |
| Mutante en el Panel: cada recarga lee en un contexto nuevo que queda retenido | 71,2 → 79,3 MiB (+8,1) | **rojo** |
| Mutante en Spotlight: cada tramo deja vivo su contexto con sus filas | 70,7 → 104,3 MiB (+33,6) | **rojo** |

Los mutantes se pusieron a mano en `PanelViewModel.fetchTransactionsInSlices` y `SpotlightIndexService.readSlice`, se
corrieron y se quitaron; no están en el PR.

## 2. Pasada final: todo el plan, antes y después

| Qué | Antes (informe) | Después (final del plan) | Lote que lo movió |
|---|---|---|---|
| **Volver**: bloque con el hilo principal ≥ 90 % | 16-25 s por vuelta (B2) | **0 s** en las 10 vueltas | 1, 4 |
| **Volver**: CPU del hilo principal tras volver | ~33 s en 36 s (B2) | **1,2-2,9 s en 36 s**; mediana **1,5 s en 20 s** (ciclos 2-10) | 1, 2, 4 |
| **Volver**: cuelgues con Yala delante | 1 por vuelta, 7-20 s | **0** | 1, 4 |
| **Volver**: tirones > 250 ms | congelamientos de 12-20 s en 6 de 10 | **0** | 1, 4 |
| **Reposo** (hilo principal, app quieta) | 35-38 % de un núcleo (E) | **0,0-0,3 %** | 2 |
| **Scroll**: pasadas fuera de pantalla por fotograma (mediana / máx.) | Panel 33 / 97 · Registros 68 / 115 (base del lote 5) | Panel **31 / 64** · Registros **18 / 41** | 5 |
| **Scroll**: tirones por segundo | 2,8 (B2) | Panel 1,64 · Registros 2,02 (de render: 0,36 · 0,37) | 1, 4, 5 |
| **Calor** (estado térmico de iOS) | **Serious** de principio a fin (B2, C, D, F, G) | **Fair** de principio a fin (vuelta y scroll) | 1, 2, 4 |
| **Cierres** en segundo plano | 2 `0x8BADF00D` en una mañana; lote 3: 4 de 5 al salir a los 3 s | **0** en 10 salidas a los 2-5 s; ningún `.ips` ni `cpu_resource` en la sesión | 3 |
| **Energía**: reposo en el Panel (impacto CPU) | 1,87 (J1) | **0,02** | 2 |
| **Energía**: 10 s tras volver | 25,15 | **1,71** | 1, 4 |
| **Energía**: con otra app delante | 3,73 | **0,34** | 3 |
| **Memoria** al volver | 238 → 363 MiB en 5 ciclos | **108 → 110 MiB en 10 ciclos** | 1, 3, 4 |

Las cifras de «después» son de pasadas con los mismos guiones del informe: `vuelta` (B2), `reposo` (E), `energia` (J1) y
`memoria` (F) en `scripts/pasada_final.sh`; el scroll (D) con el conductor del informe (`../scripts/pantallas.sh`) y el
análisis del lote 5 (`scripts/pasadas_lote5.py`); los cierres con el guion del lote 3 (`scripts/cierres.sh`).

### Lo que no llegó a su objetivo

- **Tirones de scroll < 0,5 por segundo** (lote 5): no. Quedan 1,6-2,0 por segundo en Panel y Registros. Los de render
  son 0,36-0,37; el resto son «actualización de la app», trabajo del hilo principal durante el gesto. Ya no son
  congelamientos (ninguno pasa de 250 ms), pero siguen ahí.
- **Mediana de pasadas fuera de pantalla < 20**: Registros sí (18); el Panel no (31).
- **Pasos de < 50 ms en el recálculo del Panel** (lote 4): quedan tramos de ~0,85-0,92 s (la proyección del saldo). En
  esta pasada no se ven como cuelgues porque volver ya no recalcula; con datos nuevos, sí.

### Qué cubrió la pasada D y qué no

Panel, Registros y Compartido (esta última, sin grupos en el almacén: 1 pasada por fotograma, como Grupos en el lote 5).
Estadísticas, Pagos planificados y Bandeja se midieron en el lote 5 y no se repitieron: sus rutas dependen de tocar
tarjetas en Más.

### Control de las trazas

- Vuelta: en los primeros 30 s (arranque en frío y dos cálculos del Panel con 16 k) la traza capta 8.800-9.900 ms de hilo
  principal por cada 10 s; luego solo los tramos de cada vuelta. La traza ve a Yala.
- Reposo: cada toque de navegación deja 550-1.735 ms de hilo en los 4 s antes de su ventana: las pantallas cambiaron.
- Calor: el teléfono venía de una hora de mediciones y empezó cada pasada en Fair. El informe pasó de Fair a Serious en
  la primera pasada con 16 k.

## Archivos

- `datos/F_memoria_antes1.*`: memoria por ciclo, uso normal. `datos/F_memoria_forzada1.*`: con la recarga forzada.
- `datos/V_final_por_vuelta.txt`: por vuelta, CPU, bloque, cuelgues, tirones y estado térmico.
- `datos/E_final_reposo.txt`, `datos/D_final_por_pantalla.txt`, `datos/J_final_energia.txt`, `datos/C_final_cierres.txt`.
- `datos/*.ciclos.csv`: los eventos de cada pasada (hora de Lima y epoch).
- `scripts/`: los guiones. `trazas.py` sustituye a `xtparse.py` y `perfil_lector.py`, que el informe cita y no llegaron al
  repo (`xtparse.py` queda como alias para los guiones del informe y del lote 5). Las trazas (`.trace`) no van al repo.
