# Exploración 2.3 · Mascota «Yalitto»

Cinco direcciones visuales para una mascota de Yala, dónde viviría en la app, cómo se movería y qué haría. **No implementa
nada y no elige**: recomienda y deja las decisiones a Jürgen. «Yalitto» es un nombre provisional. Card del tablero:
`tablero-analizar-una-mascota-en-la-app-56ze`.

- **Abrir:** `yalitto.html`. Es un solo archivo con todo dentro (capturas, SVG, animaciones): se abre en el iPhone o en la
  Mac sin nada al lado. Abajo hay un selector para ver cada Yalitto, «Más lento» y «Simular Reducir movimiento».
- **Respaldo:** `yalitto.pdf` (36 páginas A4, ~2 MB). En el PDF la animación se sustituye por el storyboard.
- **Regenerar:** `cd fuente && python3 build.py` (Python 3 de serie, sin dependencias). El PDF se imprime del HTML con
  Chromium sin cabeceras: `chrome-headless-shell --headless --no-pdf-header-footer --print-to-pdf=../yalitto.pdf yalitto.html`
  (el de Playwright está en `~/Library/Caches/ms-playwright/chromium_headless_shell-*`). Para revisar por partes:
  `yalitto.html?quieto&solo=<sección>` (`referentes`, `direcciones`, `personalizar`, `superficies`, `movimiento`,
  `reglas`, `tecnica`, `decision`).

## Qué hay

| Sección | Contenido |
|---|---|
| 1. Referentes | Duolingo, Copilot (Mico), Notion AI, Finch, Cleo, Clippy, Pablo y Ditto: qué tomamos y qué evitamos, con fuente enlazada |
| 2. Direcciones | A Gota, B Ficha, C Trazo, D Boleta, E Bit: silueta, tamaños, 8 expresiones, formas, colores, detalles, qué cambia y qué no. Descartada «Brote» (moraliza el ahorro) |
| 3. Personalizar | Configurador de la dirección A (forma × color) y los límites para que siga siendo reconocible |
| 4. Dónde vive | 10 superficies: 7 capturas reales de Yala 2.3 con Yalitto encima y 3 maquetas dibujadas (presupuesto al 90 %, widget, Ajustes) |
| 5. Movimiento | 8 prototipos animados en CSS/SVG (reposo, saludo, primera utilidad, ayuda, pensando, error, presupuesto cerca y pasado) y su storyboard |
| 6. Reglas | Qué hace y qué no, la prueba de valor frente a decoración, presencia, apagado, Reducir movimiento, VoiceOver, montos ocultos, tono |
| 7. Técnica | Sin conexión, privacidad, batería; SwiftUI nativo frente a Lottie y Rive, sin cifras inventadas |
| 8. Decisión | Comparativa de las cinco, recomendación (A · Gota) y siete decisiones para Jürgen |

## Cómo se hizo

- **Personajes:** SVG propios generados por `fuente/yalittos.py`. Las cinco direcciones comparten piezas de cara y estados,
  así que cualquier maqueta y animación se ve con cualquiera.
- **Capturas:** Yala Dev compilada desde `origin/2.3` el 7-nov-2026, simulador iPhone 17 Pro con iOS 27.2, modo oscuro,
  semilla «realista» con Pro (`-uitest -uitest-pro -uitest-skip-onboarding -uitest-seed realista`; Yala IA con
  `-uitest-ai-chat-ready -uitest-chat-conversation`). Nuevo registro y Registros vacío vienen de las revisiones de vistas
  2.3 del 6 y 7 de noviembre. La Bandeja y el botón de Yala IA no abren con toques de `axe`; sí con el tap de XcodeBuildMCP.
- **Verificación:** HTML revisado en Chromium a 390 px (teléfono) y 1280 px (escritorio), en claro y en oscuro, y el PDF
  página a página.

## Decisiones para Jürgen

1. ¿Se hace? (puede quedar en exploración; no adelanta el roadmap 2.5).
2. ¿Qué dirección? Recomendada A · Gota; alternativas E · Bit (solo Yala IA) o C · Trazo (la más sobria).
3. ¿Encendido por defecto en los sitios de v1 o se ofrece una vez?
4. ¿Qué superficies en v1? Recomendado: vacíos, errores, primer registro, Bandeja, presupuestos, Yala IA y Ajustes.
5. ¿Nombre? «Yalitto» recuerda a Ditto: revisar marcas antes de usarlo en público.
6. ¿Cómo se construye? Recomendado SwiftUI nativo con un prototipo medido; Rive como plan B.
7. ¿Se cambia ya el texto «¡el próximo período será mejor!» de presupuesto pasado?

## Encontrado (no se tocó)

- Con la semilla «realista» en 2.3, Planificación muestra cada presupuesto **dos veces** y la Bandeja cada borrador dos
  veces («Almuerzo equipo», «Taxi aeropuerto»), con categoría «Accesorios y juguetes». Visto en el simulador el 7-nov; no
  se averiguó si es la semilla o la vista.
- La lista de presupuestos dice «Pasaste tu presupuesto, ¡el próximo período será mejor!» y el muro de Yala IA dice
  «No pudimos cargar los precios. Revisa tu conexión.»: los dos chocan con «sin moralizar» y «sin culpar».
- `docs/planning/BRAND-VOICE.md` pone como ejemplo bueno «¿Qué tal si cocinamos en casa estos días?», que es opinar sobre
  el gasto. Si Yalitto se hace, conviene revisar ese ejemplo.
