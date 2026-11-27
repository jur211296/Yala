---
id: 2026-11-27-tendencias-enlace-al-plan-queda-bajo-la-barra
status: done
priority: medium
area: "estadísticas, proyección, pruebas de interfaz"
created: 2026-11-27
updated: 2026-11-27
source: "gate del lote 7 de eficiencia (27-nov-2026, Max, simulador iPhone 17 Pro, iOS 27.2)"
---

# En Tendencias, «Afinar con un plan de flujo de caja» queda bajo la barra de pestañas y su prueba cae

## Qué se midió

- `YalaUITests/Flows/ProjectedFlowUITests.swift:142`, `test_trends_projectionWithoutAPlan_linksToSettingUpTheCashFlowPlan`:
  «Sin plan, falta «Afinar con un plan de flujo de caja» bajo la cifra.» Los otros tres casos de la clase pasan.
- Cae igual en `origin/2.3` en `a5e93673f` (sin el lote 7) y con el lote 7: 3 de 3 corridas, una de ellas a solas. No lo
  trae el lote 7: ese lote no toca Estadísticas ni `ProjectedFlowViews.swift`.
- El último fotograma del vídeo del fallo: «Ver proyectado» encendido, la cifra «Al 31 de diciembre tendrías…» visible justo
  encima de la barra de pestañas, y el enlace (`trend_projected_link_setup`, `Yala/App/Views/Shared/ProjectedFlowViews.swift:99`)
  debajo de la barra. El `scrollTo` del test no lo sube.

## Hipótesis (sin medir)

La fila «Nuevo registro · Voz · Foto · Yala IA» encima de Tendencias empujó la tarjeta hacia abajo y el enlace quedó bajo la
barra; o el `scrollTo` del test deja de desplazar cuando el elemento ya «existe» en el árbol (regla de `isHittable` en
`.claude/rules/testing.md`). Si es lo segundo, es el test; si la persona tampoco puede desplazar hasta el enlace, es de la app.

## Plan

1. Abrir Tendencias con «Ver proyectado» en el simulador y comprobar a mano si el enlace se alcanza desplazando.
2. Si se alcanza: arreglar el `scrollTo` del test (arrastres cortos hasta la franja central, molde `openObservations`).
3. Si no: dar al contenido el margen inferior de la barra.

## Resuelto (27-nov-2026, lote «Arreglos pre-build 12»)

- **Medido en el simulador** (Mini, iPhone 17 Pro, iOS 27.2, semilla `realista`, «Este año»): con «Ver proyectado»
  encendido, el enlace queda en y=814, bajo la barra de pestañas (y=795). Desplazando a mano sube a y=635 y se toca.
  **La app no tenía nada que arreglar: era la prueba.**
- **Causa (inferida, no aislada con un mutante):** el arrastre de `scrollTo` empieza en el 70 % del alto, encima de la
  gráfica de la tarjeta, que se queda el gesto; la página no se desplaza y a los 14 arrastres la prueba se rinde.
- **Arreglo:** `ProjectedFlowUITests.bringToCenter`, arrastres cortos y lentos por el margen derecho (fuera de las
  tarjetas) hasta dejar el enlace en la franja central, molde `openObservations`. La prueba toca el enlace y comprueba
  que abre el armado del plan. Verde a la primera (26 s).
