---
id: own-telemetry-panel-by-sections
status: qa
priority: high
area: telemetry
created: 2026-11-06
updated: 2026-11-06
source: encargo 2026-11-06-telemetria-propia-construccion · card «Telemetría propia en Cloudflare y dashboard en lenguaje natural, para reemplazar TelemetryDeck»
---

# Panel propio por secciones, con frases, y los datos que faltaban

## Qué cambia

- **Para Jürgen**: un panel en `panel.yala-app.pe`, detrás de su cuenta, con siete secciones —Uso, Registro, Grupos,
  Nube, Pro, IA y Salud—. Cada número va con una frase que se entiende sin saber de métricas, y guarda historia más allá
  de los 90 días de Analytics Engine.
- **Para quien usa Yala**: nada visible. La app apunta, como mucho una vez al día, qué funciones usó, si vio la oferta
  de Pro o chocó con un límite del plan gratis y por qué pasos del alta pasó. Sin importes, nombres ni textos.

## Decisiones (Jürgen, 2026-11-06)

Las 8 recomendadas de `docs/telemetria/propuesta-2026-11.md`, con la 1 en **C** (funciones + oferta de Pro + límite +
pasos del alta). Las asumidas por la sesión están en el `## Paso 0` del encargo y en el PR: retención 7/30 días por
cohorte de alta, umbrales de Salud (ámbar desde 1 aparato, rojo desde 5), «se convirtieron en suscripción» sin
pintar, costo de IA con la tabla de precios del banco y altas contadas por persona.

## Guion de QA (tras desplegar; pasos de despliegue en `panel/README.md`)

1. Abrir `https://panel.yala-app.pe` en el Mac con `admin@yala-app.pe`: entra. En una ventana privada con otra cuenta:
   Access lo corta.
2. Al pie, «Al día hasta el <ayer>» y «Última corrida: … bien». Si dice «sin conteos de la base», falta el paso 2 o el
   4 del README.
3. Uso, Nube e IA tienen cifras desde el primer día (vienen de lo que ya llega). Comparar «Activos en la semana» con
   el SQL de `qa/cloud/README.md` § Telemetría propia: deben cuadrar.
4. Grupos y «Cuentas en la nube»: cifras reales (no «sin datos aún»).
5. Con un build de 2.3 en el iPhone de pruebas (gateway ya desplegado): abrir Panel, Estadísticas, Presupuestos y
   Grupos y registrar un gasto. Al día siguiente, «Lo que más se usa» los enseña (cada uno «< 3» con un solo teléfono).
6. Pro: tras una compra de prueba en Sandbox, la tarjeta sigue vacía en el panel (cuenta solo Production). Es lo
   esperado.

## Fuera

- Un resumen semanal con IA (decisión 4 = A: solo plantillas).
- Que el panel distinga una prueba que pasa a pago de una renovación.
- Ticket del hallazgo de camino: `born-cloud-signup-sends-two-registrations`.
