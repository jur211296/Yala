# Después del lote 2: sin animaciones infinitas fuera de la vista

Medido el 2026-11-26 entre las 11:40 y las 11:48 (Lima) en el iPhone 14 de Jürgen, por cable a la Max. Misma copia de
perfilado que el informe (Release-Dev optimizada con `DEBUG` encendido solo en la copia), con el cambio de este lote
encima, y el mismo almacén de pruebas (`YalaModel-UITest`, 16.004 movimientos), abierto con `-uitest
-uitest-skip-onboarding`. Mismos guiones: `scripts/pasadaE.sh` y `scripts/pasadaJ.sh`, con `reposo.py` y `energia.py`.

**El «antes» son las pasadas E y J1 del informe.** Se midieron esa mañana sobre `b5c6e98c5`, y entre ese commit y la base
de este lote (`3eb19a261`) no cambió ningún fichero de `Yala/App`: es el mismo código sin el cambio.

## Reposo: hilo principal con la app quieta (pasada E, 30 s por pantalla, se descartan 3 s)

| Pantalla delante | Antes (E) | Después |
|---|---|---|
| Panel arriba | 38,1 % | **0,4 %** |
| Panel con la tendencia a la vista | 35,6 % | **0,0 %** |
| Registros | 34,9 % | **0,0 %** |
| Más | 35,4 % | **0,0 %** |
| Panel, de vuelta | 35,3 % | **0,0 %** |

Control: la traza capta a Yala. En los primeros 37 s (arranque y cálculo con 16 k movimientos) hay ~9.000 muestras del
hilo principal por cada 10 s; luego solo picos en cada toque de navegación (`E_control_muestras_por_tramo.txt`).

## Energía (Power Profiler, pasada J: 45 s quieta en el Panel y 3 idas y vueltas)

| Ventana | Antes (J1) | Con los dos interruptores del informe (J2) | Después |
|---|---|---|---|
| Reposo en el Panel, CPU | 1,87 | 0,04 | **0,03** |
| 10 s tras volver, CPU | 25,15 | 5,90 | 28,14 |
| Fuera (otra app delante), CPU | 3,73 | 0,30 | 2,27 |

La vuelta no es de este lote: la domina la recarga al volver (lote 1). J2 llevaba además el interruptor que la apagaba.

**Mejora esperada (informe): reposo de 35-38 % a ~0,3 %, pasada E < 2 %.** Cumplida.
