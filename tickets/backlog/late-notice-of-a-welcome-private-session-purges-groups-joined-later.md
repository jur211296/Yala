---
id: late-notice-of-a-welcome-private-session-purges-groups-joined-later
status: backlog
priority: medium
area: "groups, onboarding, modo-nube"
created: 2026-09-27
source: "hallazgo de `activation-private-gate-leaves-a-late-notice-that-purges-groups` (2026-09-27); inferido por lectura, NO reproducido"
---

# El aviso tardío de quien empezó en el Welcome se lleva los grupos a los que se unió después

## El síntoma, en lenguaje de usuario

Empiezo Yala con «Es mi primera vez → privado» sin iCloud (o sin red). Semanas después me uno a un grupo. Cuando iCloud
vuelve, aparece «Encontramos datos tuyos en iCloud». Si elijo «Empezar de cero», además de mis registros se van mis grupos
de este teléfono y la sesión de Grupos, aunque el aviso solo nombra «tus registros, tus cuentas y tus presupuestos».

## Lo medido (2026-09-27, leyendo código)

- El testigo del espejo tardío lo escribe la puerta del Welcome (`continueWithoutValidating`).
- Fuera de una sesión nacida de «Activar Yala completo», el aviso borra con `.handover`
  (`ICloudWipeScope.lateNotice(sessionBornFromFullActivation: false)`): sube los cambios de grupos pendientes, purga el
  dominio local, lo sella y retira la sesión de Grupos (`DataWipeService.wipeLocalGroupsDomain`).
- `.handover` es la frontera de «aquí empieza otro usuario», y la propia doc de `ICloudWipeScope` dice que quien contesta
  al aviso tardío es la misma persona. Los grupos siguen en el backend: se recuperan entrando otra vez.

## Qué hay que decidir

El mismo aviso termina también el borrado a medias de la puerta del Welcome (`.leaveForLateNotice`), y ahí el dominio
puede ser de otra persona. Separar los dos casos pide saber de quién son los grupos: ¿se unió a ellos después de su
elección privada, o estaban de antes? No hay hoy un hecho durable que lo diga.

## Criterios de aceptación

- [ ] «Empezar de cero» del aviso tardío no se lleva grupos a los que la persona se unió después de elegir privado.
- [ ] El borrado a medias del Welcome sigue sellando el dominio de quien usó el teléfono antes.

## Relacionados

- [[activation-private-gate-leaves-a-late-notice-that-purges-groups]]
