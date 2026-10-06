# La tarjeta «Migrar» de Ajustes recuerda la cuenta que la comprobación rechazó: apaga el botón y dice el motivo (decisión A de Jürgen)

## Contexto
Ticket `tickets/backlog/migrate-card-keeps-promising-an-account-the-check-refused.md` (léelo entero primero). Hoy, si la cuenta de grupos ya tiene finanzas personales, «Activar la nube» enseña «Esa cuenta ya tiene finanzas personales»; tras «Entendido» la tarjeta sigue prometiendo esa misma cuenta («Usarás tu cuenta de Yala actual…») con el botón activo, y cada toque vuelve a preguntar a la red y a enseñar el mismo aviso. Lo medido en el ticket es del 16-sep: re-mídelo sobre `origin/2.1` de hoy antes de tocar, porque el área cambió mucho (puede que parte ya no aplique).

Decisión Jürgen 2026-10-04 (tarjeta del centro de mando `tablero-decidir-el-texto-de-la-tarjeta-migrar-qu-iy2l`): **opción A**. Recordar el rechazo mientras dure la sesión, apagar el botón y decir el motivo en la tarjeta. Copy nuevo en los 16 locales (es-AR voseo, es-ES pretérito perfecto, español neutro en `es`).

## Qué se pide
- Recordar el rechazo de la comprobación para esa cuenta (el `sub` o lo que sea la identidad real hoy) mientras dure esa sesión; si cambia la sesión o la cuenta, se olvida.
- Con el rechazo recordado: la tarjeta no promete esa cuenta, el botón queda apagado y la tarjeta dice el motivo en lenguaje de usuario.
- Tests que fallen antes del arreglo y pasen después; mutantes del recuerdo y del apagado.
- Ticket a done con el parte; si el cambio se ve, capturas antes/después del simulador en `capturas/` del worktree (`antes.png`, `despues.png`) y sus rutas en el resumen. Si no se puede provocar en el simulador, dilo y no inventes capturas.
- Si sale una decisión de copy o producto que no cubra la opción A, deja propuestas A/B/C en un ticket nuevo y sigue con lo decidido; no te pares.

## Qué NO hay que tocar
- No cambies qué comprueba la verificación de identidad ni el flujo de migración/adopt en sí; solo lo que la tarjeta recuerda, enseña y permite.
- No toques el alert del shell de «Empezar de cero» ni el adopt cancelado (ticket `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes`, espera decisión de Jürgen).
- Nada de marketing/.

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. No se espera a que el PR anterior (#369) entre, y no se parte de su rama. Justo antes del gate, mira si #369 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Pipeline serial en la Mini (obligatorio)
1. Limpiar (sims muertos, DerivedData de sesiones cerradas, cachés de XcodeBuildMCP de worktrees que ya no existen) sin preguntar. 2. Build con `xcodebuild -jobs 2` sin sim booteado. 3. Boot de 1 sim. 4. Tests. 5. Apagar y borrar ese sim. Prohibido solapar compilación con sim/UITests.
Al lanzar y al cerrar borras tú sola el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados. No preguntes. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

## Cierre
Autónoma de punta a punta: PR contra `2.1` con auto-merge, y luego `/cerrar-total` tú sola (apagar y borrar el sim, retirar el worktree y sus cachés cuando ya no haga falta, Mini limpia). No esperes a nadie para cerrar.

## Cómo se sabe que está bien
Tras el aviso de la comprobación con la sesión de grupos, la tarjeta no promete esa misma cuenta, el botón está apagado y se lee el motivo; con otra sesión o cuenta, la tarjeta vuelve a lo de siempre. Gate verde salvo los rojos conocidos con ticket.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Re-medido sobre `origin/2.1` (7d78e3054), 2026-10-06.** El bug sigue: la nota `storage_account_reuse_note` sale con
cualquier sesión viva y el botón solo se apaga con `isWorking` o el bloqueo del faro. `migrationIdentityBlock` se suelta
al montar la hoja y nada más recuerda el rechazo.

**D1 · ¿Qué identifica «esa sesión»?** → el `sub` de la sesión viva más un contador de sesión en memoria
(`CloudAuthService.sessionEpoch`), que sube en cada inicio de sesión que entra y en cada `signOut()`.
Por qué: el encargo pide olvidar si cambia la sesión, no solo la cuenta, y cerrar y volver a entrar con la misma cuenta
puede cambiar la respuesta (la asociación de grupos, el sello de «Empezar desde cero»). Alternativa descartada: solo el
`sub`, que no ve una re-entrada; y la última entrada de `SessionSignInLog`, que es de otro dueño y otras precondiciones.

**D2 · ¿Dónde vive el recuerdo?** → en memoria, en el controller. Un relanzamiento lo olvida y el primer toque vuelve a
preguntar.
Por qué: un rechazo persistido que se queda viejo apagaría el botón para siempre; uno en memoria, como mucho, repite el
aviso una vez tras relanzar. Alternativa descartada: `UserDefaults`, que además es una key ausente en todo el parque.

**D3 · ¿Qué rechazos se recuerdan?** → todo aviso de la hoja (los cuatro motivos de `Block`, del adelanto al toque, de la
comprobación tras firmar y del claim devuelto), **solo si al publicarlo queda una sesión viva**. «No pudimos comprobar tu
cuenta» no se recuerda: no es un rechazo.
Por qué: la sesión que abrió el intento se cierra antes de publicar el aviso, y entonces la tarjeta ya no promete ninguna
cuenta. La que queda es la que se comprobó, y es la que la tarjeta seguiría prometiendo. Alternativa descartada: atarlo a
`offersAnotherAccount`, que dice lo mismo hoy pero es otro hecho (y un `signOut` fallido deja la sesión viva).

**D4 · ¿Qué enseña la tarjeta?** → en lugar de la nota «Usarás tu cuenta de Yala actual…», una nota en color de aviso
con el motivo y la salida que ya daba la hoja; el botón «Activar la nube» queda apagado. Solo en la tarjeta de «Migrar»:
el adopt no pasa por esta comprobación.
Por qué: es la opción A de Jürgen. El texto reusa los caminos ya revisados de la hoja (desasociar en «Grupos», entrar con
la cuenta de los grupos) y no repite «No cambiamos nada», que habla del toque y no de la tarjeta.

**D5 · Copy** → cuatro claves nuevas `storage.migrate.refused*` en los 16 locales; es-AR con voseo, es-ES con pretérito
perfecto donde el verbo lo pide («ha vuelto a iCloud», «se ha empezado»), `es` copia byte a byte de `es-419`.

**D6 · Pruebas** → lógica pura (recordar / aplicar por `sub` y época) con unit; el cableado (controller, `CloudAuthService`,
vista) con source-scan como el resto de la puerta; y el XCUITest de la hoja comprueba que tras «Entendido» la tarjeta
ya no promete la cuenta, enseña el motivo y el botón está apagado. Mutantes del recuerdo y del apagado.
