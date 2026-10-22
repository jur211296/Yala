---
name: el-flaky-de-entorno-se-mide-lanzando-a-mano
description: Un rojo intermitente que un ticket da por «es el entorno» se clasifica con N arranques a mano (simctl launch --console-pty) e instrumentación, no con más corridas de XCUITest
metadata:
  type: feedback
---

Cuando mi test nuevo cae 1 de N y la firma casa con un flaky viejo cuyo ticket concluye «es el entorno», no lo
acepto ni subo esperas: lanzo la app a mano N≥10 veces con `simctl launch --console-pty` (con tiempos por línea
vía perl), cuento atascos, e instrumento con `print` el camino (matriz → router → onChange → drenaje).

**Why:** el 2026-10-08 el ticket `queued-offer-after-dismiss-flakes-on-a-cold-simulator` llevaba tres semanas y
seis apariciones atribuido a memoria/simulador frío. Cuatro arranques instrumentados lo clasificaron: la matriz
quedaba libre y `markReady` bumpeaba, pero `onChange(revision)` no llegaba — bug de producto. Y la receta SIN mi
seam (1 de 16) descartó que fuera artefacto del test. Lanzar a mano cuesta 25 s por muestra; un XCUITest, 60-70.

**How to apply:** antes de cerrar un test nuevo con un rojo intermitente, (1) busca el ticket del flaky viejo,
(2) muestrea a mano con y sin el seam, (3) instrumenta la frontera donde se pierde el efecto. Ojo con el grep del
criterio «ok»: un `drained.*rial` casó con «nothing drained; peek=trialOffer» y me dio un falso 14/14. Relacionado:
[[instrumentar-gana-a-razonar]], [[bisect-de-un-flaky-miente]].
