---
id: 2026-11-25-guias-y-avisos-senalan-donde-deben
status: done
priority: high
area: "primeros-pasos, guías de lugar, cierre de sesión"
created: 2026-11-25
updated: 2026-11-25
source: "Observación en vivo del iPhone 14 del 25-nov (docs/qa/observacion-iphone14-2026-11-25/bitacora.md), lote 2 de 3, pedido por Jürgen a las 18:21 (Lima)"
---

# Guías y avisos que señalan donde deben

Segundo lote de la observación del iPhone 14. Cubre cinco cards del tablero de Yala 2.3.

## Qué cambia para la persona

1. **Historias de Primeros pasos.** Tocar a la izquierda o a la derecha, y mantener el dedo para pausar, responde en
   toda la zona entre las rayitas y el botón, también donde el contenido ya terminó. Antes solo respondía sobre el
   texto y los ejemplos. El contenido largo se sigue desplazando.
2. **«Tus presupuestos / pagos planificados / gráficas viven en Más» y «Tus grupos, a un toque».** Mientras se ve el
   aviso, la barra de pestañas va desplegada y la pestaña señalada lleva un borde del color del tema. Tocarla sigue la
   guía, como antes.
3. **Paso 6.** Si Más estaba desplazada, la guía la lleva hasta Estadísticas antes de enmarcarla. Al tocar
   «Entendido», el paso queda hecho y vuelve al Panel, con el mazo en el paso 7.
4. **Intro de Grupos tras cerrar sesión.** Si ya se aceptó, no vuelve a salir al cerrar sesión y volver a entrar.

## Decidido sin consultar

- La marca de la intro de Grupos sobrevive al borrado del cierre de sesión, que también usa «Eliminar cuenta». Es lo
  mismo que ya pasaba con las intros de Primeros pasos. «Vaciar datos» y «Empezar de cero» la siguen reiniciando.
  No se guarda por cuenta: haría falta más maquinaria y el teléfono es de quien aprendió.
- El borde de la pestaña vale también para «Grupos» y para la guía de gráficas «días después», que usan el mismo aviso.

## Cómo se probó

- Unitarias: `YalaTests/GuiasSenalanBien/GuiasSenalanBienTests` (15 casos, verdes; y `YalaTests` entero: 16.394 pruebas en verde).
- Interfaz: `YalaUITests/GuiasSenalanBien/GuiasSenalanBienUITests`, dos casos verdes: el paso 6 con Más desplazado
  (rojo sin el arreglo: reprodujo la guía centrada sin foco) y el aviso de presupuestos con la barra encogida.
- Historias: medido a mano en el simulador con `axe`. Tocar a 450, 600 y 738 pt (justo encima del botón) avanza. El
  toque sintético de XCUITest en esa franja no llegaba ni con el arreglo, así que ese caso no tiene XCUITest: lo fija
  el cableado en la unitaria y el guion de abajo.
- Intro de Grupos: unitarias del barrido (el cierre de sesión completo no se recorre en el simulador sin cuenta).

## Guion para el iPhone (cuando puedas)

1. Primeros pasos, intro del paso 1: toca en la mitad de abajo, justo encima de «Crear mi primera cuenta», a la
   derecha. Debe pasar a la parte 2. A la izquierda, vuelve. Mantén el dedo ahí: la barra se detiene.
2. Termina el paso 3 con el Panel desplazado hacia abajo (barra encogida). El aviso «Tus presupuestos viven en Más»
   sale con la barra desplegada y «Más» bordeado. Toca «Más»: te lleva a Presupuestos.
3. Abre Más, desplázala hasta abajo, vuelve al Panel y toca el paso 6. La guía enmarca Resumen, Tendencias y
   Distribución. «Entendido» te deja en el Panel con el paso 7.
4. Con la intro de Grupos ya aceptada, cierra sesión y vuelve a entrar con la misma cuenta. Grupos → «Nuevo grupo» no
   repite la intro.
