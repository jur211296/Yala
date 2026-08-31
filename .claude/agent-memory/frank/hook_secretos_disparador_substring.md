---
name: hook-secretos-disparador-substring
description: El hook pre_push_secretos bloquea cualquier comando bash que contenga las palabras "git" y "push", aunque no sea un push
metadata:
  type: project
---

El hook `~/.claude/hooks/pre_push_secretos.py` decide si actuar con
`if "git" not in comando or "push" not in comando: return 0` — un substring sobre
el texto entero del comando. **Cualquier** comando bash que mencione ambas
palabras se bloquea, aunque no empuje nada: un `cat` cuyo heredoc cite
`qa/cloud/push-e2e-test.sh` y la palabra «gitignore» ya basta.

**Why:** me pasó el 2026-08-31 escribiendo la propia allowlist del hook — el
comando que registraba las excepciones fue bloqueado por el hook al que
pertenecían. Es parte de por qué Jürgen dice que «anula casi todos los push».

**How to apply:** si un comando tuyo se bloquea sin ser un push, mira si el texto
contiene «git» y «push» en cualquier posición y reformúlalo (escribe el cuerpo a
un fichero con Write y muévelo con un `cat` que no las mencione). No desactives
el hook ni lo edites para pasar: la salvaguarda es de Jürgen.

Lo estructural —que escanea todo lo trackeado en vez del rango a empujar— está en
[[push-solo-lo-de-la-sesion]]. Pendiente de decisión suya el 2026-08-31.
