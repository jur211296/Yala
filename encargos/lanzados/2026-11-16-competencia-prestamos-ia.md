Yala
# Análisis: préstamos (Vuelto) y conexión con IA (Neto, Qalta) frente a lo que Yala tiene y planea
---
toca: docs/analisis/2026-11-16-competencia-prestamos-ia/, tickets/done/2026-11-16-competencia-prestamos-ia.md
esfuerzo: medium
cierre: cierra-sola
---

Encargo autorizado por Jürgen el 16-nov (vía Lola): «Sí, que Frank la encole al final de la cola». SOLO ANÁLISIS: no tocar código de la app, no abrir PR de código. El único cambio en el repo es el informe en `docs/analisis/2026-11-16-competencia-prestamos-ia/` y el ticket en done.

Entregable: UN artifact visual de Claude (nunca Markdown/PDF de puro texto), fácil para decidir, con dos partes. Todo en español neutro latinoamericano.

## Parte 1 · Préstamos
Fuente competidor: Vuelto 1.0.7 (13-nov) https://apps.apple.com/pe/app/vuelto-control-de-gastos/id6816194818 — préstamos personales (lo que prestas y te prestan, saldo por persona) y préstamos de banco con cuotas e intereses.
En Yala: cards de la 2.4 «Seguimiento de deudas personales» (`tickets/backlog/debt-tracking.md`) y «Pagos en cuotas: registrar una compra a plazos y ver lo que queda por pagar»; lo que ya existe en Grupos (saldo por persona, patas de préstamo, recordatorio de deuda).
Entregar: comparación lado a lado; qué cubrimos ya, qué falta (en especial préstamos de banco con cuotas e intereses, que no tienen card); propuesta de alcance recomendada con 2–3 opciones y recomendación, y cómo encaja con las dos cards de la 2.4 (fusionar, ampliar o card nueva). Maquetas simples de las pantallas clave.

## Parte 2 · Conexión con asistentes de IA
Fuente competidor: Neto 2.4.28 (15-nov) https://apps.apple.com/pe/app/neto-finanzas-y-patrimonio/id6757704061 — se conecta con Claude/ChatGPT para preguntar por gastos y tiene un panel para ver lo que hizo la IA y desconectarla. Qalta 2.1 tiene algo parecido (App Store PE).
En Yala: conector MCP (pruebas; producción en mcp.yala-app.pe pendiente), cards de la 2.3 «Conectar Yala en Claude iniciando sesión con Apple o Google», «Tu IA registra en Yala: Claude y ChatGPT (y Grok si se puede) crean borradores en la Bandeja» y «Pedir que Yala salga en los directorios de conectores de Claude y ChatGPT». Revisar el código y docs del conector para describir nuestro flujo real.
Entregar: el flujo de conexión paso a paso de Neto (y Qalta, con lo que se vea en su ficha, capturas públicas o sitio web) frente al nuestro; si el suyo es más sencillo y por qué; si conviene sumar un panel de conexiones (qué hizo la IA, desconectar) y dónde iría; recomendación concreta.

## Reglas
- Usa solo fuentes públicas (fichas App Store, sitios web de las apps). No inventes funciones que no estén evidenciadas; marca lo inferido como inferido.
- Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». No asumas accesos ni credenciales.
- Commit y PR sin firma de IA. El PR solo trae el informe y el ticket.
- Simuladores: si los necesitas, puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP.
- Cierre según el modo fijado al arrancar: semi con trabajo completo, `/cerrar-total`; nocturno, si queda algo vital, checkpoint sin completar ni mergear lo incompleto. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar» (con motivo o «Nada») y el enlace al artifact.

## Paso 0 — decisiones (resueltas en semiautónomo; nada vital)

1. **Formato del entregable:** una página HTML publicada como artifact, con tablas, maquetas con piezas de la app y un selector de decisión que guarda en su base de datos (solo escribe el dueño). La fuente se guarda en el repo. Motivo: el encargo pide un artifact visual, y Jürgen decide desde el móvil.
2. **Qalta:** se analiza «Qalta AI: Control de Gastos» (id6756010294), que hoy va en la 2.2.0 y trae el conector desde la 2.1.0. Hay otras tres apps llamadas Qalta en la tienda de Perú, todas en ruso y sin conector, y se descartan.
3. **Neto:** sus pasos para conectar no están publicados. Se marcan como inferidos y no se inventan.
4. **Préstamos:** recomiendo repartir las cards por cómo funciona el préstamo (personas / cuotas), que es una opción por producto y no por esfuerzo. Cómo afecta un préstamo a los totales del Panel queda para el /spec.
5. **Cards del tablero:** no se mueven ni se reescriben hasta que Jürgen elija en la página.
6. **Sin simulador ni pruebas de interfaz:** no hace falta ninguna, porque no se toca la app.
