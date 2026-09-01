---
name: push-bloqueado-hasta-rotar-staging
description: Ningún push mío desde Yala pasa el hook de secretos hasta que Jürgen rote las credenciales de staging; la allowlist está cerrada por decisión
metadata:
  type: project
---

**Hasta que Jürgen rote las credenciales de test de staging, ningún `push` mío
desde `~/Yala` pasa** — da igual qué toque mi rama. El hook marca cuatro ficheros:

```
YalaTests/CloudSync/{CloudAccountClaim,CloudSync,MigrationCutover,PrefsSync}E2EStagingTests.swift
```

**Why:** el hook escanea *todo lo trackeado*, no el rango a empujar (ver
[[hook-secretos-disparador-substring]]), y esos ficheros llevan en `2.1` desde
antes. Son credenciales reales en un repo público — ticket
`staging-test-credentials-in-public-repo` — y **ya se decidió NO exentarlas en la
allowlist**, porque esa lista significa «he mirado esto y no es un secreto». Así
que el hook acierta y mi push es daño colateral: me bloqueó el 2026-08-31 un
commit que *quitaba* un webhook muerto.

**How to apply:** si vas a entregar algo que necesita subir, cuenta con esto
**antes** de prometer el PR, y plantéaselo a Jürgen de entrada con las dos
salidas: (1) rotar —el arreglo de verdad, porque sacar las claves del código sin
rotar no cambia nada con el histórico público—, o (2) que suba él la rama desde
su terminal, que el hook es de Claude Code y no un hook nativo de git. **Nunca**
edites el hook ni la allowlist para pasar: la salvaguarda es suya
([[push-solo-lo-de-la-sesion]]).

**Caduca cuando se rote.** Si ves el ticket cerrado o el hook ya no marca esos
cuatro, borra esta nota en vez de arrastrarla.
