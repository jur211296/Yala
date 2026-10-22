# Al salir de un borrado a medias en la puerta privada, recordar que iCloud ya quedó vacío

## Contexto
Cola A autónoma (riesgo real nube/sync) encadenada tras el cierre limpio de PR #277 (`private-gate-wipe-failure-copy-claims-icloud-is-intact`: si el borrado de iCloud falla con iCloud ya borrado, la puerta ya no dice «intactos»). Esta sesión arranca limpia; no hay otra Yala en curso.

Ticket: `tickets/backlog/private-gate-leave-after-a-halfway-wipe-forgets-the-zone.md` (medium, onboarding/modo-nube). Inferido en el encargo anterior: tras `.wipeFailed` con zona ida, `leaveGate()` llama `clearICloudCorpusWipeArm()` y borra también `icloudCorpusWipeZoneDone`, así que «Dejarlo por ahora» olvida que iCloud quedó vacío con lo del teléfono dentro. El aviso tardío, en el mismo estado, usa `disarmFailedICloudCorpusWipe()` / `leaveICloudCorpusWipeHalfway` y el arranque pregunta. Los tres montajes de la puerta no piden el mismo remedio (Welcome `.handover` sí; activación `.zoneOnly` / «Empezar desde cero» no deben purgar grupos ajenos).

Hora Lima diurna (~07:29): AskUserQuestion OK solo para producto/acceso reales. Frank elige por ti la opción robusta / good-practice (suele ser la Recommended del formulario) y te contesta vía decirle/Enter — no esperes a Jürgen. Device-QA no frena merge ni cierre.

**OVERRIDE AUTÓNOMO (norma Jürgen, vigente):** la regla del repo «wait for approval if >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA. Implementa de cabo a rabo hasta gate verde → PR → merge a 2.1 → `/cerrar-total` sin pedir continuar. Solo AskUserQuestion de producto/acceso real en 06:00–21:00 Lima; nunca «¿sigo?» ni «¿mergeo?».

## Que se pide
1. Reproducir/medir el olvido al salir de `.wipeFailed(zoneGone: true)` desde la puerta (Welcome y montajes de activación que apliquen).
2. Hacer que, tras salir de un borrado a medias, algo recuerde que iCloud quedó vacío y lo del teléfono no — alineado al desarme del aviso tardío donde el alcance lo permita.
3. Ningún remedio ofrecido a quien activa Yala completo debe purgar sus grupos; si hace falta marca/remedio propio de activación, que respete ese alcance.
4. Si la puerta vuelve a medir y ya no queda nada a medias, la marca se retira.
5. Tests que fijen el comportamiento; gate; PR a 2.1; merge; `/cerrar-total`. Residuos/hermanos fuera de alcance → ticket backlog, no ampliar.

Decisiones de producto robustas por defecto (Frank las asume salvo que midas lo contrario):
- Welcome: al salir de `.wipeFailed` con zona ida, escribir estado «a medias» (como el aviso tardío), no un clear a ciegas.
- Activación: no reutilizar `.handover` si purgaría grupos; marca/remedio de su alcance o re-detección segura.
- Retirar la marca solo donde `measure()` demuestra que ya no hay mitad hecha.

## Que NO hay que tocar
- Prod Supabase / tokens / credenciales.
- Rediseño UI/Cola B, iPad, copy cosmético fuera de este estado.
- Ampliar a reescribir todo el late-icloud notice salvo lo necesario para coherencia de la marca.
- Pedir a Jürgen aprobación de plan, merge o «¿sigo?».

## Como se sabe que esta bien
- Criterios del ticket: tras salir de borrado a medias, algo recuerda iCloud vacío + teléfono no; ningún remedio de activación purga grupos; marca se va si ya no hay mitad.
- Gate verde; PR mergeado a 2.1; `/cerrar-total` con ticket en qa/done según corresponda; hallazgos de alcance → backlog nuevos.

## Paso 0 (Frank, 2026-09-27)

Medido en código antes de tocar nada:

- `.zoneOnly` (activación, puerta privada) devuelve `nil` justo tras marcar la zona: nunca deja filas a medias, porque
  no borra filas. Su «a medias» no existe; salir sigue retirando todo.
- `.importedRows` (activación, «Empezar desde cero») sí: la zona se va y las filas importadas quedan con el espejo
  puesto. Al volver a entrar, la sonda ve iCloud vacío y `.proceed` sigue al onboarding encima de ellas (el hermano
  `discard-gate-proceed-leaves-the-imported-rows-behind`, que el borrado a medias vuelve alcanzable siempre).
- La marca «a medias» solo la lee `runLateICloudMirrorCheck`, que corre con sesión privada. El modo nube cuenta
  como sesión privada y no tiene guard de modo: una marca viva en una cuenta nube ofrecería «Terminar de borrar»
  (`.handover`) sobre sus datos. El Welcome a medias → «Soy nuevo → nube» lo alcanza.
- Una sesión solo-grupos no pasa por el aviso tardío; al completar la activación sí. `completeFullActivation`
  retira el arm pero no la marca.

Decisiones (asumidas, robustas por defecto del encargo):

1. **Parámetro nuevo sin default en la puerta**: qué hace con un borrado a medias. Welcome → «a medias» para el
   aviso tardío (su remedio es `.handover`, el mismo borrado de la puerta). «Empezar desde cero» → «a medias» y, al
   volver a entrar con iCloud vacío, **termina su propio borrado** (`.importedRows`) en vez de seguir. Puerta privada
   de la activación → nada a medias, retira como hoy.
2. **Una sola marca** (`icloudCorpusWipeLeftHalfway`), no una propia de la activación: describe el mismo hecho; lo
   que cambia es quién la termina y con qué alcance.
3. **Ningún activador ve el remedio `.handover`**: `completeFullActivation` retira la marca junto al arm.
4. **El aviso tardío no pregunta en modo nube**: allí la marca ya no describe este store; se retira.
5. **Se retira donde se mide que no queda mitad**: `.proceed` de la puerta que mide el teléfono (Welcome neutro), el
   onboarding privado que arranca con el teléfono vacío (Welcome con espejo), y todo borrado de la puerta que
   termina bien en los montajes que dejan marca.
6. **El fallo tras un «a medias» dice «puede que parte ya no esté»** aunque este intento no llegue a la zona
   (`zoneDone || leftHalfway`), como `classifyLateWipeFailure` en el aviso tardío.

Fuera de alcance → backlog si no existe: el `.proceed` de «Empezar desde cero» sin marca (hermano ya abierto).
