---
id: device-qa-groups-account-association
status: done
priority: high
area: "settings, groups, modo-nube"
created: 2026-09-11
source: "paso 10 del rediseño de sesiones (`groups-account-association-in-storage-row`)"
updated: 2026-09-23
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - fuera del corte de hoy; GroupsAccountAssociationTests cubre asociar, soltar y conservar
---

# Device-QA · asociar y desasociar la cuenta de grupos

**NO es simulable.** Hacen falta CloudKit real, una cuenta de Yala real en el backend y —para el
recorrido 5— un segundo dispositivo con el mismo Apple ID. El simulador no tiene sesión de nube: los
XCUITest fingen el predicado `hasSession` y no crean ninguna cuenta.

## Montaje

- iPhone con **sesión privada** (datos en iCloud) y onboarding completado.
- Una cuenta de Google o Apple que en el backend sea `groups_only` o no exista todavía.
- Para el 5: iPad o segundo iPhone con el MISMO Apple ID y la app instalada.

## Recorridos

**1 · Asociar (AC 1).** Ajustes → «¿Dónde viven tus datos?». Bajo **Grupos** tiene que salir «Asociar una
cuenta para grupos». Tócalo: Ajustes se cierra y aparece el sign-in de Grupos. Entra con Google. Termina
el alta. Vuelve a Ajustes → la sección dice **tu correo**. Abre la pestaña Grupos: tus grupos están.
→ Comprueba además que al volver de Ajustes NO se ha quedado nada bloqueado: crea una transacción y
  comprueba que el aviso de la bandeja o el paywall siguen saliendo cuando toquen.

**2 · Desasociar CONSERVANDO (AC 2).** Antes: crea 3 gastos de grupo que pagues TÚ, y comprueba que los 3
salen en tu Panel. Ajustes → Grupos → «Desasociar» → «Conservar los gastos que pagué».
→ Los 3 siguen en el Panel **sin marca de grupo**, y ahora se pueden **editar y borrar** (ábrelos y
  compruébalo: es la mitad que el diseño anterior rompía).
→ Los apuntes de «presté X» / «debo Y» desaparecen — es lo que el copy anuncia.
→ La pestaña Grupos ya no tiene tus grupos.
→ **Desde otro dispositivo o desde la web**, la cuenta y sus grupos siguen vivos en el backend.

**3 · Re-asociar la MISMA cuenta (AC 3).** Vuelve a asociar la misma cuenta. Los grupos vuelven.
→ **Cuenta los movimientos del Panel: los 3 gastos tienen que seguir siendo 3, no 6.** Es el criterio que
  el libro de conservados existe para cumplir.
→ Residual conocido y esperado: los 3 NO vuelven a estar enlazados al gasto de grupo (ticket
  `groups-reassociation-does-not-restore-the-bridge-link`). Editar el gasto en el grupo no los cambia.

**4 · Asociar OTRA cuenta (AC 4).** Desasocia conservando y asocia una cuenta DISTINTA.
→ Los 3 movimientos de antes se quedan como estaban.
→ Los gastos de los grupos de la cuenta nueva llegan limpios y se puentean normal.

**5 · Segundo dispositivo (AC 6).** Con la cuenta asociada en el iPhone, abre la app en el iPad del mismo
Apple ID y restaura desde iCloud.
→ Ajustes → «¿Dónde viven tus datos?» tiene que decir **«Tus grupos están en \<tu correo\>»** con el botón
  «Entrar con esa cuenta» (la sesión no viaja; la asociación sí).
→ La pestaña Grupos tiene que ofrecer **entrar**, no «crear una cuenta».
→ **Y la prueba que más importa:** desasocia en el iPhone, deja pasar un rato, y **abre el iPad**. Al
  volver al iPhone, la asociación tiene que seguir soltada. Si reaparece, el tombstone no está llegando.

**6 · Nube completa (AC 5).** En un dispositivo con la sesión personal ya en la nube, la sección tiene que
decir «Tus grupos usan esta misma cuenta» y **no** ofrecer desasociar.

**7 · Bloqueo.** Pon el teléfono en modo avión con un gasto de grupo recién creado (sin subir) y toca
«Desasociar».
→ Tiene que salir **el aviso de esta pantalla** («No pudimos soltar la cuenta»), no el del cierre de
  sesión, y nada tiene que soltarse.
→ Cierra el aviso y vuelve a tocar «Desasociar»: **tiene que responder**. Si el segundo toque no hace
  nada, la fase se quedó bloqueada.

**8 · Los OTROS miembros no pierden nada (2026-09-11, ticket
`detach-history-replay-can-tombstone-groups-on-next-launch`).** Es el recorrido que más daño evita y
**necesita dos personas**: el gasto que se borraría es el de los demás.

Montaje: un grupo con **otro miembro real** (segundo Apple ID / segunda cuenta de Yala) y **3 gastos suyos**
visibles en los dos teléfonos.

1. En tu iPhone: desasocia la cuenta de grupos (cualquiera de las dos salidas).
2. **Mata la app del multitarea y vuelve a abrirla.** Este paso es el recorrido: el daño no ocurría en la
   sesión del desasociar sino en el ARRANQUE siguiente, cuando el canal vuelve a mirar el historial local.
3. Vuelve a asociar la MISMA cuenta y espera a que los grupos bajen.
4. **Mira el teléfono del OTRO miembro**: sus 3 gastos tienen que seguir ahí. Si desaparecen —a él, sin que
   él haya tocado nada—, el borrado local está viajando al servidor y hay que parar el release.
5. Repite el ciclo una segunda vez sin cerrar la app entre medias.

→ Comprueba también en tu propio teléfono que los grupos vuelven completos (no una cáscara sin gastos).
→ Si tienes acceso al panel del backend: cero filas nuevas con `op = tombstone` para esa zona durante todo
  el recorrido.

**NO es simulable, y el porqué es el de siempre:** el simulador no tiene sesión de nube ni un segundo
miembro, así que el unit test llega hasta «el teléfono no encola la escritura» y el resto —que el servidor
no la reciba y que el otro miembro no la vea— solo se ve en device.

## Lo que NO entra aquí

La promoción de la asociada a `complete` desde «Migrar a la nube»: su cableado es del ticket
`settings-migrate-to-cloud-adopts-silently-instead-of-migrating`. Este paso solo entrega el dato.

## Nota · 2026-09-16 (barrido de QA)

- **Absorbe desde hoy a dos tickets cerrados:** `groups-account-association-in-storage-row` (recorridos
  1 a 7) y `detach-history-replay-can-tombstone-groups-on-next-launch` (recorrido 8).
- **Hueco:** la salida «Quitarlo todo del Panel» no tiene recorrido propio. Solo aparece como «cualquiera
  de las dos salidas» (:73). Al hacer el recorrido 5 o el 8, prueba también esa salida: tras desasociar con
  ella no debe quedar ningún movimiento con marca de grupo, y la asociación debe seguir soltada tras abrir
  el iPad.
- **No añadas** el recorrido que prometía `detach-failure-looks-like-success`: no se puede ejecutar en
  device (ese ticket se cerró como no replicable).
- **Ya visto en simulador, con seams:** bajo el kill-switch, la fila con «Desasociar» y sin «Migrar a la
  nube» (`cloud-killswitch-hides-the-only-door-to-detach-groups`, PASS 2026-09-16).

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Queda fuera del corte de hoy: no toca nube, restaurar ni migrar, y dos de sus recorridos piden un iPad y otra persona. Lo cubre `GroupsAccountAssociationTests`.
