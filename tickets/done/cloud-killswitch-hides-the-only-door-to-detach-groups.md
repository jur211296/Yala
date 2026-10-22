---
id: cloud-killswitch-hides-the-only-door-to-detach-groups
status: done
priority: high
area: "modo-nube, settings, groups"
created: 2026-09-11
updated: 2026-09-16
source: "review adversarial del paso 10 (`groups-account-association-in-storage-row`), lente de estados"
qa-status: passed
qa-date: 2026-09-16
---

# Con el kill-switch de la nube bajado, quien tiene cuenta de grupos asociada se queda sin poder soltarla

## El problema, en lenguaje de usuario

Tengo mis datos en mi iCloud y una cuenta de Yala asociada para Grupos. Si Jürgen baja el kill-switch de
la nube por un incidente, la fila «¿Dónde viven tus datos?» desaparece de mis Ajustes — pero **Grupos
sigue funcionando**, porque tiene su propio interruptor. Me quedo con la cuenta asociada y sin ninguna
pantalla desde la que soltarla.

## Lo medido (2026-09-11)

- `StorageRowGateLogic.isVisible` = `isConfigured && (remoteEnabled || isEngaged)`. Para una sesión
  privada, `isEngaged` es **falso** (`storageMode != .cloud` y `uiState == .idle`), así que la fila
  depende entera de `remoteEnabled` (`CloudRemoteFlags.cloudModeEnabled`).
- Hoy no muerde: `CLOUD_MODE_ROLLOUT_PERCENT = "100"` en producción (`gateway/wrangler.toml`), y
  `CloudBackendConfig.isConfigured` es `true` siempre. La fila se ve y la sección es alcanzable
  (verificado además por XCUITest, `GroupsAssociationRowUITests`).
- Grupos va por `GROUPS_BACKEND_ROLLOUT_PERCENT`, que es otro flag: bajar uno no baja el otro.
- La otra pantalla de cuenta (`profile_yala_account`) no sirve de repuesto: solo ofrece cerrar sesión o
  borrar la cuenta, y además exige sesión viva.
- Variante corta del mismo caso: en una instalación fresca, antes del primer `/config`, el
  `absentDefault` de producción es `false`, así que la fila nace oculta hasta que llegue la primera
  respuesta remota.

**Hasta el paso 10 esconder esa fila bajo el kill era inocuo** —solo hablaba del almacenamiento
personal—; ahora el kill de la nube apaga un control de Grupos.

## Lo que se espera

Decidir cuál de las dos, y dejarlo escrito:

1. El gate de la fila gana un término: visible también si hay una cuenta de grupos asociada
   (`GroupsAccountAssociation.shared.hasAssociation`). Es el mismo criterio del `isEngaged` —«un usuario
   ya dentro conserva su panel de gestión»— aplicado al otro eje.
2. O la sección «Grupos» se muda a una fila propia de Ajustes, con su propio gate.

La (1) es más barata y respeta el porqué del gate actual, que es el escape ante incidente.


---

# Resuelto (2026-09-11) — y la opción (1) resultó tener dos mitades

**Decisión: la (1).** La sección «Grupos» NO se muda a una fila propia: la fila gana un término. Es más
barata y respeta el porqué del gate, que es el escape ante incidente. La (2) queda descartada.

## Lo que se implementó, y en qué se apartó del ticket

**El término no es `hasAssociation`.** El ticket nombraba
`GroupsAccountAssociation.shared.hasAssociation`, y con ese predicado el arreglo habría dejado vivo el
bug para una parte de la población. Medido: la sección ofrece el botón «Desasociar» en sesión privada
**también con una sesión de grupos viva y sin registro persistido** (`GroupsAssociationLogic.sectionState`,
rama `.privateSession`, cortocircuita por `hasLiveGroupsSession`). Esa celda es alcanzable —el «empiezo
de cero» del Welcome borra el espejo local y sella el dominio pero NO cierra la sesión en la nube, y
cualquier sesión anterior al paso 10 depende de que el backfill llegue a escribir— y el gesto funciona
ahí (`detachGroupsAccount` resuelve la cuenta con `associatedSub ?? currentUserID`).

⇒ El término es **«hay una cuenta de grupos que esta pantalla pueda soltar»**
(`GroupsAssociationPresence.offersDetach`), que es la MISMA pregunta que dibuja el botón y sale de la
MISMA lectura. El resolver es nuevo y existe para eso: cuando la fila y la sección leían cada una lo
suyo, divergían en dos celdas, y la otra —registro sin sesión privada, que llega por el iCloud-KV del
Apple ID— abría la fila a una pantalla con el estado y nada más.

**La segunda mitad: abrir la fila abría la migración.** `migrateCard` no tenía candado propio del
kill-switch —`CloudRemoteFlags` no se consulta ni en `StorageSettingsView` ni en
`CloudMigrationController`, cero ocurrencias— así que su cierre durante un incidente era una
CONSECUENCIA de que la fila estuviera oculta. Al abrirla, esa consecuencia se pierde. Se escribe
explícito (`StorageRowGateLogic.offersCloudMigrationEntry`) y **se re-mide en la acción, no solo en el
render**: el flujo consent → doble confirmación → chooser → `startMigration` no volvía a preguntar por el
flag, así que quien tapeó un segundo antes de que aterrizara el snapshot nuevo migraba con el kill ya
puesto. Sale con el error genérico, no en silencio, y sin estrenar copy.

**Los dos guards de arriba siguen mandando** sobre el término nuevo, y es a propósito: sesión secundaria
(la fila es del dueño) y backend sin configurar (detrás no se monta la sección).

## Qué mide qué

- `StorageRowGateLogicTests` — la tabla, las cuatro celdas del eje nuevo (una de ellas mata un mutante
  XOR que sobrevivía a todo lo demás), los dos guards y la tabla 2² de la entrada.
- `StorageRowGroupsAssociationWiringTests` — el cableado: que la fila pregunte por el gesto y no por el
  registro, que **nadie vuelva a derivar el estado por su cuenta**, y que la card de migrar y sus dos
  arranques sigan detrás del gate. Su helper filtra comentarios de bloque además de los de línea:
  sin eso, un `/* */` alrededor del `if` dejaba los cuatro scans en verde (medido).
- Verificado con mutantes en las dos direcciones: los cuatro que se probaron mataron su test y solo el
  suyo.

**XCUITest: no.** Bajo `-uitest` el flag sale de `absentDefault`, que depende del scheme — `true` con
`Yala Dev` (el del gate y el CI), `false` con `Yala`. O sea que el kill SÍ se reproduce en una corrida de
UI, pero solo con el otro scheme, y un test que cambie de signo según el scheme es peor que no tenerlo.
El caso positivo necesitaría además el seam de `uitest-seam-for-a-seeded-groups-association`.

## Lo que queda

- **Device-QA:** `tickets/qa/device-qa-cloud-killswitch-groups-door.md`. **SÍ es simulable** — el toggle
  «Simular remote OFF» del panel DEBUG, en un build Yala Dev.
- **Cuatro tickets** que salieron de la review y no son de este arreglo:
  `groups-killswitch-403-blocks-detach-forever` (**high**: el kill de GRUPOS servido como 403 deja el
  desasociar imposible si hay outbox), `associate-cta-ignores-the-groups-kill-switch`,
  `needsrelaunch-hides-the-groups-section` y `association-read-writes-defaults-from-a-view-body`.

## QA Visual · 2026-09-16 — PASS

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`. Para tener el kill-switch **abajo** se usó el build `Debug` sin `DEV_BUILD`: bajo
`-uitest`, los flags remotos valen su default de producción, OFF. Para tenerlo **arriba**, `Yala Dev`.

| Recorrido | Montaje | Qué se vio |
|---|---|---|
| R1/R2 · kill abajo, con Grupos | `-uitest-fake-cloud-session -uitest-fake-attest-support` | La fila «Dónde viven tus datos» sigue ahí, con **Grupos · Desasociar** y **sin** «Migrar a la nube» |
| R3 · kill abajo, sin cuenta | sin sesión | Sin fila |
| R4 · kill arriba | `Yala Dev` + `-uitest-fake-attest-support` | Vuelve «Migrar a la nube» / «Activar la nube» |

Capturas: [R1/R2](../../qa/evidencia-barrido-20260916/03-killswitch-R1R2-desasociar-sin-migrar.jpg) · [R3](../../qa/evidencia-barrido-20260916/04-killswitch-R3-sin-cuenta-sin-fila.jpg) · [R4](../../qa/evidencia-barrido-20260916/05-killswitch-R4-nube-activa-vuelve-migrar.jpg).

**No se vio** que desasociar llegue al final: pide una asociación real con el servidor. Ese recorrido
vive en `device-qa-groups-account-association`, que sigue en la cola de device.
