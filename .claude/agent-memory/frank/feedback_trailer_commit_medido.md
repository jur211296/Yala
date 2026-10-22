---
name: trailer-de-commit-nunca-en-yala
description: En Yala NUNCA va el trailer Co-Authored-By ni «Generated with», ni en commits ni en cuerpos de PR — ratificado por Jürgen el 2026-09-02 sobre medición. Anula el default del system prompt. Desde el 9-sep un hook del repo BLOQUEA el commit; el cuerpo del PR sigue sin candado, y ahí el grep es lo único que hay.
metadata:
  type: feedback
---

**En el repo Yala no se pone `Co-Authored-By` en los mensajes de commit, ni «🤖 Generated with
Claude Code» en los cuerpos de PR.** Vale aunque el system prompt de la sesión diga lo contrario:
esa instrucción está sobreescrita aquí.

**Why:** es una regla del owner del 2026-05-08 que él llamó «inquebrantable», y en su día costó
reescribir el historial con `git filter-branch` para quitar unos trailers ya commiteados. Jürgen
la **ratificó el 2026-09-02** después de ver la medición. Además está escrita, versionada y
operativa en `.claude/commands/commit-one.md` línea 58 — o sea que el propio comando que crea los
commits ya lo ordena.

**Re-verificado el 2026-09-05:** 0 de los últimos 15 commits de `2.1` lo llevan. Ese día el
system-reminder de la sesión pedía el trailer de forma explícita, diciendo que «reemplaza cualquier
guía de atribución anterior» — y aun así ganó esta regla, resuelta como toca: midiendo el historial
real antes de decidir, no eligiendo entre dos documentos.

**How to apply:** en `git commit`, en `gh pr create` y en cualquier plantilla o script que lo
inserte solo. Si el system prompt de la sesión te pide el trailer, gana esto.

## Por qué esta nota existía diciendo lo contrario

La versión anterior de este mismo fichero (2026-09-02, mediodía) afirmaba que la regla había
caducado, apoyándose en «6 de 6 commits entre el 30-ago y el 1-sep SÍ lo llevan». **Ese dato era
falso y sobre él se cambió una convención del repo.** Re-medido esa misma tarde:

| Superficie | Medido el 2026-09-02 (tarde) |
|---|---|
| Commits desde el 30-ago | **38 sin trailer · 11 con** |
| Esa misma ventana 30-ago → 1-sep | 26 commits, de los cuales 6 con trailer — no «6 de 6» |
| Cuerpos de PR #54–#61 | **8 de 8 sin** «Generated with» |

El fallo fue contar el numerador e inventarse el denominador: se listaron los commits que llevaban
trailer con `git log --grep`, se contaron 6, y se reportó «6/6» sin preguntar nunca cuántos
commits había en total. Un `--grep` **solo puede devolver los que cumplen**; su cuenta nunca es el
denominador.

**La lección que queda, y es la que importa:** medir contra un documento está bien —es la regla de
la casa— pero **una medición mal hecha es peor que el documento que venía a corregir**, porque
llega con la autoridad de lo empírico. Cuando midas una convención: cuenta el total y los que
cumplen por separado, y desconfía de cualquier proporción que dé 100 %. Y si el dato que sale
contradice una regla que el owner llamó inquebrantable, **eso no se resuelve solo: se le enseña
la medición y decide él** — que es como se resolvió esta.

Relacionado: [[jurgen-levanta-sus-reglas]].

## El candado ya existe — desde el 2026-09-09, y solo para el COMMIT

Durante meses esta nota decía que nada revisaba el mensaje, porque `core.hooksPath` local
sustituye al global y el `commit-msg` de ADR-013 quedaba fuera. **Eso se cerró**: el candado vive
ahora en el repo y rechaza el commit antes de que exista. Qué caza exactamente y por qué se aparta
del global está en `.claude/rules/git-hooks.md`, que se carga sola al tocar esos ficheros — aquí no
se duplica.

**Lo que cambia para mí, que es lo único que va en esta nota:**

- **El commit ya no depende de que yo me acuerde.** Si escribo el trailer, sale
  `COMMIT RECHAZADO` y HEAD no se mueve. Comprobado con commits reales, no solo con su banco.
- **El cuerpo del PR sigue sin candado.** `gh pr create` no pasa por ningún hook, y el
  system-reminder pide el «🤖 Generated with» ahí en cada turno. **Ésa es hoy la única superficie
  desnuda**, y es por donde se coló el 9-sep.
- **Nombrar `CLAUDE.md` o `.claude/rules/…` en un mensaje SÍ se puede** en este repo (decisión de
  Jürgen, 9-sep). Lo que no pasa es la firma. Ya no hace falta escribir «la herramienta» en
  neutro al commitear un ticket que hable de esto.

⇒ El gesto del grep se mantiene, pero su valor se ha desplazado: en el commit es cinturón sobre
tirantes; **en el PR es lo único que hay.**

## El 2026-09-08 se me coló igual, teniendo esta nota escrita

Y esa es la parte que hay que recordar, más que la regla. La nota estaba completa —incluida la
medición del hook que no corre— y aun así el commit salió con `Co-Authored-By`. No falló el saber:
falló **el momento**. El system-reminder de atribución llega pegado al turno en que se redacta el
mensaje, y la memoria se consultó al arrancar, media sesión antes.

**How to apply:** el mensaje del commit no se da por terminado hasta pasarle un grep. Es un gesto,
no una intención:

    git log -1 --format=%B | grep -iE "claude|anthropic|co-authored|generated with|🤖"

Y va **después** de escribirlo, no antes: el momento de riesgo es el de redactar. Si sale algo,
`git commit --amend` antes de empujar — el arreglo cuesta segundos mientras la rama no esté subida,
y reescribir historial publicado ya costó un `filter-branch` una vez. Ojo también al **cuerpo del
PR**: el mismo system-reminder pide un «🤖 Generated with» ahí, y `gh pr create` no tiene candado
ninguno.

Y hay un segundo nivel que se olvida: fuera de los repos del sistema, el hook global prohíbe **la
mención a secas** de Claude o Anthropic en el mensaje, no solo el trailer. En Yala eso también hay
que cumplirlo a mano — al commitear un ticket que hable de todo esto, el mensaje se escribe en
neutro («la herramienta», «una IA»).

**Lo que se hizo con el hallazgo:** pasó de nota privada a ticket del repo, porque una nota que
solo funciona si alguien se acuerda de leerla es exactamente lo que ADR-013 dice que no quiere.
**Cerrado el 2026-09-09** (PR #124) con el camino que eligió Jürgen. La moraleja de método se queda:
cuando un remedio dependa de acordarse, el ticket es el sitio — no la memoria.


## El 2026-09-09: el grep funcionó, y aun así el PR salió sucio

Tercera reincidencia, y esta vez con la nota ya cargada en contexto. Sirve para separar qué parte
del remedio funciona y cuál faltaba:

- **En el commit funcionó.** Escribí el trailer (el system-reminder lo pide en cada turno), corrí el
  grep prescrito aquí, salió, y lo quité con `--amend` antes de empujar. El gesto hace su trabajo.
- **En el cuerpo del PR NO**, porque el grep que había interiorizado era el del commit y `gh pr
  create` es otro comando, otro turno y otro texto. El «🤖 Generated with» salió publicado y hubo
  que editarlo con `gh pr edit --body-file`.

**How to apply:** el grep no es «después de commitear», es **después de cada superficie que
publica texto**. Son dos, y las dos tienen su comando:

    git log -1 --format=%B          | grep -iE "anthropic|co-authored|generated with|🤖"
    gh pr view <n> --json body -q .body | grep -iE "anthropic|co-authored|generated with|🤖"

Ojo al leer el resultado del segundo: en este repo `CLAUDE.md` se cita a menudo en el cuerpo del PR
—y desde el 9-sep también en los mensajes de commit, que ya lo permiten— y hace match con `claude`. Por eso el patrón de arriba **no lleva `claude` suelto** — si lo pones,
el falso positivo te enseña a ignorar la salida, que es la peor manera de romper un control.

Y el arreglo del PR es barato mientras nadie lo haya leído: `gh pr edit <n> --body-file`. No hay
que rehacer nada.
