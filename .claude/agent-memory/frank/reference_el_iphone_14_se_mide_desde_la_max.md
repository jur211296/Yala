---
name: el-iphone-14-se-mide-desde-la-max
description: Con el iPhone 14 por cable a la Max y su Device MCP reflejándolo, la Mini no puede conducirlo con device-mcp-cli; se mide por ssh desde la Max e instalar sí va desde la Mini
metadata:
  type: reference
---

Medido el 26-nov-2026 (lote 1 de eficiencia, sesión en la Mini): desde la Mini, `devicectl` llega al iPhone 14 por red
(lockState, `device install app`), pero `device-mcp-cli` lo da `blocked` («Another app … is mirroring»): lo refleja el
Device MCP de la Max. Lo que funcionó:

- **Compilar e instalar desde la Mini** (copia de perfilado, `devicectl device install app` por red).
- **Grabar y conducir por `ssh max`**: copiar los guiones a `~/Claude/entregas/<sesión>/scripts/` de la Max, ajustar la
  `S=` de `pasada.sh` (apunta al scratchpad de la sesión que los escribió) y correr ahí `xctrace` + `ciclos.sh`; también
  los `xctrace export` y los `.py` de análisis. Las trazas (100-200 MB) se quedan en la Max; al repo, solo los extractos.
- Antes, mira el transcript de la sesión de Yala de la Max por si usa el iPhone (`grep 00008110` en su jsonl).

Ver [[el-iphone-14-lo-ve-tambien-la-otra-maquina]], [[medir-release-en-el-iphone-con-semilla]].
