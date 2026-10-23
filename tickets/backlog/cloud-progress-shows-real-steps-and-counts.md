---
id: cloud-progress-shows-real-steps-and-counts
status: backlog
priority: high
area: "modo-nube, settings, ux"
created: 2026-10-21
updated: 2026-10-21
source: "tablero igt9 (barra quieta en ~60 %), ppxk (6 movimientos, más de 5 min) y 27z3 (la vuelta no dice que trabaja) — QA guiado 2026-10-19/20"
---

# «Activar la nube» y «Volver a iCloud» dicen qué hacen y cuánto falta

## En lenguaje de usuario

Mientras se activa la nube o se vuelve a iCloud, la tarjeta enseña una barra que se queda quieta minutos (55 %, 90 %, o
«Pendientes de subir: 448» sin bajar) y no dice qué está pasando. Parece colgada.

## Lo medido

- **Activar la nube, TF19 en producción (20-oct):** 9 min y medio de consentimiento a corte del servidor. En esos 9 min
  el teléfono no emitió NADA: ni un export de iCloud (el último 21:37:11, el siguiente 21:46:45). INFERIDO: el espejo de
  iCloud estaba bajando la zona (instalación nueva con un iCloud lleno de restauraciones) y la migración esperaba a que
  terminara. Desde este cambio, agotar esa espera emite `cloudMigrationImportNotSettled` con `…|runner`: la próxima
  corrida lo confirma o lo refuta.
- **Con muchos movimientos (igt9):** la barra avanza por fases (22, 35, 55, 75, 80 %) y no se mueve mientras sube el tramo
  largo, aunque en staging subían ~17 movimientos por segundo.
- **Volver a iCloud (27z3):** «Pendientes de subir: 448» quieto ~10 min y terminó de golpe, dos veces.
- **Qué se puede contar de verdad:** lo que ya subió de cada tabla (el cursor de la subida) contra lo que hay; si iCloud
  está importando (`iCloudSyncService.status`); lo que queda por subir en la vuelta. **No** se puede contar cuánto le
  falta a iCloud por bajar: iOS no lo dice.

## Propuestas (lienzo: https://claude.ai/artifact/CvEQtrq9rTpfwvAXH9PLpq)

- **A · Contador real:** la barra sigue la cifra del tramo largo («650 de 1.537 movimientos») con un indicador de
  actividad.
- **B · Pasos con su cifra (recomendada):** cuatro pasos con check; el que está en marcha lleva su barra y su cifra, y
  cuando la espera es de iCloud lo dice con su nombre («Esperar a iCloud · iCloud todavía está trayendo tus datos a este
  iPhone»). La misma forma sirve a la vuelta a iCloud.
- **C · Contador + tiempo que queda:** porcentaje real y «Quedan unos 2 min» calculado con el ritmo. Más preciso a la
  vista, pero el ritmo de iCloud no se mide y el tiempo podría mentir en las esperas.

Espera la elección de Jürgen. Tras elegir: textos en los 16 idiomas y capturas en el simulador para aprobar.

## Lo que no se arregla con diseño

El tiempo de la espera a iCloud en un teléfono recién instalado depende de cuánto tiene que bajar el espejo. Con una
zona sana y pocos datos debería ser corto; el canario nuevo dice cuánto pesa en la flota.
