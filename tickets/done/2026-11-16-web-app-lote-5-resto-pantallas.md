---
id: 2026-11-16-web-app-lote-5-resto-pantallas
status: done
priority: high
area: web
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-web-app-lote-5-resto-pantallas (maqueta «Yala web como la app», aprobada el 16-nov)
---
# Yala web como la app, lote 5: Planificación, Estadísticas, Grupos, Bandeja y Ajustes

Quinto de los seis lotes del plan de `docs/web-app/parecida-a-la-app/`. Las pantallas que quedaban pasan a verse como en
la app. Las decisiones, con su porqué, están en el Paso 0 del encargo
(`encargos/lanzados/2026-11-16-web-app-lote-5-resto-pantallas.md`).

## Qué cambia para quien usa la web

- **Presupuestos:** la tarjeta de la app: círculo con el ícono y el color de la categoría, «S/ 1,461.00 de S/ 1,800.00 ·
  15 días», a la derecha «Te quedan» y la cifra (o «Te pasaste por» en rosa), y la barra del color de la categoría, ámbar
  con «En el límite» y rosa con «Te pasaste». En escritorio, de dos en dos.
- **Pagos planificados:** «Por pagar en los próximos 30 días» en grande con su «?»; cada cobro con el ícono de su
  categoría y agrupados por día; en escritorio, Próximos cobros y Suscripciones lado a lado.
- **Estadísticas:** segmentos con ícono en el orden de la app (Resumen, Tendencias, Distribución; en el celular solo el
  elegido lleva nombre), el período en una cápsula, «Te queda» (o «Te quedó») en grande con su «?», y Gasto medio diario
  y Gasto más alto en tarjetas. Cada categoría con su ícono y su color; «Sin categoría» en gris.
- **Grupos:** arriba «Te deben en total · en S/» (o «Debes…», «Estás a mano…») con el neto en grande, la barra rosa y
  verde y los dos lados; con varias divisas, las líneas de antes. Tarjetas con el ícono del grupo. En escritorio ancho, la
  lista a la izquierda y el grupo abierto a la derecha, con «Nuevo gasto», «Saldar» e «Invitar» como cápsulas.
- **Bandeja de Entrada:** se abre encima de la pantalla en la que estabas (panel lateral en escritorio, hoja desde abajo
  en el celular), con la fila de Registros y la píldora del origen. Se cierra con la ✕, con Esc o tocando fuera.
- **Ajustes** (antes «Configurar»): avatar grande con nombre y correo, y grupos de filas con el cuadrito de color, en una
  columna de 700 px.
- Las direcciones de siempre siguen abriendo lo mismo (`/presupuestos`, `/pagos`, `/bandeja`, `/configurar`…).

## Decisiones que el lote 6 no debe deshacer

- El ícono y el color de presupuestos, cobros, trozos y borradores salen de buscar su nombre en `/api/categorias`
  (`app/pantallas.ts`, `app/categorias.ts`): la API solo manda el nombre.
- El neto de Grupos solo sale con una divisa: con varias no se convierte.
- Los rótulos nuevos son los de la app en sus 16 idiomas; `test/lote5.test.ts` los compara con `Localizable.strings`.
  Las tres explicaciones del «?» (Estadísticas, Pagos, Grupos) son textos propios, traducidos a los 14 idiomas.
- `app.apuntar` y `app.apuntarTitulo` se quitaron (sin uso desde el lote 4).

## Fuera de este lote

- La gráfica «Gastos del mes» acumulada día a día y «Tu salud financiera» de Estadísticas: la API no manda la serie
  diaria y la nota se calcula en el iPhone.
- «Nuevo gasto» en la portada de Grupos (la app elige grupo primero) y el segmento «Archivados» de la Bandeja.
- El navegador de período de Presupuestos: la web solo tiene el período en curso.

## Pruebas

- `webapp`: `npm run typecheck` y `npm test` (294 casos; 25 nuevos en `test/lote5.test.ts`).
- Recorrido en Chromium sin cabeza, `docs/web-app/parecida-a-la-app/herramientas/recorrido-lote-5.mjs`, contra el
  servidor de maqueta: todo en verde. Los de navegación (lote 3) y del lote 4 siguen en verde (el de navegación, con la
  Bandeja encima y «Ajustes» como nuevo nombre).
- Staging: las tres escrituras de Grupos desde la interfaz nueva (nuevo gasto, saldar e invitar) con los usuarios de
  prueba, en escritorio y celular, borradas al final por el canal del iPhone; y el e2e de la web, 23 de 23.
- Capturas de antes y después en `docs/web-app/parecida-a-la-app/capturas/lote-5/` (claro y oscuro, escritorio y
  celular), hechas con `herramientas/capturar-lote-5.mjs`.
