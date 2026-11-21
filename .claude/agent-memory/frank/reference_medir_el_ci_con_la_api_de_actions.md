---
name: medir-el-ci-con-la-api-de-actions
description: Cómo medir tiempos del CI de Yala (cola, prep, build, unit) desde la API de Actions, y qué no se puede leer (factura).
metadata:
  type: reference
---

Medido el 2026-11-21 (auditoría de tiempos del CI). Lo que funcionó:

- `gh api repos/jur211296/Yala/actions/workflows/286940687/runs?per_page=100&page=N` (QA) y, por run, `.../runs/<id>/jobs?filter=all`: cola = `started_at - created_at` del job; los pasos traen sus tiempos.
- `pull_requests` viene VACÍO en los runs de PR: la base se saca cruzando `head_branch` con `gh pr list --state all --json headRefName,baseRefName`.
- `filter=all` trae también los intentos anteriores de un run relanzado: al contar concurrencia de macOS salen picos falsos (9 en vez de 5).
- El log de un job lleva secuencias de escape: `gh api --allow-escape-sequences .../jobs/<id>/logs`. Swift Testing imprime «passed after N seconds» por caso: de ahí salen los tests lentos.
- La factura NO se lee: a `gh` le falta el permiso `user` (`gh auth refresh -s user`). No lo pedí; quedó como inferencia en el informe.

**Cómo aplicarlo:** antes de proponer cambios de CI, vuelve a medir con esto; la cifra de la auditoría (66 min p50 por PR) caduca con cada cambio de runner o de suite. [[el-silencio-de-la-telemetria-tambien-mide]]
