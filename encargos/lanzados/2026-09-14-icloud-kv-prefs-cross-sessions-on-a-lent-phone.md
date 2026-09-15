# Implementar ticket: icloud-kv-prefs-cross-sessions-on-a-lent-phone

## Contexto
Cola autónoma nocturna reanudada (Jürgen cambió de cuenta Claude, 2026-09-14). Tras #166. Las 37 prefs del iCloud-KV cruzan dueño ↔ móvil prestado (solo-grupos); el guard de OwnerKeyValueStore se retiró con una premisa falsa.

## Decisión de Jürgen (2026-09-14)
**Cada cuenta, sus preferencias.** Dueño y prestado no se pisan. Reponer el guard en `OwnerKeyValueStore` (y solo ahí, como dice la cabecera) con predicado de eje de sesión: no aplicar ni escribir prefs del dueño desde una sesión que no es la suya.

MODO AUTÓNOMO HASTA TERMINAR: review adversarial, gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank (pregunta directa). Device-QA → `tickets/qa/` si aplica.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.

No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer ticket + OwnerKeyValueStore + PreferenceSyncService.applyRemoteValues.
2. Reponer guard; criterios del ticket; premisa de la cabecera al día.
3. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Dejar prefs cruzando. Wipe de prod.

## Como se sabe que esta bien
Prefs del dueño no se aplican ni se pisan desde sesión ajena; tests; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Medido contra el árbol `f548ac94`. Revisadas tras la review adversarial de cuatro lentes: D1, D2 y D4
> cambiaron por lo que cazó. **Son 36 preferencias, no 37**: el ticket traía la cifra de antes del 13-sep.

**D1 · ¿Qué sesión «no es la dueña» del iCloud-KV?** → la que AFIRMA no tener sesión privada (marca del eje 1
en `false`), o la que, sin esa marca todavía, EMPEZÓ un alta solo-grupos (marca del neutro solo-grupos armada).
Abre con el eje en `true` y sin ninguna de las dos marcas.
Por qué: (1) sin marcas tiene que abrir — el arranque neutro tras «Cerrar sesión» aplica el `userName` que
`isFullyPrefilled` exige para que «Restaurar» vaya directo a la app, y el alta personal escribe sus prefs y
`signalOnboardingCompleted` ANTES de encender el eje; (2) la puerta del organizador arma el neutro y escribe
nombre y periodo ANTES de apagar el eje; (3) con el eje en `false` cierra aunque el neutro ya no esté:
«Activar Yala completo» lo levanta al relanzar y «volver» desde Restaurar deja la activación pendiente sin
límite (`CancelEffect.keepPending`) — la primera versión abría ahí y la review lo cazó; (4) con el eje en
`true` abre aunque el neutro se quede pegado.
Descartadas: `!hasPrivateSession` sola (llega tarde a la puerta del organizador); `!confirmedPrivateSession`
sola (cierra el arranque neutro y el alta personal: rompe restaurar para toda la población de producción);
«neutro armado y sin eje afirmado», que fue la primera versión (reabre el bug en la activación cancelada); el
predicado del vaciado `confirmed && .icloud` (cierra la nube completa, que tiene que escribir el faro).
Coste aceptado, con ticket: lo que la activación escribe con la puerta cerrada —las prefs de su onboarding y el
centinela del interruptor maestro— no sube cuando nace la sesión privada.

**D2 · ¿Qué bloquea la puerta cerrada?** → escrituras, borrados y `synchronize()` no llegan; las lecturas
contestan «no hay nada», **salvo las dos señales del Apple ID** (`lastWipeTimestamp`,
`lastOnboardingTimestamp`), que se leen siempre.
Por qué: «no aplicar» es enmascarar la lectura que alimenta `applyRemoteValues`, y la misma frontera cubre el
faro, el espejo del interruptor maestro y la cuenta de grupos asociada (el correo del dueño en claro). Las
señales son del canal y no del dueño: todo dispositivo tiene que verlas para darlas por procesadas, y
obedecerlas ya lo decide el eje. La primera versión también las ocultaba, y dos lentes midieron el daño: el
vaciado de otro dispositivo quedaba pendiente, y la sesión privada que nace de la activación lo obedecía al
abrirse la puerta, borrándose recién creada.
Descartada: solo escrituras, como el guard viejo — deja vivo el «me llega con el idioma del dueño».

**D3 · ¿Se cierra aquí la herencia del arranque neutro tras «Cerrar sesión»?** → no; ticket nuevo y pregunta
a Frank.
Por qué: en ese arranque nadie ha elegido todavía y la puerta no puede saber quién va a entrar; cerrarlo por
ausencia es D1-(1). Descartada: resetear las 36 en las dos altas solo-grupos — sale de «solo ahí» y es una
decisión de producto.

**D4 · Lectores crudos fuera de la fachada.** → `PanelPreferencesMigration` pasa por la puerta; `ContentView`
y `AppPreferences` se quedan como lectores crudos declarados, con sus lecturas FIJADAS en el escáner.
Por qué: la migración vería el Panel del dueño con la puerta cerrada y se saltaría la siembra sin que nadie
aplicara nada. Los otros dos leen lo que la puerta también deja pasar —las dos señales— o se suscriben al
emisor crudo, así que por la puerta harían lo mismo; moverlos tocaba `ContentView`, que casa con 29 áreas del
índice de cobertura y habría lanzado unas 20 suites de XCUITest sin cambiar un comportamiento. La review midió
que eximirlos por FICHERO dejaba pasar una escritura cruda nueva en ellos: por eso el escáner fija el conteo y
las sentencias, no el nombre del fichero.

**D5 · La nube completa (celda E) en un móvil prestado.** → fuera de esta puerta; ticket.
Por qué: su eje vale `true` y el faro y el cutover tienen que escribir desde ella en el teléfono propio. Sus 36
prefs van al backend salvo el idioma, que `LanguageManager` escribe directo al iCloud-KV — y la elección nube
está al 100 en producción (`gateway/wrangler.toml`), así que el camino existe.

**D6 · Cómo se verifica.** → `OwnerKeyValueGateTests` (tabla de 6 celdas, las mismas 6 leídas de un teléfono,
fachada con espía y decisión inyectada, y la lectura por defecto de `.standard`) · `OwnerKeyValueWiringTests`
(nadie más nombra el store crudo, lectores declarados fijados, usuarios conocidos, `shared` vivo, cuerpo entero
de `readRemoteIKV`, señales legibles = las del servicio, emisor crudo en los dos suscriptores, orden del
`-uitest-reset`) · censos de `confirmedPrivateSession(` (8) y `hasPrivateSession(` (18) · el scope
`.ownerKeyValueGateOpen` con su pin en `SharedStateIsolationTests`. Mutantes: uno por rama de la tabla, por
lectura, por escritura, por la excepción de las señales, y por cada eslabón del cableado.

**D7 · Device-QA.** → sí, el ticket va a `tickets/qa/`: dos dispositivos del mismo Apple ID, uno privado y otro
prestado en solo-grupos. El simulador no da dos dispositivos sobre el mismo iCloud-KV.

**D8 · Documentación.** → cabecera de `OwnerKeyValueStore` reescrita · los dos comentarios de `L10n` · nota
corregida en `m1-prose-outlives-its-code-in-comments` · una frase en `.claude/rules/swiftdata-cloudkit.md` ·
`qa/coverage-index.json`. Sin ADR: la decisión de producto es de Jürgen y vive en el ticket; lo técnico, en la
cabecera y la regla.
