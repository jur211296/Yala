---
id: cloud-progress-shows-real-steps-and-counts
status: qa
priority: high
area: "modo-nube, settings, ux"
created: 2026-10-21
updated: 2026-10-23
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

Jürgen eligió la **B** el 2026-10-22 (05:42).

## Lo que no se arregla con diseño

El tiempo de la espera a iCloud en un teléfono recién instalado depende de cuánto tiene que bajar el espejo. Con una
zona sana y pocos datos debería ser corto; el canario nuevo dice cuánto pesa en la flota.

## Hecho (2026-10-23, Frank)

- **Opción B tal cual el lienzo**, en `CloudProgressStepsView` + `CloudProgressStepsLogic` (pura): la ida son cuatro pasos
  (Conectar · Preparar · Subir con «X de N» y su barra · Confirmar con iCloud) y la vuelta tres (Traer de la nube · iCloud
  revisa lo que ya tiene · Subir a iCloud con «N por subir»). «Esperar a iCloud» sale con su explicación cuando la app espera
  el import (pre-espera del controller **o** la del runner, que antes era muda). «Borrar y volver a iCloud» empieza por el
  paso del borrado con su cifra, y la tarjeta de pasos sale desde el «Sí» aunque el journal siga en «nube activa». Sin
  «Retomar». Textos en los 16 idiomas.
- **Asumido**: la cifra de la subida cuenta TODAS las filas («650 de 1.537», sin «movimientos»): con pocos movimientos lo
  que más sube pueden ser tipos de cambio y cuentas, y «0 de 5 movimientos» se habría quedado quieto minutos. «Este iPhone»
  del lienzo pasa a «este dispositivo» (iPad).
- **La cifra se mueve**: la subida avisa por cada trozo de 50 que el servidor confirma (`SyncPushClient.push(onChunkConfirmed:)`);
  la vuelta relee los pendientes en cada re-empuje, que en las esperas locales de iCloud pasa de 30 s a 5 s.
- **Menos espera de la app**: el paso del marcador espera su export dentro de la pasada (1 s, hasta 30 s) en vez de aparcar
  hasta el siguiente re-empuje. La espera al import de iCloud **se queda** (guardar durante el import tumba la app y subir con
  el import a medias sube un corpus incompleto).
- **Medición en la flota**: `cloudMigrationStep` (de qué paso a cuál, con lo que duró el anterior) y
  `cloudMigrationImportWaited` (cuánto se esperó a iCloud y cómo acabó).

## Guion de QA en iPhone (Yala Dev contra staging, luego TF)

1. Activar la nube con pocos datos: ver Conectar → (Esperar a iCloud si toca) → Preparar → Subir con su cifra → Confirmar.
   Anotar la hora de inicio y de «Nube activa».
2. Con miles de movimientos: la cifra de «Subir tus datos» cambia cada pocos segundos.
3. Volver a iCloud (y «Borrar y volver a iCloud» con datos de antes): desde el «Sí» la tarjeta dice qué hace; «iCloud revisa
   lo que ya tiene» hasta que la cifra empieza a bajar; luego «Subir a iCloud» con lo que falta.
4. Mirar en Analytics Engine la serie `cloudMigrationStep` de esa instalación: dice qué paso se llevó el tiempo.
