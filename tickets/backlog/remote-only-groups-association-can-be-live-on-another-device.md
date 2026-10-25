---
id: remote-only-groups-association-can-be-live-on-another-device
status: backlog
priority: low
area: "modo-nube, grupos"
created: 2026-10-25
updated: 2026-10-25
source: "review adversarial del lote 12.2 (card 9mc6), inferido leyendo el código"
---

# «Desasociarla y seguir» suelta también la asociación que otro dispositivo sigue usando

## Qué pasa

La card 9mc6 añadió «Desasociarla y seguir» a la hoja «Ya usas otra cuenta para tus grupos» cuando la asociación solo
está en el iCloud-KV (`GroupsAccountAssociation.isRemoteOnly`). Desde este dispositivo no se distingue la asociación vieja
de otra instalación (el caso de la card) de la que un iPad del mismo Apple ID sigue usando: el servidor solo contesta a la
sesión de esa cuenta. La hoja lo dice («Si usas esa cuenta para tus grupos en otro dispositivo, allí seguirá asociada»).

Lo que queda sin resolver, inferido: tras soltarla y activar la nube con otra cuenta en el iPhone, el iPad conserva su
asociación local, ve el marcador de la migración y el Panel le propone activar la nube (card vbf9). El adopt no pasa por
la comprobación de identidad de «Migrar», así que podría entrar en la cuenta nueva con sus grupos en la vieja: dos cuentas
en un dispositivo, contra el ADR «Sesiones — dos ejes» §2.

## Qué haría falta

Medir con dos dispositivos si el adopt de ese iPad llega a entrar. Si entra, que el adopt mire la asociación local de
grupos como lo hace la puerta de «Migrar».
