---
name: reloj-por-causa-en-el-techo-pre-mount
description: PR #210 (2026-09-22) — el techo previo al montaje pasa a dos relojes; la review cazó 6 defectos míos y cambió el diseño de racha a acumulado. Deja el GEMELO de la espera de subida con ticket propio.
metadata:
  type: project
---

**PR #210, en `qa`.** El techo de las cuatro fases previas al montaje de la vuelta a iCloud pasa de UN reloj a DOS:
el de FASE (72 h, cualquier causa) y el de CAUSA (15 min, tiempo ACUMULADO bajo un mismo motivo). Salida con el
primero que venza. `MigrationState` sube a schema 8.

**Why:** un `localFailure` aislado tras horas de espera por red se cobraba las horas y abandonaba la vuelta sin un
reintento. El ticket lo abrió la review del hermano (`reverse-verify-network-bucket-hides-a-definitive-server-no`,
PR #209), y Jürgen decidió en bloque: reloj por causa, un solo mecanismo para los cinco motivos, y el residual del
outbox fuera de este encargo.

**How to apply:**

- **El techo largo aplica con CUALQUIER causa, y es el suelo del mecanismo.** No es redundancia: sin él, dos motivos
  definitivos alternándose reinician el corto en cada observación y la espera vuelve a no tener techo. Si alguien
  propone «el largo solo para lo desconocido», eso reabre el bug-class de la familia.
- **Los presupuestos se llaman `reversePreMountCauseBudgetSeconds` y `reversePreMountPhaseBudgetSeconds`** desde este
  PR. Los nombres viejos (`Definitive`/`Unknown`) ya mentían.
- **El predicado del techo corto vive en `MigrationPolicy.reversePreMountCauseCeilingReached`**, y lo consultan la
  máquina (para salir) y el runner (para elegir el motivo journaleado). No lo dupliques.
- **La serie `cloudReversePreMountWaiting` cambió de forma**: `<fase>|<tramo de fase>|<tramo de causa>|<causa>`, con
  `-` cuando no hay motivo. Cambió de valores dos días seguidos (21 y 22 de septiembre); una caída del tramo alto en
  `stop_*` es el arreglo, no una mejora de la flota.

**Lo que dejó abierto**, y es lo primero que hay que mirar al retomar esta zona:

- **`reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`** — el GEMELO. `observeReverseUploadWait` tiene
  la misma forma y sigue con un reloj. Camino medido: tras horas sin cuenta iCloud (plazo largo), entras a iCloud y
  el espejo contesta `notAuthenticated` —lo habitual justo al iniciar sesión, y que el propio código trata como
  pasajero—, lo que elige el plazo corto y cobra las horas de golpe. Su implementación tiene una diferencia real con
  ésta: allí existe una noción de AVANCE (la cifra de pendientes que baja), y el reloj de causa tiene que convivir
  con ese re-sellado.
- **`verify-reads-a-failed-local-fetch-as-an-empty-outbox`** — el residual hermano, que va en serie después.

**El device-QA no puede montar el escenario del ticket** (tres horas de espera y un fallo local en la pasada justa).
El guion del ticket comprueba las dos mitades que el cambio podría haber roto: que el 403 repetido siga saliendo a
los 15 min —si el reloj de causa no persistiera, ese paso no terminaría nunca— y que un corte de red de un minuto
PAUSE la cuenta en vez de reiniciarla.

Relacionado: [[feedback_un_reinicio_se_mide_contra_su_cadencia]],
[[project_un_no_definitivo_en_la_vuelta_ya_no_espera_72h]], [[feedback_el_copy_lo_elige_quien_produjo_el_motivo]].
