---
id: 2026-11-16-web-app-lote-1-base-visual
status: done
priority: high
area: web
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-web-app-lote-1-base-visual (maqueta «Yala web como la app», aprobada el 16-nov)
---
# Yala web como la app, lote 1: base visual

Primero de los seis lotes del plan de `docs/web-app/parecida-a-la-app/` (maqueta aprobada por Jürgen el 16-nov a las
17:46, todo lo recomendado). Este lote cambia el aspecto de todas las pantallas sin tocar dónde está cada cosa.

## Qué cambia para quien usa la web

- **Liquid Glass en oscuro**: azul noche con el degradado índigo de la app arriba y tarjetas de cristal.
- **Claro como la app**: blanco azulado con el velo índigo y tarjetas blancas con sombra suave.
- **Tema en Configurar › En esta web**: Como el sistema (por defecto), Claro, Oscuro (el negro plano de la app) o
  Liquid Glass. Se guarda en ese navegador, como el idioma.
- Tarjetas de 22 px, botones en cápsula, botones redondos de cristal arriba, barra lateral y barra de pestañas de cristal.
- Cifras en la letra redondeada del sistema; fuera de Apple, Nunito servida por la propia web.
- **Monto**: la cifra principal del Panel, de Estadísticas y de Pagos planificados se dibuja como `AmountText` de la app
  (entero grande, símbolo y decimales a la mitad y en gris), con el mismo texto que antes.

## Decisiones del Paso 0

Están en el encargo (`encargos/lanzados/2026-11-16-web-app-lote-1-base-visual.md`) y en el cuerpo del PR. Las que un
lote siguiente no debe deshacer:

- Todos los colores por tema viven en `webapp/src/client/styles.css`; `app.css` no mira `prefers-color-scheme`. Si no, el
  tema elegido en Configurar no alcanza a la app con sesión. Lo vigila `webapp/test/base-visual.test.ts`.
- La clase de tamaño de Monto es `principal`, no `hero`: `.hero` es la tarjeta que la contiene.
- Gris secundario del claro en #6C6C78 (contraste AA), no el 64 % de la app.

## Fuera de este lote

- El «?» que explica cada cifra principal (estándar del hero del Panel de la app): con los lotes 4 y 5, que rehacen esas
  pantallas.
- Monto en filas y listas, íconos Lucide, navegación y la entrada: lotes 2 a 6.

## Pruebas

- `npm run typecheck` y `npm test` de `webapp/` en verde, con `test/base-visual.test.ts` nuevo: Monto da el mismo texto
  que el `money()` anterior en los 16 idiomas, el tema se guarda y se aplica, cada tema define todas las variables.
- Capturas de antes y después (claro, oscuro del sistema, temas forzados; escritorio 1280 px y celular 390 px) en
  `docs/web-app/parecida-a-la-app/capturas/lote-1/`.
