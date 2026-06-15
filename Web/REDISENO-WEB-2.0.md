# Rediseño web Yala 2.0 — Resumen

Rama: `web/redesign-2.0` (desde `2.0`). Stack intacto: Astro 5, Tailwind, i18n (es/en/de/fr/it/pt), middleware de routing por idioma. **No se tocaron rutas ni el sistema i18n.** Build verde (`npm run build`).

---

## 1. Rediseño visual "liquid glass" — antes / después

| Aspecto | Antes (1.x) | Después (2.0) |
|--------|-------------|----------------|
| **Fondo** | Color plano (`bg-yala-slate` / `neutral-50`) | Capa **aurora** fija (gradientes radiales indigo/cyan/pink) con **deriva lenta**, detrás del contenido; atenuada en light. |
| **Cards** | Borde sólido, fondo opaco | **Glass**: `backdrop-filter: blur(18px) saturate(135%)`, borde translúcido + *inner highlight*, esquinas squircle (24px), hover con lift + glow. |
| **Botón primario** | Indigo sólido | Gradiente de marca (indigo→violeta→pink) + glow + highlight interno. |
| **Hero** | Mockup estático | Mockup con **halo de glow** + **tilt sutil al cursor** (desktop) + flotación. |
| **Scroll-reveal** | fade + translate | + **blur-in** y stagger (sensación glass). |
| **Galería** | — | **Carrusel auto-scroll** (marquee) con los 10 screenshots compuestos, pausa al hover/focus. |
| **Sheen** | — | Barrido de brillo diagonal al hover en glass-cards. |
| **Páginas legales/soporte** | Fondo plano | Contenedor **glass-dark** sobre la aurora. |

**Motion:** todo CSS + JS vanilla, **sin librerías nuevas**. Bajo `prefers-reduced-motion: reduce` se desactiva (aurora estática, sin tilt, sin blur-in, galería con scroll manual).

**Responsive y dark/light:** verificado en desktop y móvil; dark (default) y light (toggle por `body.light`). Aurora y glass funcionan en ambos.

### Secciones nuevas en la home
- **Yala IA** (`#yala-ia`) — showcase del chat con badge **Pro**, 3 bullets, mockup real y **nota de transparencia** (OpenAI + consentimiento) con link a Privacidad.
- **Grupos** (`#grupos`) — badge **Beta**, "vía iCloud", 3 bullets, mockup, nota de privacidad.
- **Galería "Yala por dentro"** — carrusel de los 10 compuestos (localizado).
- **Features bento:** +2 tarjetas destacadas (Yala IA · Pro, Grupos · Beta).
- **Nav:** +`Yala IA` y `Grupos` (desktop + móvil).
- **FAQ:** +2 (datos de Yala IA, privacidad de Grupos) en home y soporte.
- **Pricing Pro:** +línea "Yala IA: tu asistente financiero".
- **Copy de confianza:** `heroTrust`/`ctaTrust` "100% privado" → **"Privado por diseño"** (honestidad: la IA opt-in envía datos a OpenAI).

### Archivos tocados (UI)
- `src/styles/global.css` — aurora, glass, motion, marquee, reduced-motion.
- `src/layouts/Layout.astro` — `<div class="aurora-bg">` + meta description.
- `src/components/HomePage.astro` — nav, hero, secciones Yala IA/Grupos, galería, features, pricing, FAQ, tilt JS.
- `src/components/PrivacyPage.astro` · `TermsPage.astro` · `SupportPage.astro` — glass-dark + secciones/FAQ nuevas.
- `src/i18n/translations.ts` — +31 keys nuevas ×6 idiomas + reescritura legal (ver doc legal).
- `tailwind.config.mjs` — sin cambios (radios vía CSS).

---

## 2. Screenshots 2.0 integrados

**Fuente:** `screenshots-appstore/` (el set 2.0 con Yala IA y Grupos dedicados), optimizados con `sips` → `Web/public/images/screenshots/v2/`. **Peso total 5.0 MB** (vs 22 MB del set 1.x — **−77%**), mayoría lazy-load. Idioma-aware: `es`→`-es`, resto→`-en`, con fallback a `es` donde `raw/en/` no existe.

### Mockups (en marcos CSS, ~860px, JPEG q88)
| Ubicación | Imagen | Idiomas |
|-----------|--------|---------|
| Hero | `panel-hero` | es (fallback global) |
| Sección Yala IA | `chat-analisis` | es, en |
| Sección Grupos | `grupos-lista` | es, en |
| Cómo funciona · paso 1 | `nuevo-registro` | es, en |
| Cómo funciona · paso 2 | `panel-distribucion` | es, en |
| Cómo funciona · paso 3 | `stats-tendencias` | es (fallback) |
| Analytics | `stats-resumen` | es, en |

### Galería (compuestos localizados, ~700px, JPEG q85)
`01-hero`, `02-yala-ia`, `03-grupos`, `04-registro`, `05-score`, `06-presupuestos`, `07-flujo-caja`, `08-distribucion`, `09-temas`, `10-privacidad` — en ES y EN (10×2 = 20).

**Limpieza:** se eliminaron los 25 screenshots 1.x sin referencia de `public/images/screenshots/`.

---

## 3. Verificación
- `cd Web && npm run build` → **Complete** (6 idiomas + privacy/terms/support/invite).
- Paridad i18n: cada key nueva = 6 ocurrencias; **0 `undefined`** renderizado.
- Visual (dev server): hero dark/light, sección Yala IA (con nota de transparencia), glass + aurora, mockups 2.0 cargando, página de privacidad glass-dark. Sin errores de consola.
- Link "Política de Privacidad" en Terms funciona y es por idioma (`/fr/privacy`, etc.).

### Pendiente / fuera de alcance (documentado)
- **og-image.png** no regenerado (asset de diseño aparte).
- **Astro `<Image>`/sharp** (WebP/AVIF responsive) no adoptado — `sips` ya cubre el peso; mejora opcional futura.
- Comentarios HTML de numeración en `TermsPage.astro` (7→8…) quedaron con su número viejo en algunos puntos: son invisibles al usuario (la numeración real viene de las keys, ya correcta); deuda cosmética menor.
