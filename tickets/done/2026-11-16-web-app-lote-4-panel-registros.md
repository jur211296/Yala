---
id: 2026-11-16-web-app-lote-4-panel-registros
status: done
priority: high
area: web
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-web-app-lote-4-panel-registros (maqueta «Yala web como la app», aprobada el 16-nov)
---
# Yala web como la app, lote 4: Panel, Registros y Nuevo registro

Cuarto de los seis lotes del plan de `docs/web-app/parecida-a-la-app/`. Las tres pantallas que más se usan pasan a verse
y leerse como en la app. Las decisiones, con su porqué, están en el Paso 0 del encargo
(`encargos/lanzados/2026-11-16-web-app-lote-4-panel-registros.md`).

## Qué cambia para quien usa la web

- **Panel:** abre con «Tu saldo hoy» en grande sobre el fondo, sin tarjeta, y un «?» que explica la cifra con el texto
  de la app («Suma todas tus cuentas, también las tarjetas…»). Debajo, entradas y salidas del mes. «Tus finanzas»: en
  escritorio, tarjetas con el color de cada cuenta; en el celular, las cápsulas de cristal de la app. «Últimos registros»
  con la fila de la app. Se suman Distribución (categorías del mes con su ícono y color) y Planificación (lo que falta
  pagar en 30 días y los dos presupuestos más gastados). Cada título lleva a su pantalla.
- **Registros:** arriba «Te queda» del mes (o «Te quedó» del mes pasado), con entradas, salidas y número de movimientos:
  las cifras de Estadísticas. Los filtros son cápsulas de cristal (período, cuenta, categoría, buscar en las notas,
  Exportar CSV). Cada registro es una tarjeta con su círculo de color, la cifra con signo, las etiquetas y la píldora de
  necesidad (Esencial, Prioritaria, Opcional). Cada día dice lo que se gastó. En escritorio ancho el detalle se abre a la
  derecha; en el celular, en una hoja.
- **Nuevo registro** (antes «Apuntar»): la hoja centrada en el monto, con «Hoy» en cápsula, Gasto o Ingreso, la
  descripción con el ejemplo de la app, «¿Cuánto gastaste?» y la cifra grande con su símbolo, hasta tres categorías
  sugeridas (las de tus últimos registros) y Cuenta y Categoría en cápsulas. Sigue yendo a la Bandeja del iPhone.
- En el celular, «+ Nuevo registro» va debajo de la cifra principal, como en la app.

## Decisiones que un lote siguiente no debe deshacer

- Los rótulos nuevos son los de la app en sus 16 idiomas; `test/lote4.test.ts` los compara con `Localizable.strings`.
- Lo gastado de cada día es la cabecera de día de la app: solo gastos, con signo, en la divisa preferida; sin cifra si un
  gasto no tiene conversión o si el día puede seguir en la página siguiente (`registro.ts`).
- El resumen de Registros solo sale sin filtro de cuenta, categoría ni texto: es la cifra de Estadísticas, que no los
  recoge.
- Las claves `app.apuntar` y `app.apuntarTitulo` quedan sin uso (se quitan con el lote 5, que toca los 14 idiomas).

## Fuera de este lote

- El menú «…» de la maqueta para Exportar: Exportar queda como cápsula al final de los filtros.
- Mi parte, Favorito, Recurrente y Etiquetas en Nuevo registro: el borrador de la web no los guarda.
- Planificación, Estadísticas, Grupos, Bandeja y Ajustes: lote 5.

## Pruebas

- `webapp`: `npm run typecheck` y `npm test` (269 casos; 21 nuevos en `test/lote4.test.ts`). Las de Registros (filtros,
  CSV, cargar más) y las de borradores siguen en verde.
- Recorrido en Chromium sin cabeza, `docs/web-app/parecida-a-la-app/herramientas/recorrido-lote-4.mjs`: 54
  comprobaciones en verde contra el servidor de maqueta (el «?», los títulos que llevan a su pantalla, resumen y cuándo
  se esconde, filtros, detalle a la derecha y en hoja, CSV, la hoja con el teclado y el borrador que envía, el ojo y
  390 px sin scroll lateral). El de navegación del lote 3 sigue en verde.
- Capturas de antes y después en `docs/web-app/parecida-a-la-app/capturas/lote-4/` (claro y oscuro, escritorio y
  celular, con la hoja y el detalle abiertos), hechas con `herramientas/capturar-pantallas.mjs`.
