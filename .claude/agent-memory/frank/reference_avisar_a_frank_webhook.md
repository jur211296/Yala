---
name: avisar-a-frank-webhook
description: Cómo se avisa al Grok dueño — normalmente NO hay que hacer nada: el hook avisa solo. A mano, `<motivo>` a secas no envía, el POST propio da 401, `--dry-run` NO previsualiza el `--texto` y el resumen se recorta a 600
metadata:
  type: reference
---

**El aviso a Frank se manda con `python3 ~/.claude/hooks/avisar_grok.py <motivo>`, no con un POST
propio.**

**Why:** el 2026-09-05 compuse el POST a mano leyendo `~/.claude/grok-webhooks.json` y me dio **401**.
El fichero tiene dos campos que parecen una cosa y son otra: `cabecera` vale `Authorization` (no
`X-Sender-Key`) y `prefijo` vale `Bearer` — es el prefijo del **token**, no del mensaje. El script ya
sabe todo eso, elige el destino por el cwd y escribe el registro.

**How to apply:**

- `--estado` → qué destinos hay, la sesión tmux de esta sesión y los últimos envíos.
- `--dry-run <motivo>` → compone y dice si pasaría la puerta, sin enviar.
- **`--avisar <motivo> --texto "…"` SÍ envía, y es el modo del cierre.** Lo encontré el 2026-09-05
  leyendo el `main()` después de que esta ficha me dejara creyendo que no había forma manual. Su
  docstring lo explica: el texto del cierre **no lo puede componer el hook** («qué se hizo» solo lo
  sabe quien trabajó), así que entra por `--texto`, pasa por `sanear` (quita rutas, recorta) y sale.
  Sin `--texto` se niega: «un aviso de cierre sin resumen no es una noticia». Medido: `ENVIADO
  destino=frank motivo=cierre-resumen HTTP 200`.
- **El PR que sale en el aviso de cierre puede ser el de OTRA sesión, y `--rama` no lo arregla.**
  Medido el 2026-09-09: el aviso salió con `#109` cuando los míos eran `#111` y `#112`. La anotación
  del hook estaba bien —`ultimas/Yala__encargo-<slug>.txt` apuntaba a mi sesión, con los dos PR
  dentro—; lo que falla es la resolución, que usa `ultimas/Yala__2.1.txt` (la rama del árbol
  principal, desde donde se avisa) y sirve el PR de quien cerró antes. `--dry-run` da lo mismo con
  el flag y sin él, así que el flag no llega ahí. **Comprueba el número antes de dar el cierre por
  bueno**: `cat ~/.claude/cache/avisos-grok/ultimas/<repo>__<rama-con-guiones>.txt` y compara contra
  `sesiones/<id>.json`. Ticket: `el-aviso-de-cierre-cita-el-pr-de-otra-sesion` (medium).
- **`<motivo>` a secas NO envía** — corregido el 2026-09-05, midiendo el log antes y después:
  `main()` solo desvía a `modo_manual` con `--dry-run` o `--probar`; sin flag cae al **modo hook**,
  que espera el JSON del evento por stdin, revienta al no encontrarlo y **sale 0 sin decir nada**.
  Esta línea decía «→ envía», que es el peor error posible aquí: crees que avisaste y no avisaste.
  Es la familia del «cero casos con exit 0» de `.claude/rules/testing.md`.
- **Solo TRES motivos despiertan a nadie (ADR-021, medido el 2026-09-08): `cierre-resumen`,
  `espera-permiso`, `espera-pregunta`.** Los demás —`artefacto-pr` incluido— los rechaza en la cara:
  «no despierta a nadie: se anota y viaja dentro del próximo aviso». ⇒ cuando un encargo pida «avisa
  al abrir el PR», eso YA está cubierto: se cuenta dentro del cierre. No lo intentes por separado.
- Motivos que el script acepta pero no envían solos: `espera-input`, `fallo-build`, `fallo-tests`,
  `artefacto-captura`, `artefacto-pr`, `artefacto-preview`, `artefacto-publicado`.
- Comprueba `~/.claude/cache/avisos-grok/envios.log`: la línea dice `HTTP 200` o no lo dice.

**El hook avisa solo, y de más cosas de las que parecía: normalmente no hay nada que hacer.** Además
del `fallo-tests` de aquella noche, el 2026-09-05 mandó el **`artefacto-pr` él solo, 48 segundos
después de `gh pr create`**, sin que yo tocara nada. **Ojo con esos 48 s: el hook corre al TERMINAR
el turno**, así que en una sesión autónoma larga puede no haber disparado todavía y el log estar
mudo sin que nada vaya mal (2026-09-08). Y desde ADR-021 ese aviso ya no despierta igualmente. ⇒
cuando un encargo pida «avisa al webhook al dejar el PR listo», la tarea real es **comprobar el
log**, no enviar:

    tail -5 ~/.claude/cache/avisos-grok/envios.log

**Y el 401 tiene un segundo modo de fallo, distinto del de la cabecera.** Los destinos cuelgan de
`destinos.<agente>`, no del top level, así que una heurística que busque «la primera url del fichero»
apunta a **otro agente** (me fue a la de Dan); y la clave se llama `sender_key`, que no casa con
`key`/`token`, así que el POST sale sin `Authorization` encima. El fichero trae sus propias
instrucciones en las claves `_1_`…`_6_`: leerlas cuesta menos que adivinar el esquema.

**El canal tiene vuelta:** la sesión corre en tmux con nombre `repo--slug`, así que Frank puede
contestar con `tmux send-keys`. Eso hace que valga la pena que el mensaje diga qué se necesita, no
solo qué pasó. Relacionado: [[push-solo-lo-de-la-sesion]].

## Confirmado el 2026-09-05 por segunda vez, y con el coste: dupliqué el aviso

En el PR #66 mandé `--avisar artefacto-pr --texto "..."` a mano porque el encargo lo pedía. El log
lo dice todo: **06:57:59 el hook, 06:59:06 el mío**. Dos avisos del mismo PR a Frank con 67 s de
diferencia. El antirrebote de 10 min no los para porque el motivo se compone distinto según el
camino. ⇒ ante un encargo que pida avisar de un PR, `tail -5 envios.log` PRIMERO; si ya está, no
mandes nada y di que el hook lo cubrió.

## `--avisar` sí envía, y su trampa NO es la del `<motivo>` a secas

`--avisar <motivo> --texto "..."` entra por `modo_avisar` y **sí manda** (`ENVIADO … HTTP 200`);
lo que no envía es `<motivo>` a secas, que es lo que dice arriba. Los dos caminos existen y se
parecen; el que compone un texto propio es el de `--avisar`.

## Y la trampa que costó un descarte: la palabra «prueba» dentro del texto

`RX_PRUEBA = re.compile(r"\bPRUEBA\b", re.IGNORECASE)` corre sobre el **cuerpo entero**, no sobre
una marca. Mi aviso decía «conservamos la prueba de su consentimiento» y la puerta lo descartó
como si fuera un aviso de test: `DESCARTADO … — prueba`, sin enviar nada.

**Why:** es la familia exacta de [[hook-secretos-disparador-substring]] — un disparador que casa
por contenido y no por intención. Y aquí el fallo es silencioso en la dirección cara: el script
imprime el descarte, pero si no lees esa línea crees que avisaste.

**How to apply:** evita la palabra «prueba» (y «PRUEBA», «pruebas») en el cuerpo de un aviso —
usa «registro», «evidencia», «comprobación», «tests». Y **lee siempre la última línea del script**:
`ENVIADO … HTTP 200` o `DESCARTADO … — <razón>` son lo único que distingue haber avisado de creerlo.

**Y el hook manda MÁS de lo que decía esta ficha.** El 2026-09-05, en una sola sesión, mandó solo
`artefacto-pr` (48 s tras `gh pr create`) **y `artefacto-pr-mergeado`** (tras `gh pr merge`). Lo
único que quedó por enviar fue el `cierre-resumen`, que es justo el que necesita texto humano. ⇒ la
regla práctica: **de los artefactos se encarga el hook; el cierre lo mandas tú con `--avisar`.**
Y en los dos casos, lo que se comprueba es el log, no la intención.



## Y `--dry-run` NO sirve para previsualizar un aviso con `--texto` (2026-09-08)

**El dry-run compone un cuerpo DISTINTO del que se envía.** Leído en el fuente, no inferido:
`modo_manual` (el de `--dry-run`) llama `componer(destino, motivo, d, prueba=prueba)` — **sin
`resumen=`**; `modo_avisar` llama `componer(..., resumen=texto_libre, fallos="")`. Así que el
`--texto` que le pases al dry-run **no aparece por ningún lado** y el cuerpo que te enseña no es el
que va a salir.

**Why:** el 2026-09-08 pasé dos rondas de dry-run creyendo que mi resumen no entraba por el motivo
equivocado —probé `espera-permiso`, luego `cierre-resumen`— cuando el problema era el modo. Y el
tell estaba delante: metí un marcador con la palabra **PRUEBA** dentro del texto y la puerta dijo
**«pasa»**. Si el texto hubiera estado en el cuerpo, `RX_PRUEBA` lo habría descartado. Un filtro que
no reacciona a lo que debería descartar está mirando otra cosa — es la familia del control positivo
de `.claude/rules/testing.md`.

**How to apply:** para saber si tu texto sale y cómo, **lee `modo_avisar`**, o mándalo y comprueba el
log. El dry-run solo vale para el encabezado, el destino y la URL. Y no te fíes de un «pasa» de la
puerta sobre un cuerpo que no contiene tu texto.

## `TOPE_RESUMEN = 600`, y recorta a mitad de palabra sin avisar

`sanear(texto, TOPE_RESUMEN, repo)` corta a `tope-1` y pega `…`. **No hay aviso**: el script imprime
`ENVIADO … HTTP 200` igual, y tú te quedas creyendo que llegó entero. El 2026-09-08 mandé 637
caracteres y a Frank le llegó «El ti…» donde decía que el ticket quedaba en `blocked`.

**How to apply:** cuenta los caracteres **antes** de la llamada que envía, no en la misma línea —
ahí ya es tarde y duplicar el aviso cuesta más que la frase perdida (ver el duplicado del 5-sep
arriba). Y pon lo accionable al principio: **lo que se pierde es siempre el final**.

Dos cosas más que `sanear` hace y conviene saber: en un repo de `REPOS_SIN_TEXTO_LIBRE` devuelve
vacío y el aviso se niega entero; y su regex de rutas es **sensible a mayúsculas**
(`Users|Claude|Projects|Documents`), así que una URL con `claude.ai` en minúscula pasa intacta.

**La palabra «prueba» muerde cuando es LEGÍTIMA, y por eso saber que existe el filtro no basta.**
Medido el 2026-09-10, con esta misma ficha ya escrita: el aviso de cierre salió `DESCARTADO … — prueba`
porque el resumen decía «volver a crear los grupos **de prueba**». No era un aviso de test: era la frase
natural para nombrar los datos de device-QA. El filtro mira la palabra, no la intención.

**How to apply:** el riesgo no está en los avisos de test —ésos ya no los mandas— sino en el vocabulario
de trabajo: «datos de prueba», «cuenta de prueba», «grupos de prueba», «entorno de pruebas». **Repasa el
`--texto` buscando esa raíz antes de enviar** y sustitúyela («los grupos que usas para el device-QA»). Y
lee siempre la línea del log: el descarte no sale por stderr con estruendo, sale como una línea más.
