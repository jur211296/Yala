# Los grupos que el aviso tardío conserva no se pierden si la persona cancela el onboarding y vuelve a elegir privado en la bienvenida

## Contexto
Ticket `tickets/backlog/groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start.md` (léelo entero primero). Tarjeta del tablero cba9.
Contesto «Empezar de cero» en «Encontramos datos tuyos en iCloud». Mis grupos se quedan y vuelvo al onboarding personal. Si ahí toco «Cancelar», vuelvo a la bienvenida; si elijo «Es mi primera vez → privado», sale el aviso de «hay datos en este teléfono» con el texto de «aquí empieza otro usuario» y, si confirmo, se borran también mis grupos, su sesión y el dominio queda sellado. Lo medido en el ticket es por lectura de código (`ContentView.presentNextOnboardingScreen`, `startFreshPrivateOnboarding` → `hasLocalDataNow` → `SplitGroup`, puertas de organizador e invitación con `.returnsToNeutral`), no reproducido: verifícalo antes de cambiar nada.

Decisión de Jürgen del 2026-10-04: **opción A**. Camino de la misma persona: conservar los grupos. El aviso tardío no prueba que sea otra gente, así que quien acaba de conservar sus grupos no los pierde por cancelar el onboarding y volver a elegir privado.

Jürgen prefiere siempre lo más robusto y la mejor práctica, aunque tome más tiempo. Si cambia algún texto visible, español neutro latinoamericano en es/es-419 (nada de vosotros) y variantes completas en los 16 idiomas.

## Qué se pide
- Que, tras conservar los grupos en el aviso tardío, volver a la bienvenida y elegir privado siga el camino de la misma persona: los grupos, su sesión y el dominio quedan intactos, sin el alert de handover de «otro usuario».
- Revisar las puertas de organizador e invitación que hoy ven esos grupos como datos del teléfono, y alinearlas con la misma decisión.
- Que el handover real (otra persona de verdad, sin aviso tardío previo en esta instalación) siga funcionando como hoy.
- Tests que fijen los dos caminos (misma persona tras el aviso vs. handover real) y mutantes que lo prueben.
- Capturas de antes y después en `capturas/` del worktree (`antes.png`, `despues.png`) si el cambio se ve y el estado se puede montar en el simulador; si no se puede, dilo en el cierre en vez de inventarlas.
- Ticket a `qa` con guion corto de device-QA si hace falta (o a `done` si no), `docs/TICKETS.md` y `qa/coverage-index.json` al día.
- Cierra con PR a `2.1` en auto-merge y luego `/cerrar-total` autónomo, sin esperar a Jürgen.

## Qué NO hay que tocar
- El borrado del handover cuando de verdad entra otra persona.
- El aviso tardío en sí (su texto y sus opciones).
- marketing/ y Web/.

## Pipeline serial en la Mini (obligatorio)
1. Limpiar sims muertos, basura previa, DerivedData de sesiones ya cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen. Sin preguntar.
2. Build con `xcodebuild -jobs 2` sin simulador encendido.
3. Encender UN solo simulador.
4. Tests.
5. Apagar y borrar los datos de ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests. La Mini anda justa de disco (~36 GB libres).

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. Justo antes del gate, mira si el PR #379 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez. (#379 toca la bienvenida y los 16 Localizable.strings: resuelve el conflicto si sale.)

## DerivedData y cachés
Al lanzar y al cerrar, borra sola el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No preguntes. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

## Cierre limpio
Al `/cerrar-total`: apaga el simulador que usaste, borra sus datos, quita el worktree y su DerivedData si ya no hace falta, y no dejes devices apagados ni worktrees huérfanos. Si creaste algún secreto en el Llavero, dilo en el cierre.

## Cómo se sabe que está bien
- Quien conserva sus grupos en el aviso tardío, cancela el onboarding y vuelve a elegir privado, sigue con sus grupos y su sesión.
- El handover real sigue borrando como hoy.
- Build verde, unit y UI de las áreas tocadas verdes, mutantes muertos.
- PR a 2.1 en auto-merge, capturas antes/después (o motivo de su ausencia), Mini limpia.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (lectura del árbol en `123f59cd7`).** El aviso tardío borra con `.importedRows`
(no resetea preferencias, así que `hasShownWelcomeChooser` sigue en `true`) y `settleAfterLateICloudWipe` baja
`hasCompletedOnboarding`. Tras «Cancelar» en el paso 1, el Welcome trata los grupos conservados como datos de otro en
**seis** sitios, no en uno: (A) `startFreshPrivateOnboarding` —el alert, y en su rama sin datos el retiro de la sesión y
del espejo de la asociación—; (B) `onNeedsMirrorRelaunch(.privateOnboarding)`, que con mount neutro arma el retiro de la
sesión; (C) `deviceCorpusGate` (mount neutro), cuyo borrado purga y sella; (D) el borrado de «Encontramos datos en
iCloud» de la puerta privada del Welcome, que es `.handover`; (E) el término de datos de la puerta del organizador;
(F) el de la puerta del invitado.

**D1 · ¿Cómo sabe el Welcome que los grupos son de la misma persona?** → Una marca durable nueva,
`LateNoticeKeptGroupsMark`, que escribe el borrado del aviso tardío cuando conserva los grupos, atada al `sub` de la
sesión de Grupos de ese momento (o a «sin sesión»). Vale solo mientras la sesión sea la misma.
Por qué: es el único hecho que separa «el aviso conservó estos grupos» de «hay grupos de alguien». Alternativa
descartada: leer `PrivateSessionMark` en `true` con el Welcome visible — es implícito y tiene nueve escritores.

**D2 · ¿Dónde nace y dónde muere?** → Nace en `performLateICloudWipe`, en la rama que no purga el dominio, antes de que
el llamador desarme el borrado (un kill reanuda y la vuelve a escribir). Muere al completarse el onboarding (transición
en proceso + barrido al arrancar), dentro de `wipeLocalGroupsDomain` y en el borrado del cierre de sesión. Y deja de
valer sola si cambia la sesión de Grupos.
Por qué: describe a los grupos y a quien hace el onboarding; ninguno de los dos sobrevive a esas tres fronteras.

**D3 · ¿Qué cambia con la marca válida?** → Los seis sitios siguen el camino de la misma persona: el Welcome solo cuenta
como «datos del teléfono» lo personal (cuentas y categorías propias); «Es mi primera vez → privado» va al onboarding sin
alert, sin retirar la sesión, sin borrar el espejo de la asociación y sin limpiar nombre y divisa; y el borrado de
«Encontramos datos» del Welcome pasa a `.importedRows` con la convergencia de las filas puenteadas, igual que el aviso.
Por qué: decisión A de Jürgen (2026-10-04). Alternativa descartada: arreglar solo (A) — (B), (C) y (D) llevan al mismo
borrado por otra puerta.

**D4 · ¿Y si con la marca hay además datos personales en el teléfono?** → El alert de siempre, con su borrado de siempre.
Por qué: su copy dice «¿Borrar todo?» y hace eso; ahí hay un corpus que no es el que el aviso conservó (solo aparece si
el espejo vuelve a bajar algo). Alternativa descartada: un borrado del teléfono que conserve grupos — cambia copy en 16
idiomas para un caso marginal.

**D5 · ¿El término del espejo en las puertas de Grupos?** → No se toca. Con el espejo puesto (el caso normal tras el aviso)
las dos puertas siguen devolviendo al neutro, por el espejo y no por los grupos. Esa vuelta es un cierre de sesión que
sube los grupos antes y los recupera al volver a entrar.
Por qué: ese término protege otra cosa (no exportar los gastos de grupo de una sesión solo-grupos al iCloud del teléfono)
y «Qué NO hay que tocar» deja fuera el handover.

**D6 · Copy** → Ninguno cambia.

**D7 · Capturas** → Sí, con un seam DEBUG nuevo (`-uitest-late-notice-kept-groups`) que planta la marca sobre el seed
`solo-grupos`. «Antes» se saca sin el seam: ese estado es exactamente lo que el código anterior veía (no conocía la
marca). Lo dice el cierre.

**D8 · ¿ADR?** → No. Es una convención del código, no una decisión de producto nueva: va como entrada en
`.claude/rules/swiftdata-cloudkit.md`, junto a la del alcance del aviso tardío.

**D9 · Lo que cambió la review adversarial (tres lentes)** → tres decisiones nuevas, en autónomo:
- **Supersede D4: con la marca, ningún borrado del Welcome purga los grupos.** El borrado del teléfono y el del alert
  borran solo lo personal (como el aviso). Por qué: dos lentes encontraron caminos alcanzables —datos que el espejo
  vuelve a bajar, y un kill a mitad del borrado del Welcome que deja mount neutro— que llevaban al mismo handover. El
  copy no cambia («¿Borrar todo?» sigue siendo verdad de lo personal, como el texto del propio aviso).
- **La marca solo la invalida OTRA cuenta abierta; sin sesión vale.** Por qué: el guard cross-cuenta del Welcome cierra
  la sesión que la propia persona abre, y perder la marca ahí devolvía el handover.
- **Nombre y divisa: los limpia quien borra** (la puerta privada, el alert), como hasta hoy; el camino sin borrado los
  conserva. Se retiró el `clearsResidualPreferencesOnWipe` condicional del container: leía la marca al pintar y el
  borrado al borrar, y un test existente lo prohíbe por diseño.
- El XCUITest usa un seed nuevo, `solo-grupos-tras-aviso`: `solo-grupos` siembra categorías propias y el caso de la
  misma persona habría visto el alert por ellas.
