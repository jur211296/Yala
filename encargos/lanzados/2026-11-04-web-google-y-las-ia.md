# Web y contenido para que Google y las IA recomienden Yala
toca: web de Yala (yala-app.pe, rama 2.3 de la web), SEO/GEO, contenido

Rama base: la web de la 2.3. Un solo PR, un solo cierre. No despliegues a producción: la producción sigue la rama 1.0 y se pasa en el release. Máquina: la primera que se libere.
Card «Web y contenido para que Google y las IA recomienden Yala», de Lola, aprobada por Jürgen el 2026-11-04. Sigue el plan que ya tiene la card y lo que Lola haya dejado. Incluye los datos estructurados, llms.txt, páginas por funcionalidad y preguntas frecuentes, en español neutro latinoamericano y en inglés. Mide el antes y el después con Lighthouse.

Mueve la card con `tablero`: en curso al empezar e in qa al cerrar.
Si algo bloquea o cambia el resultado, pregunta con `preguntar-bot`; no asumas nada.
El cierre trae la sección «Saltado o asumido sin preguntar».
Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> D1 y D2 las decidió Jürgen por el bot dueño (2026-11-04).

**D1 · ¿Alcance: lo del encargo o el plan entero de Lola (pt, comparativas, guías, calculadoras, URL de ASC)?** → Solo lo del encargo: datos estructurados, llms.txt, páginas por funcionalidad y preguntas frecuentes, en es y en.
Por qué: lo decidió Jürgen. Descartado: comparativas que afirman cosas de la competencia y portugués.

**D2 · ¿URL de marketing por idioma en App Store Connect?** → Fuera; es de Lola (ficha de la App Store).
Por qué: territorio de marketing. Descartado: tocarla desde aquí.

**D3 · ¿Rama?** → Rama `encargo/…` rehecha desde `origin/2.3`, PR contra `2.3`.
Por qué: el encargo dice «rama base: la web de la 2.3». Descartado: 2.2 (de donde nació el worktree).

**D4 · ¿URLs de las páginas nuevas?** → Slugs en el idioma de cada página: `/funciones/<slug>/`, `/preguntas-frecuentes/`; `/en/features/<slug>/`, `/en/faq/`. hreflang solo entre es y en, por página.
Por qué: el slug en el idioma de la búsqueda ayuda a posicionar. Descartado: misma ruta en los dos idiomas (slugs en inglés para el público hispano).

**D5 · ¿Qué seis funciones?** → Anotar gastos (texto, Siri, importar), leer comprobantes por captura, voz y foto del recibo, Yala IA, presupuestos con alertas, dividir gastos (Grupos).
Por qué: son las que ya presenta la web publicada y existen en el código; «Hoy puedes gastar» es de 2.3 sin publicar y no entra.

**D6 · ¿De dónde salen los datos de cada página?** → Del código (`FeatureGateService`: Gratis 4 cuentas y 3 presupuestos; voz, imagen e IA son Pro; `SplitType`: igual, porcentaje, monto, partes) y de la web/llms.txt ya publicados. Nada inventado.

**D7 · ¿«Gratis» en el copy?** → Solo como nombre del plan o como hecho («un mes de prueba gratis»), no como gancho; nada de «la app privada» ni viajes (regla del plan de Lola).

**D8 · ¿Datos estructurados?** → `FAQPage` en la portada (sus 6 dudas visibles) y en las páginas de preguntas; `BreadcrumbList` + `WebPage` sobre la app en cada función; `featureList` en `MobileApplication`. Sin `aggregateRating` (decisión previa del owner).

**D9 · ¿robots.txt?** → Mantener `Allow: /` para todos y nombrar explícitos GPTBot, OAI-SearchBot, ClaudeBot, PerplexityBot y Google-Extended, como pide el plan.

**D10 · ¿Lighthouse antes/después?** → Build local de `origin/2.3` frente a la rama, servido en local, 3 corridas móviles por ruta, mediana. No se mide producción (sigue `1.0`).
