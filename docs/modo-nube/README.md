# Copias de trabajo para sesiones en otra máquina — NO son la SSOT

La SSOT de estos documentos es el vault de Obsidian (`$VAULT/Backlog/modo-nube/`, iCloud), que NO
sincroniza a otras máquinas vía git. Estas copias existen para que una sesión autónoma remota
(noche G1→G3, 2026-07-15) pueda LEER el diseño y ESCRIBIR su log de implementación.

Protocolo: la sesión remota lee `MODO-NUBE-GRUPOS-BACKEND-V1-DISENO.md` (diseño, solo-lectura) y
apendea su log en `groups-backend-v1.md` (sección Implementación). Al volver a la máquina principal,
el owner/Claude sincroniza los deltas de `groups-backend-v1.md` DE VUELTA al vault y estas copias
pueden refrescarse o borrarse. No editar el diseño aquí sin replicarlo al vault.
