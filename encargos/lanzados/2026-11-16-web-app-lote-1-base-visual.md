Yala
# Yala web como la app · lote 1: base visual en claro y Liquid Glass
---
toca: webapp/src/client/styles.css, webapp/src/client/app.css, webapp/index.html, webapp/src/client/app/Configurar.tsx, webapp/src/client/app/Monto.tsx, webapp/src/client/app/format.ts, webapp/src/client/i18n/*.ts, webapp/test/, docs/web-app/parecida-a-la-app/capturas/lote-1/, tickets/done/2026-11-16-web-app-lote-1-base-visual.md
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen (16-nov, 17:45 Lima) revisó la maqueta comentable «Yala web lo más parecida posible a Yala móvil» (PR #1007, `docs/web-app/parecida-a-la-app/index.html` y su `README.md`) y aprobó **todo lo recomendado**. Esto implementa el lote 1 de los seis de su «Plan por lotes».

Decisiones aprobadas (las recomendadas de la maqueta): tema oscuro Liquid Glass por defecto con selector en Ajustes (Como el sistema, Claro, Oscuro, Liquid Glass); barra lateral de cristal en escritorio, como la app en iPad; en celular las pestañas de la app (Panel, Registros, Grupos y Más, con Buscar aparte, Bandeja arriba a la izquierda y «+ Nuevo registro» en el contenido); Voz, Foto y Yala IA no se muestran hasta que la web los tenga (Yala IA sigue en la barra lateral con «Pronto»); íconos Lucide con tabla desde los SF Symbols; cifras en letra redondeada del sistema con Nunito de respaldo; Planificación y Distribución se suman al Panel, como en la app.
Además, el hero del Panel de la app (saldo grande con rótulo claro, «?» que explica la cifra y sin hueco antes del valor) es el estándar de claridad: aplícalo donde la web muestre una cifra principal.

## Lote 1 · Base visual
Variables de color, fondo, tarjetas, cristal y cifras para los dos temas; selector de tema en Ajustes; componente Monto. Ya cambia todas las pantallas sin tocar su estructura.

Archivos previstos: webapp/src/client/styles.css, webapp/src/client/app.css, webapp/index.html, webapp/src/client/app/Configurar.tsx, webapp/src/client/app/Monto.tsx (nuevo), webapp/src/client/app/format.ts, webapp/src/client/i18n/*.ts (16 idiomas).
Pruebas: npm run typecheck, npm test y capturas de antes y después en claro, oscuro, escritorio y celular.

## Cómo entregar
- Usa `docs/web-app/parecida-a-la-app/herramientas/` para las capturas de antes y después en claro y oscuro, escritorio y celular (390 px), guardadas en `docs/web-app/parecida-a-la-app/capturas/lote-1/`.
- `npm run typecheck` y `npm test` de la web en verde.
- Las direcciones de hoy (/registros, /presupuestos, /pagos…) siguen funcionando.
- Producción: Jürgen autorizó el 16-nov ir subiendo Yala web a producción (app.yala-app.pe) para probarla con su cuenta personal; todavía no está enlazada desde la web principal y eso no cambia. Despliega a producción solo con todo en verde y pruébalo de punta a punta allí, como se hizo en «Yala web en producción probada de punta a punta» (PR #1001).
- Entregable visual: artifact de Claude con antes y después lado a lado de cada pantalla tocada, junto a la app como referencia. Nunca Markdown ni PDF como entregable.

## Reglas
- Toca solo lo declarado. Si hace falta otro archivo, agrégalo de forma mínima y anótalo en «Decidido sin consultar».
- Commits y PR sin firma de IA. PR contra `2.3`.
- Si necesitas mirar la app como referencia: en la Max puedes usar un segundo simulador (además del de otra sesión) o el iPhone 14 conectado por DeviceMCP; en la Mini, uno solo.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital se pregunta según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto).
- Sin credenciales nuevas inventadas: los secretos de producción ya están en su lugar (Turnstile en la Mini, `~/Secrets/yala-web-production/`); nunca los imprimas.
- Cierre: si está completo y el modo lo permite, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», el link del artifact y el link de producción si se desplegó.

## Paso 0 — decisiones (resueltas por la sesión, modo semi; lo menor y reversible con la recomendada)

1. **Qué es «Liquid Glass por defecto».** El selector arranca en «Como el sistema»: claro con el sistema en claro y Liquid Glass con el sistema en oscuro. «Oscuro» es el negro plano de la app y «Liquid Glass» lo fuerza siempre. Es lo que dicen las variables de la maqueta aprobada («por defecto en oscuro y forzado con data-tema»).
2. **Dónde se guarda el tema.** En este navegador (localStorage), como el idioma y «Ocultar montos al abrir». No viaja a la nube ni al iPhone.
3. **Cuándo se aplica.** Al arrancar, antes de pintar React (`src/client/tema.ts`, llamado desde `main.tsx`); la CSP no deja scripts en línea en `index.html`. Sin preferencia guardada, el CSS ya sigue al sistema solo, sin JS.
4. **Nunito.** Se sirve desde la propia web (dentro de `/assets/`, con huella): la CSP solo admite `font-src 'self'`. Licencia OFL junto a los ficheros. El navegador solo la baja donde no hay letra redondeada del sistema.
5. **Una sola fuente de colores.** Todos los colores por tema viven en `styles.css`; `app.css` deja de tener bloques `prefers-color-scheme` (si no, el tema elegido en Ajustes no alcanzaría a la app con sesión). Un test lo vigila.
6. **Monto.** Componente nuevo con el mismo texto que `money()` (copiar, buscar y lectores de pantalla no cambian). En este lote solo se usa en las cifras principales (Panel, Estadísticas, Pagos planificados): una línea por pantalla, anotada como fuera de «toca». El resto de cifras y el «?» del hero llegan con sus lotes (4 y 5), que reestructuran esas pantallas.
7. **Contraste.** El gris secundario del tema claro se queda en #6C6C78 (AA) y no en el 64 % de la app, que no llega a 4,5:1 en texto pequeño.
8. **Sin despliegue a producción si algo no está verde**; con todo verde, se despliega y se prueba allí como en el PR de producción probada.
