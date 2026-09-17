# Spinner de hidratación: ríndete si el teléfono no consigue App Attest

## Contexto
Ticket: `tickets/backlog/cloud-hydration-spinner-never-gives-up-without-attest.md` (medium).
Sale de la review de #177. En un teléfono que no consigue App Attest, «Descargando tus datos…» gira para siempre y ahora, además, convive con el aviso de que este teléfono no puede sincronizar. El spinner es preexistente; el aviso lo vuelve contradictorio.

Cola noche 2026-09-16/17 (Frank): tras #188 personal-sync. Siguiente tras este: `fresh-start-keeps-a-groups-session-that-migrate-promotes` (decisión ya en ticket: no promover sesión de grupos preexistente).

## NOCHE (21:00–6:00 Lima)
Elige lo recomendado **sin** AskUserQuestion. Si es demasiado gordo, aparca y avisa a Frank.

**Decisión ya tomada (Frank, recomendada del ticket):** opción 1 — el spinner se rinde. `CloudHydrationLogic` gana un cuarto término (veredicto terminal de attest) y el banner desaparece; queda solo el aviso de attest, una sola voz. No inventes copy nuevo en 16 idiomas (opción 2). No dejes el spinner eterno (opción 3).

## Que se pide
1. Cuando el veredicto de attest es terminal, no mostrar el banner «Descargando tus datos…».
2. Tests según el repo (el banner no debe co-aparecer con el aviso terminal).
3. Gate, commit, mover ticket + actualizar `docs/TICKETS.md`, PR, merge a 2.1, `/cerrar-total`. Bugs/decisiones nuevas → ticket propio antes de cerrar. No sync al Kanban del panel.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board del repo/`docs/TICKETS.md`/merge/`/cerrar-total` sin preguntar. Noche: aparca solo si la decisión es demasiado importante. UI CI advisory (continue-on-error).

## Que NO
marketing/; no reabrir el aviso de attest del #177 salvo el término que apaga el spinner.

## Como se sabe que esta bien
Con veredicto terminal de attest + store vacío + motor parado: no gira «Descargando tus datos…»; el aviso de attest sigue siendo la voz. Con hidratación real en curso (sin terminal): el banner sigue. Board al día y `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo a reclasificar, build a reintentar, ni ruido de CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (encargo de noche, bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Corregidas tras la review adversarial (dos lentes, 2026-09-17): lo que la review midió está marcado **[review]**.

**Hechos medidos antes de decidir** (árbol `2.1` @ `3eed0fb50`):

- **El pull del MOTOR exige token, y ese token borra la racha.** `CloudSyncRuntime.performCycle` pasa por la puerta
  (`resolveAttest`) antes de subir y de bajar, y con token llama a `GroupsAttestStreakStore.recordAcceptance()`. ⇒ con
  el veredicto terminal el motor no está bajando nada. La única ventana es el arranque, antes de que el primer ciclo
  resuelva la puerta: una racha heredada se borra ahí y la descarga empieza justo después. **[review]** Los pulls de la
  migración (`MigrationWorkExecutor.verify` y el drenaje de la vuelta a iCloud) no pasan por esa puerta: piden el token
  con `try?` y no tocan la racha.
- **Premisa corregida: el motor no siempre está parado.** El `stoppedUntilRelaunch` del ticket no sale del veredicto: sale
  del presupuesto de `AttestSyncGate.classify`, un `.unavailable` tras tres fallos seguidos de la puerta en el mismo
  proceso (**[review]** el presupuesto lo gasta cualquier fallo; solo `.unavailable` lo cierra). Con los demás fallos que
  cuentan en la racha (`DCError`, `yala_attest_invalid`, `unknownKey`) el motor reintenta con backoff para siempre. En los
  dos casos el primer pull no cierra nunca y el spinner gira igual: el arreglo vale para los dos.
- **El sondeo actual termina con el primer `false`** (`guard visible else { return }`), y el veredicto depende del reloj
  y vive en `UserDefaults`: ninguna vista se entera sola.

**D1 · ¿El cuarto término es el veredicto a secas o la decisión entera del aviso (`CloudAttestNotice.isShowing`)?** →
El veredicto a secas, `GroupsAttestStreakStore.isTerminal()`.
Por qué: con él el motor no puede estar bajando nada (primer hecho), y ésa es la descarga que el spinner explica.
Alternativa descartada: la decisión del aviso. Sus otras condiciones dicen a quién le es cierta la frase del aviso, no si
el motor baja algo: con ellas el spinner volvería sin sesión. Y leería el Keychain una vez por segundo, para siempre, en
el teléfono sin attest. En la población del ticket (nube, sesión, canal estable) las dos coinciden. **[review]** En una
vuelta a iCloud retomada tras relanzar, el drenaje baja datos sin tocar la racha y el banner puede esconderse mientras
tanto; antes giraba hasta relanzar. Se acepta y queda escrito en el docblock.

**D2 · ¿Cómo se entera el banner de que el veredicto cambió?** → Lo lee vivo en el tick de 1 s que ya tiene.
Por qué: el banner ya sondea porque `hasCompletedFirstPull` tampoco es observable. Leído en cada tick, el spinner se va
como mucho un tick después de que el veredicto se vuelva terminal y vuelve igual de rápido cuando la puerta borra la
racha. Con una escritura de la racha, el aviso sale en el acto: coinciden como mucho un tick. Alternativas descartadas:
(a) `.cloudAttestVerdictWatcher` con un `@State` y `.task(id:)`. Serían dos `@State`, el del Panel y el del overlay, que
se refrescan al montar vistas distintas: el aviso podía salir con el spinner aún girando, que es la co-aparición del
ticket. (b) Leerlo solo al montar. Con el sondeo que acaba en el primer `false`, una racha heredada que el primer ciclo
borra dejaría la descarga real sin banner.
**[review] Residual aceptado:** si el veredicto cambia por el RELOJ (las 24 h se cumplen con la app delante), nadie
escribe la racha. El spinner se va y el aviso espera a su siguiente refresco: en ese rato no sale ninguno. Dura como mucho
un backoff (300 s) con el motor reintentando, porque el rechazo que marca `terminalReported` notifica, y hasta el siguiente
gesto con el motor parado por `.unavailable`. Con el reloj hacia atrás justo después del cruce, salen los dos hasta ese
gesto. Cerrarlo pide que el aviso también sondee, y eso es reabrir el aviso del #177, que el encargo excluye. Se prefiere
el silencio breve a la co-aparición, que es lo que el ticket pide evitar.

**D3 · ¿Cuándo termina el sondeo?** → Solo cuando lo descarta un término que no es el veredicto: primer pull cerrado o sin
motor de nube, y con datos en pantalla **si ya los había al montar** (**[review]** el `.task` captura `storeLooksEmpty`
y no se reinicia cuando el shell lo vuelve a medir; es anterior a este cambio y va a ticket). Va en una función pura
aparte (`keepsWatching`).
Por qué: el veredicto se cura solo con un token, y la descarga empieza justo después. Si acabara el sondeo, el banner no
volvería. Coste: en el teléfono sin attest el tick sigue a 1 s, lo mismo que hoy con el spinner visible. Alternativa
descartada: dejar `guard visible`, que es el bug de D2 (b).

**D4 · ¿Parámetro con valor por defecto?** → No. `attestVerdictIsTerminal:` sin default, como
`CloudAttestNoticeLogic.showsNotice`: quien llame se pronuncia.

**D5 · ¿Cómo se prueba?** → Tabla pura exhaustiva (16 filas) más casos con nombre, y dos source-scans del banner: el cuerpo
ENTERO del `.task`, y (**[review]**) que ese `.task` cuelga de la raíz del body, es el único y es el único que escribe
`visible`. Mutantes: quitar el término, pasar `false` desde la vista, volver a `guard visible`, leer el veredicto fuera del
bucle y mover el `.task` dentro de `if visible`. **Sin XCUITest.** No hay seam de uitest para `storageMode == .cloud`
(precedente #177), y un negativo en `.icloud` no puede fallar: ahí el banner ya no sale.

**D6 · ¿Adónde va el ticket?** → `done`, como #177. El caso positivo no se monta en simulador (sin seam de `.cloud` y sin
el secreto de staging) ni en un iPhone real, que sí atesta. Lo cubren la tabla, los scans y los mutantes, y se dice en el
ticket.

**D7 · ¿Qué documentación?** → El docblock del banner (tercer falso positivo, por qué el veredicto no acaba el sondeo y lo
que no cubre) y una viñeta en `.claude/rules/gateway-attest.md`: de qué se fía (el pull del motor pasa por la puerta), que
es otro lector sin el testigo del ciclo, que no se gatea por la decisión del aviso, y el residual del reloj. Sin copy ni
l10n. `qa/coverage-index.json`: el banner entra en `cloud-sync-runtime`, junto al aviso.

**D8 · ¿Review adversarial?** → Sí, corta: dos lentes con refutación por hallazgo. Una para la carrera entre sondeo,
veredicto y arranque, y otra con la rule del área leída contra el diff. **[review]** Ninguna tumbó el diseño. Confirmados y
corregidos: afirmaciones demasiado anchas («una descarga exige token», «en una reversa no baja nada»), el residual del
reloj sin escribir, el scan que no fijaba dónde cuelga el `.task`, un docblock de test que prometía de más y el índice de
cobertura. Descartados al comprobar: coste nuevo del sondeo, otro escritor de `hasCompletedFirstPull`, `.task` fuera de
MainActor y una pestaña o un borrado que maten el sondeo sin reponerlo.

**D9 · ¿Qué hallazgos salen a ticket?** → Dos, `low`, tras buscar el duplicado por síntoma:
`cloud-hydration-spinner-keeps-spinning-with-the-engine-stopped` (el spinner no mira el estado del motor: gira con el
motor parado por algo que no es el veredicto) y `cloud-hydration-banner-does-not-see-data-that-arrives-after-mount`
(`storeLooksEmpty` congelado en el `.task`). No se arreglan aquí: el encargo decidió el término del veredicto, y el
segundo cambia cuándo desaparece el banner en una hidratación normal. **Sin ticket**, por ser la decisión ya tomada: fuera
del Panel y de «Dónde viven tus datos» no queda ninguna voz (el ticket sabía que el spinner salía en todas las pestañas y
eligió dejar solo el aviso).
