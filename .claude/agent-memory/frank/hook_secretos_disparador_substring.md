---
name: hook-secretos-disparador-substring
description: El hook pre_push_secretos está DESACTIVADO desde el 2026-09-01 (ADR-009); si se reactiva, vuelve su trampa — bloquea cualquier comando que diga "git" y "push", aunque no empuje nada
metadata:
  type: project
---

**Estado al 2026-09-01, medido: el hook NO está registrado en ningún `settings.json`** (ni el
global ni el del repo). Se retiró del push ese día por el ADR-009 de casa, porque daba siete
falsos positivos al día. El script `~/.claude/hooks/pre_push_secretos.py` sigue en disco y
reactivarlo es una línea; su allowlist, `~/.claude/hooks/secretos-permitidos.txt`, también sigue
ahí. ⇒ **hoy nada escanea antes de un push.** No cuentes con él como red, y no prometas que
«el hook lo cazaría».

**La trampa, para cuando vuelva.** El hook decide si actuar con
`if "git" not in comando or "push" not in comando: return 0` — un substring sobre el texto
entero del comando. **Cualquier** comando bash que mencione ambas palabras se bloquea, aunque no
empuje nada: un `cat` cuyo heredoc cite `qa/cloud/push-e2e-test.sh` y la palabra «gitignore» ya
basta.

**Why:** me pasó el 2026-08-31 escribiendo la propia allowlist del hook — el comando que
registraba las excepciones fue bloqueado por el hook al que pertenecían. Es parte de por qué
Jürgen decía que «anula casi todos los push», y de por qué acabó retirado.

**How to apply:** si algún día un comando tuyo se bloquea sin ser un push, mira si el texto
contiene «git» y «push» en cualquier posición y reformúlalo (escribe el cuerpo a un fichero con
Write y muévelo con un `cat` que no las mencione). No lo desactives ni lo edites para pasar: esa
decisión es de Jürgen y ya la tomó una vez, por ADR.

Lo estructural —que escanea todo lo trackeado en vez del rango a empujar— está en
[[push-solo-lo-de-la-sesion]], y fue parte del argumento para retirarlo.

**Caduca si vuelve a registrarse.** Antes de dar por buena la primera frase, compruébala:
`grep -n "secretos\|pre_push" ~/.claude/settings.json .claude/settings*.json`.
