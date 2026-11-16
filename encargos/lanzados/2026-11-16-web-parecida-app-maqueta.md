Yala
# Maqueta comentable de Yala web lo más parecida posible a Yala móvil
---
toca: docs/web-app/parecida-a-la-app/
esfuerzo: high
cierre: cierra-sola
---

## Pedido de Jürgen (16-nov, 15:59 y 16:00 Lima)
«he mirado yala web y no se parece NADA a yala movil. Debería ser lo más parecido posible.» Pidió **maqueta primero** y después implementar. La decisión ya está capturada en el registro.

## Qué se pide (esta sesión NO implementa)
1. Inventario lado a lado: cada pantalla y flujo de la web (`webapp/src/client/`, en producción en https://app.yala-app.pe) junto a su equivalente en la app de iOS. Capturas reales de las dos: simulador o iPhone 14 por DeviceMCP para la app, navegador para la web. Para cada par, anota qué se ve distinto: colores, tipografía, tarjetas, íconos, espaciados, navegación, estados vacíos, modo claro y oscuro, textos y orden.
2. Extrae el sistema visual de la app desde el código Swift: colores, tamaños de letra, radios, sombras, íconos SF Symbols y su equivalente web, y componentes. Propón cómo llevarlo a la web: tokens CSS y componentes.
3. Maqueta de la web rediseñada, pantalla por pantalla, para escritorio y para celular en navegador, en claro y oscuro. Adapta a pantalla grande lo que haga falta, por ejemplo una barra lateral en lugar de las pestañas de abajo, y justifica cada adaptación.
4. Que sea comentable: en cada pantalla, «me gusta / cambiar» con comentario y exportar los comentarios en un bloque. Marca lo que es decisión de Jürgen con opciones y tu recomendación.
5. Plan de implementación por lotes, con qué archivos toca cada uno, para encolarlo después de su visto bueno.

## Entrega
- Artifact visual de Claude, no Markdown ni PDF, en español neutro latinoamericano. El link va en el cierre.
- La fuente y las capturas van en `docs/web-app/parecida-a-la-app/`, en un PR chico a 2.3, sin firma de IA. No toques el código de la web ni de la app, ni producción.
- Si hace falta un simulador, en la Max puedes usar un segundo simulador, además del de otra sesión, o el iPhone 14 por DeviceMCP.
- Lo menor y reversible se decide y se anota en «Decidido sin consultar». El cierre conserva las secciones «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada una con motivo o «Nada».
- Cierre según el modo fijado al arrancar. En semi, si queda completo, `/cerrar-total`. En nocturno, lo vital va a checkpoint.

## Paso 0 — decisiones (resueltas en semi, por Frank, 16-nov 17:40)

1. **Capturas de la web con datos**: la web exige sesión y no tiene modo demo. Se sirve el build de `webapp/` en local con un servidor de maqueta que responde `/api/*` con datos inventados (fuera del repo, en el scratchpad). No se entra a producción con la cuenta de Jürgen: serían sus datos reales en un artifact público.
2. **Capturas de la app**: simulador iPhone 17 Pro libre en la Max (el Device MCP Free espejaba el iPhone de Jürgen), Yala Dev con `-uitest-seed rendimiento`; oscuro = tema por defecto (Liquid Glass), claro = `-userTheme 1`.
3. **Rediseño dentro del artifact**: maquetas en HTML vivo con los tokens medidos en Swift, no imágenes. No se añaden funciones que la web no tiene (Voz, Foto, Yala IA, salud financiera): lo dudoso va como decisión con recomendación.
4. **Íconos**: SF Symbols no se pueden usar en web por licencia; la maqueta usa Lucide y se propone como decisión.
5. **Comentarios**: `db` del artifact (escritura solo del dueño) + respaldo en el navegador + bloque para exportar.
6. **Entrega**: `docs/web-app/parecida-a-la-app/` (index.html + capturas jpg). Solo `docs/` y `encargos/`: no hay nada que compilar, gate de validación del índice. PR a 2.3 en cola de auto-merge.
