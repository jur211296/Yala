---
name: el-mutante-de-un-scan-vive-en-el-disco
description: Un source-scan lee el fichero al CORRER, no al compilar; una tanda que compila el mutante y restaura antes de correr da por vivos a todos los mutantes de cableado.
metadata:
  type: feedback
---

**Los mutantes que solo caza un source-scan se aplican en disco DURANTE la corrida**, no solo en el build.

**Why:** el 2026-10-05 (#363) partí la tanda en dos fases para no solapar compilador y simulador: compilar cada
mutante en su DerivedData clonado y restaurar las fuentes, y después arrancar el simulador y correr los binarios.
Los 8 mutantes de comportamiento murieron; los 3 de cableado (R0, M7, M9) salieron **vivos**. No era el test: los
scans leen `#filePath` del disco al ejecutarse, y el disco ya estaba restaurado. Puestos en disco al correr, con el
binario limpio, murieron los 7 (los 3 y 4 nuevos). Si me hubiera creído la primera lectura, habría «arreglado» tests
que funcionaban.

**How to apply:** en una tanda con scans, separa los mutantes en dos clases. Los de comportamiento: build aparte +
correr. Los de cableado: sin build, aplicar en disco → correr la suite del scan → restaurar desde la copia y `cmp`.
Y un mutante de cableado que sale vivo con la fase de build se re-mide así antes de tocar el test. Hermana de
[[el-script-de-mutantes-revierte-mi-trabajo]] y [[mutantes-sin-diagnose-y-con-copia]].
