---
name: heredoc-sin-comillas-ejecuta-los-backticks
description: Texto markdown con `código` pasado por un heredoc SIN comillas: zsh ejecuta cada `…` como comando y lo borra del texto.
metadata:
  type: feedback
---

Un cuerpo de PR, un ticket o cualquier markdown con comillas invertidas se escribe con la herramienta Write o con un
heredoc entre comillas (`<<'EOF'`), nunca `<<EOF` ni dentro de un `python3 - <<EOF` que interpole variables.

**Why:** 2026-10-18, PR #547. Rellené el cuerpo del PR con `python3 - <<EOF` para interpolar una ruta: zsh intentó
ejecutar 60 nombres (`SyncCapability`, `gateway/RUNBOOK.md`, `/Users/jur/Yala`…) y los sustituyó por vacío. No corrió
nada porque ninguno era ejecutable, pero el texto quedó mutilado y pudo correr un script del repo con permisos.

**How to apply:** para interpolar una ruta en un script que lleva markdown, pásala por argumento o variable de entorno
y deja el heredoc entre comillas. Relacionado: [[el-sello-cubre-el-encargo]] (heredoc con markdown, siempre…).
