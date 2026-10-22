---
name: mi-arreglo-empeora-un-ticket-hermano
description: Un motivo nuevo que viaja por un canal compartido puede empeorar el síntoma de OTRO ticket abierto — mídelo y anótalo allí, en vez de arreglarlo por motivo, que deja sin aviso al gesto legítimo.
metadata:
  type: feedback
---

Cuando cambias por qué motivo sale un aviso, recorre **quién más escucha ese canal**. Si un ticket abierto ya
describe un aviso colateral, tu cambio puede empeorarle el texto sin tocar una línea suya — y eso se mide y se
anota en su ticket, no se arregla de paso.

**Why:** el 2026-09-16, al separar el copy del bloqueo de cierre, el caso más común del desasociar (fallar sin
red) pasó de `.transient` a `.uploadRetryLater`. `ProfileView` escucha la misma `phase` del coordinador y
enciende su alert genérico para ese motivo, así que el colateral que ya salía pasó de decir **«Un momento
más»** —impreciso pero neutro— a **«No pudimos cerrar tu sesión»**, que nombra un gesto que la persona no
pidió. Es exactamente la dimensión que el ticket venía a arreglar, empeorada en otra población.

La salida tentadora era meter el motivo nuevo en el corte de `case .bridgeUnreadable, .detachBusy: break`.
**Está mal**: ese motivo lo produce también el cierre de sesión de verdad, y ahí el aviso SÍ tiene que salir —
cortarlo por motivo deja al gesto legítimo sin su aviso ([[mi-arreglo-deja-el-mecanismo-sin-productor]]). El
discriminador correcto es el GESTO, y se comprobó que el coordinador no lo publica: `phase` y
`waitingForPending` es todo lo observable.

**How to apply:** ante un cambio de enrutado por motivo, haz un grep de los OTROS consumidores del estado
compartido y pregúntate qué texto ven ahora. Si empeora y el arreglo de verdad es alcance de otro ticket:
(1) no lo arregles por motivo, (2) escribe en ESE ticket el antes/después con su coordenada, y (3) di
explícitamente qué salida descartaste y por qué — así quien lo coja no repite el intento. De noche, además,
es una decisión de producto («¿neutro y falso, o exacto pero de otro gesto?») y las decisiones se aparcan.
