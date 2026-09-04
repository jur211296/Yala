# Revisión de la web de Yala — UX, engagement y accesibilidad (2026-09-03)

> **Qué es esto.** El informe de la revisión encargada el 2026-09-03: recorrido de la web como usuario en ES y EN,
> comparación con las landings de apps de finanzas personales comparables, auditoría contra WCAG 2.2 AA, y los
> cambios implementados en la rama `encargo/2026-09-03-revision-web-ux-a11y-preview` — **en preview, no en
> producción**. Todo lo que aquí se afirma como «medido» se midió en esta sesión con el comando o herramienta
> que se indica; lo demás va marcado como inferencia o hipótesis.
>
> - **PR:** https://github.com/jur211296/Yala/pull/62
> - **Preview de Vercel (con el rediseño, 2026-09-04):** https://yala-awn0b3ri7-jur211296s-projects.vercel.app
> - **Producción (sin tocar):** https://yala-app.pe

## Índice

1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [Cómo se midió](#2-cómo-se-midió)
3. [Hallazgos](#3-hallazgos)
4. [Lo que hacen las landings comparables](#4-lo-que-hacen-las-landings-comparables)
5. [Criterios de accesibilidad aplicados (WCAG 2.2 AA)](#5-criterios-de-accesibilidad-aplicados-wcag-22-aa)
6. [Oportunidades priorizadas](#6-oportunidades-priorizadas-impacto--esfuerzo)
7. [Qué se implementó](#7-qué-se-implementó)
8. [Verificación: antes y después](#8-verificación-antes-y-después)
9. [Qué queda pendiente y por qué](#9-qué-queda-pendiente-y-por-qué)
10. [Cómo revisar el preview (pasos para Jürgen)](#10-cómo-revisar-el-preview)
11. [Rediseño (2026-09-04)](#11-rediseño-2026-09-04-de-auditar-a-rehacer-la-home)

---

## 1. Resumen ejecutivo

La web está bien construida y **en modo oscuro ya cumplía AA** en lo que axe puede medir. Los problemas
reales estaban en tres sitios que no se ven desde un Mac con tema oscuro y navegador en español:

1. **El idioma no se detecta en producción.** El middleware que redirige a `/en/`, `/de/`… corre en tiempo de
   build (las páginas son estáticas), así que **todo visitante aterriza en español** aunque su navegador pida
   inglés. Medido con `curl -H "Accept-Language: en"` contra `yala-app.pe`: `200` y `<html lang="es">`.
2. **El modo claro fallaba el contraste en 16 elementos** (cian y teal sobre blanco a 1.3:1 y 2.1:1; rosa a
   3.6:1; indigo en texto de 20 px a 4.2:1). Medido con axe-core 4.10 forzando `body.light`.
3. **La política de privacidad describe un proveedor que la app ya no usa.** Nombra a **TelemetryDeck** en los 6
   idiomas; el código iOS lo sustituyó por telemetría propia el 2026-07-17 (`Yala/Services/Metrics/MetricsService.swift:5`,
   `gateway/src/metrics.ts`). Es una afirmación falsa en un documento legal.

Además: un borrador Markdown de la política era una **página pública indexada** (`/privacy_content/`, en el
sitemap); la página de invitación devolvía **500** con un `%` suelto en la URL; faltaban `hreflang`, canónica,
`og:image` absoluta, Smart App Banner y cabeceras de seguridad; ninguna imagen tenía dimensiones (CLS); y la
galería auto-desplazable no tenía forma de pausarse en táctil (WCAG 2.2.2, nivel A).

**Lo implementado** corrige todo lo anterior salvo dos puntos que son decisión de Jürgen (fuentes y el texto
legal de Grupos, ver §9). Lighthouse móvil sobre el build estático: **rendimiento 89 → 94, FCP 2.6 s → 0.9 s**;
accesibilidad, SEO y buenas prácticas se mantienen en 100. axe: **0 violaciones en oscuro y en claro**.

## 2. Cómo se midió

| Qué | Herramienta | Dónde |
|---|---|---|
| Producción tal cual está | `curl -sI` con y sin `Accept-Language`, sitemap, cabeceras | `https://yala-app.pe` (2026-09-03, 22:20 Lima) |
| Recorrido como usuario | Chrome (extensión), ES y EN, oscuro y claro, ancho 1512 y 390 (iframe) | `npm run dev` local |
| Accesibilidad automática | axe-core 4.10.2 inyectado, etiquetas `wcag2a/2aa/21aa/22aa/best-practice`, en los dos temas | home, soporte, privacidad, invitación |
| Contraste | cálculo WCAG propio sobre los colores de marca contra fondo, card y chip | `python3` (tabla en §5) |
| Rendimiento | Lighthouse 12 (móvil emulado) contra el build estático servido en local | `.vercel/output/static` |
| Benchmark | lectura del HTML servido por 6 landings comparables + fuentes primarias (Apple, W3C, web.dev, Google, NN/g, Baymard) | subagente de investigación, 2026-09-03 |

**Dos trampas de medición que conviene recordar:**

- **axe con el contenido oculto no mide nada.** El scroll-reveal deja el 90 % de la home con `opacity: 0` hasta
  que el observer lo muestra; axe lo excluye y devuelve 0 violaciones. Hay que forzar `.is-visible` antes.
- **En un navegador automatizado las transiciones CSS pueden quedarse congeladas.** axe leía colores a mitad de
  transición (`transition-all` de botones y cards) y daba falsos positivos. Se mide con
  `* { transition: none !important }` inyectado.

## 3. Hallazgos

Cada línea dice si se **midió** (M) o se **infirió** (I) leyendo el código.

### 3.1 Funcionales / técnicos

| # | Hallazgo | Evidencia | Estado |
|---|---|---|---|
| F1 | La redirección por idioma en `/` **no funciona en producción**: el middleware solo corre en build para páginas prerenderizadas | M · `curl -H "Accept-Language: en-US" https://yala-app.pe/` → `200`, `lang="es"`. El build avisa: «`Astro.request.headers` is not available on prerendered pages» | **Arreglado** (redirecciones en `vercel.json`) |
| F2 | `/privacy_content/` es una página pública sin estilo e **indexada** (está en `sitemap-0.xml`) | M · `curl https://yala-app.pe/privacy_content` → `200` con `<h1>Política de Privacidad de Yala` | **Arreglado** (movido fuera de `pages/`, redirección 308 a `/privacy`) |
| F3 | `/invite?m=%ZZ` devuelve **500**: `decodeURIComponent` lanza sobre un `%` suelto | M · `curl -o /dev/null -w "%{http_code}" "…/invite?m=%ZZ"` → `500` | **Arreglado** (decode tolerante) |
| F4 | El parámetro `c` (color del grupo) va sin validar a un atributo `style` | M · `?c=fff;background:red` se acepta | **Arreglado** (solo hex de 6 dígitos) |
| F5 | `public/index.html` era la landing de una marca anterior («Neto») con Tailwind por CDN; Astro la pisaba, pero era código muerto | M · `head public/index.html` | **Borrado** |
| F6 | Sin `hreflang`, sin `canonical`, `og:image` relativa (`/og-image.png`), sin `og:url` ni Twitter card | M · `grep` en el HTML de producción | **Arreglado** |
| F7 | Cabeceras de seguridad: solo HSTS | M · `curl -sI` | **Arreglado** (nosniff, Referrer-Policy, X-Frame-Options, Permissions-Policy) |
| F8 | Sin cabeceras de caché para `/_astro/*` e `/images/*` | M · Lighthouse `cache-insight`: 272 KiB | **Arreglado** |
| F9 | La cookie `lang` que el middleware consultaba **nadie la escribía** | M · `grep -rn "document.cookie\|cookies.set" src` → 0 | **Arreglado** (el selector la fija) |
| F10 | Sin página 404 propia | M · `curl https://yala-app.pe/no-existe` → 404 genérico de Vercel | **Arreglado** |

### 3.2 Contenido y coherencia legal

| # | Hallazgo | Evidencia | Estado |
|---|---|---|---|
| L1 | La sección «Analítica anónima» de la política nombra **TelemetryDeck** en 6 idiomas; la app usa telemetría propia desde 2026-07-17 | M · `grep -c TelemetryDeck src/i18n/translations.ts` → 6; `Yala/Services/Metrics/MetricsService.swift:5` («sustituye TelemetryDeck»); `gateway/src/metrics.ts` (Workers Analytics Engine, `install` = hash SHA-256 truncado) | **Reescrito** en los 6 idiomas describiendo lo que hoy se envía. **Requiere revisión legal**, como el resto del texto (ya era DRAFT) |
| L2 | Home, FAQ, política y términos dicen que los datos de Grupos viajan **«por iCloud, no por servidores nuestros»** vía CloudKit Sharing. El repo tiene un backend propio de Grupos (`Yala/Services/CloudSync/Groups/*`, `GroupsSyncClient`, `GroupBackend*`) con `GROUPS_BACKEND_ROLLOUT_PERCENT = "100"` en producción (`gateway/wrangler.toml:166`) | M (existencia del backend y del flag) · **I** (qué camino usa hoy un usuario real: no lo he ejecutado) | **No tocado.** Es texto legal y depende de una verificación que solo el owner puede cerrar. Ver §9 |
| L3 | Sin prueba social. Rating real en App Store PE: **5,0 con 4 valoraciones**; en US: 0 | M · `itunes.apple.com/lookup?id=6758253109&country=pe` | **No añadido a propósito**: con 4 valoraciones una cifra juega en contra (NN/g, «wasn't popular enough») y una cifra fija se queda vieja |
| L4 | Textos alternativos de los mockups en español en todas las lenguas (`alt="Registrar gastos"` en `/en/`) | M · en `/en/` | **Arreglado** (7 alt localizados ×6) |
| L5 | `aria-label` en inglés («Menu», «Toggle theme») en todas las lenguas | M | **Arreglado** (localizados) |
| L6 | La clave `heroLearnMore` («Ver cómo funciona») existía en los 6 idiomas y **no se usaba**: el hero tenía un solo CTA | M · `grep -rn heroLearnMore src/components` → 0 | **Arreglado** (CTA secundario) |

### 3.3 Accesibilidad (detalle en §5)

| # | Hallazgo | Evidencia | Estado |
|---|---|---|---|
| A1 | **Modo claro: 16 fallos de contraste** (1.4.3 / 1.4.11) | M · axe: `#00C2CB` sobre `#FCFDFE` = 2.15; badge Pro 1.9; `#6366F1` a 20 px = 4.16; `#FF0080` = 3.7… | **Arreglado** (0 violaciones) |
| A2 | Modo oscuro: indigo `#6366F1` sobre card = **3.23:1** en `btn-secondary` («Descargar gratis» del plan Gratis); rosa sobre card 3.82 en «Lo que NO hacemos»; cinta PRO 4.46 | M · cálculo + axe | **Arreglado** |
| A3 | Galería auto-desplazable (60 s, infinita) **sin control de pausa** — el hover no existe en táctil (2.2.2, nivel A) | M · `.gallery-marquee:hover … paused`, ningún botón | **Arreglado** (botón Pausar/Reanudar, `aria-pressed`) |
| A4 | Sin *skip link* (2.4.1) | M | **Arreglado** |
| A5 | Menús (hamburguesa, idioma) sin `aria-expanded`/`aria-controls`; tema sin `aria-pressed`; sin cierre con Escape (4.1.2) | M | **Arreglado** |
| A6 | 75 de 75 `<svg>` decorativos sin `aria-hidden` | M | **Arreglado** (76 en home + legales/soporte) |
| A7 | Todo el contenido con `opacity: 0` hasta que corre JS: sin JS la página está **vacía** | M · captura al primer pintado | **Arreglado** (`html.js` como puerta) |
| A8 | `scroll-behavior: smooth` sin respetar `prefers-reduced-motion` | M | **Arreglado** |
| A9 | El selector de idioma no marcaba la opción activa ni el idioma de cada enlace | M | **Arreglado** (`aria-current`, `lang`, `hreflang`) |
| A10 | Enlaces que abren pestaña nueva sin avisarlo | M · 6 `target="_blank"` | **Arreglado** (texto solo para lector de pantalla) |
| A11 | Invitación: chips de miembros con el color del grupo como texto (3.48:1 con el violeta por defecto); sin `<main>` | M · axe | **Arreglado** |
| A12 | Foco visible: solo el anillo por defecto del navegador, invisible sobre las cards glass | I | **Arreglado** (`:focus-visible` con offset) |

### 3.4 Rendimiento percibido (Lighthouse móvil, build estático local)

| Métrica | Antes | Después |
|---|---|---|
| Performance | 89 | **94** |
| FCP | 2,6 s | **0,9 s** |
| LCP | 3,2 s | 3,2 s (ver §9: imagen hero de 224 KB JPEG) |
| CLS | 0 | 0,012 |
| Imágenes sin dimensiones | 31/31 | **0/31** |
| CSS bloqueante (Google Fonts) | 1 860 ms estimados | ya no bloquea |

## 4. Lo que hacen las landings comparables

Observado el 2026-09-03 en el HTML servido (lo que carga por JS puede faltar). Fuentes: las propias webs.

| App | Hero y CTA | Prueba social | Precio en la home | FAQ en la home |
|---|---|---|---|---|
| **YNAB** (ynab.com) | Un CTA repetido «Start Your Free Trial» + «No credit card required»; secundario «Browse App Features» | Trustpilot 4,6 (3 085), App Store 4,7 (103,4k), prensa, 3 testimonios con cifra | No (solo «34-day free trial») | No |
| **Monarch** (monarch.com) | «Unlock better money habits»; banner promocional encima | Citas de prensa con enlace, reseñas de App Store, «50 000+ members» en Reddit | No («7 days free») | No |
| **Copilot** (copilot.money) | «Get started» + «Meet your money assistant» | Apple Editor's Choice, ADA finalist, testimonios con handle | **Sí** ($7.92/mo) | No |
| **Spendee** | Badges iOS/Android como CTA | «4.7 in the App Store», premios, 6 testimonios | No | No |
| **Wallet / BudgetBakers** | «Open Web App» + «Download now»; «Learn More» | «4.7», «14M+ downloads», ISO 27001, GDPR | No | No |
| **Fintonic** | Hoy es una landing de préstamos | «+2 M usuarios», Banco de España, ISO 27001 | No | No |

**Patrones que se repiten en las seis:** un CTA primario único y repetido; badges oficiales de tienda (5/6);
cifras de rating con fuente identificable (4/6); testimonios con nombre (6/6); FAQ **fuera** de la home (6/6).
Yala ya tenía FAQ en la home (no es malo: NN/g no lo desaconseja, pero ninguna comparable lo hace) y no tenía
CTA secundario ni cifras — lo segundo, con 4 valoraciones, es mejor no tenerlo todavía.

**Buenas prácticas con fuente que guiaron los cambios:**

- CTA primario + secundario con jerarquía visual: NN/g, *Button States* (2025) — https://www.nngroup.com/articles/button-states-communicate-interaction/
- «57 % del tiempo de lectura es arriba del pliegue»: NN/g (2018) — https://www.nngroup.com/articles/scrolling-and-attention/
- Carruseles auto-rotativos: mostrar el siguiente panel «only when users ask for it» (NN/g) — https://www.nngroup.com/articles/auto-forwarding/ ; en móvil «autorotation is a bad idea» (Baymard) — https://baymard.com/blog/homepage-carousel
- Prueba social honesta: pocas cifras se vuelven en contra (NN/g) — https://www.nngroup.com/articles/social-proof-ux/ ; reseñas falsas prohibidas por la FTC (2024) — https://www.ftc.gov/news-events/news/press-releases/2024/08/federal-trade-commission-announces-final-rule-banning-fake-reviews-testimonials
- Smart App Banner (`apple-itunes-app`): doc de Apple — https://developer.apple.com/documentation/webkit/promoting-apps-with-smart-app-banners
- Core Web Vitals (LCP ≤ 2,5 s, CLS ≤ 0,1): https://web.dev/articles/lcp · https://web.dev/articles/cls ; `width`/`height` en imágenes: https://web.dev/articles/optimize-cls ; `fetchpriority="high"` en la imagen LCP: https://web.dev/articles/fetch-priority
- `hreflang` (cada versión se lista a sí misma y a las demás, URLs absolutas, `x-default`): https://developers.google.com/search/docs/specialty/international/localized-versions
- **FAQPage ya no produce rich results** (Google lo retiró; la doc fue eliminada) — por eso **no** se añadió JSON-LD de FAQ. `SoftwareApplication` sigue soportado pero exige `aggregateRating` o `review` reales: https://developers.google.com/search/docs/appearance/structured-data/software-app
- `og:image` como URL absoluta (tipo URL de OGP; mínimo 1200×630 según Facebook): https://ogp.me/ · https://developers.facebook.com/docs/sharing/webmasters/images/
- Google Fonts y RGPD: LG München I, 20.01.2022, 3 O 17493/20 — https://www.gesetze-bayern.de/Content/Document/Y-300-Z-BECKRS-B-2022-N-612

## 5. Criterios de accesibilidad aplicados (WCAG 2.2 AA)

Piso: **WCAG 2.2 nivel AA**. Cada criterio con su página *Understanding* de la W3C y el estado en la web.

| SC | Nivel | Qué exige | Antes | Después |
|---|---|---|---|---|
| 1.1.1 Contenido no textual | A | Alternativas textuales; lo decorativo ignorable por AT | alt en español en todas las lenguas; 75 svg sin `aria-hidden` | alt localizado; svg decorativos ocultos |
| 1.4.3 Contraste mínimo | AA | ≥ 4,5:1 (texto grande ≥ 3:1; grande = 18 pt o 14 pt bold) | 16 fallos en claro, 3 en oscuro | 0 / 0 |
| 1.4.11 Contraste no textual | AA | Iconos y bordes ≥ 3:1 | iconos cian/teal en claro 1,3–2,2:1 | override en claro a `#0B6E74` |
| 2.2.2 Pausar, detener, ocultar | A | Movimiento automático > 5 s con mecanismo de pausa (el hover no cuenta) | galería sin control | botón Pausar/Reanudar |
| 2.3.3 Animación por interacción | AAA (no exigible) | Respetar `prefers-reduced-motion` | ya cubierto salvo el scroll suave | scroll suave también |
| 2.4.1 Saltar bloques | A | Skip link | no | sí |
| 2.4.4 Propósito del enlace | A | Se entiende del texto o del contexto | «Descargar» sin avisar pestaña nueva | aviso sr-only |
| 2.4.7 Foco visible | AA | Indicador de foco visible | anillo por defecto | anillo 2 px con offset, ambos temas |
| 2.4.11 Foco no oculto (nuevo 2.2) | AA | El header fijo no tapa el foco | header fijo de 64 px; el skip link lleva al `main` | sin cambios; sin banners que tapen |
| 2.5.3 Etiqueta en el nombre | A | El nombre accesible contiene el texto visible | — | el selector «ES» se llama «Cambiar idioma: es» |
| 2.5.8 Tamaño del objetivo (nuevo 2.2) | AA | ≥ 24×24 CSS px | botones de 36 px | sin cambios (cumple) |
| 3.1.1 Idioma de la página | A | `lang` en `<html>` | sí | sí; `lang` también en cada opción del selector |
| 4.1.2 Nombre, rol, valor | A | Estados expuestos a AT | menús sin `aria-expanded`; tema sin estado | `aria-expanded`, `aria-controls`, `aria-pressed`, `aria-current`, Escape |

Enlaces W3C: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html · …/non-text-contrast.html ·
…/pause-stop-hide.html · …/bypass-blocks.html · …/focus-visible.html · …/focus-not-obscured-minimum.html ·
…/target-size-minimum.html · …/name-role-value.html · …/label-in-name.html · …/language-of-page.html ·
…/non-text-content.html · …/link-purpose-in-context.html. Novedades de 2.2: https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/

**Colores elegidos y sus ratios (calculados):**

| Uso | Oscuro (sobre `#0F172A` / card `#1C2947`) | Claro (sobre `#FAFAFC` / card blanca) |
|---|---|---|
| Acento indigo en texto pequeño/mediano (`--accent`) | `#818CF8` · 5,98 / 4,83 | `#4F46E5` · 6,03 / 6,29 |
| Teal/cian en texto (`--accent-teal`) | `#00F3FF` · 12,98 / 10,47 | `#0B6E74` · 5,76 / 6,01 |
| Rosa en texto (`--accent-pink`) | `#FF5CA8` · 6,25 / 5,04 | `#C4006A` · 5,67 / 5,91 |
| Violeta en texto (`--accent-violet`) | `#A78BFA` · 6,56 / 5,29 | `#6D28D9` · 6,82 / 7,10 |
| Cinta PRO (blanco sobre) | `#4F46E5` · 6,0 | igual |

Los colores de marca puros (`#6366F1`, `#00F3FF`, `#FF0080`, `#00C2CB`) **se conservan en todo el texto grande
(h1, precios, títulos de sección) y en iconos y bordes**, donde cumplen. Solo cambian las piezas de texto de
12–20 px que no llegaban.

## 6. Oportunidades priorizadas (impacto × esfuerzo)

| Prioridad | Oportunidad | Impacto | Esfuerzo | Hecho |
|---|---|---|---|---|
| 1 | Que el idioma del visitante se respete (F1) | Alto: hoy el 100 % de los no hispanohablantes ve español | Bajo | ✅ |
| 2 | Contraste AA en modo claro (A1) | Alto para quien usa claro o tiene baja visión | Bajo | ✅ |
| 3 | Política de privacidad veraz (L1, L2) | Alto: coherencia web ↔ app ↔ App Store que Apple revisa | Bajo (L1) / decisión (L2) | ✅ L1 · ⏳ L2 |
| 4 | Smart App Banner + `hreflang` + OG absoluto (F6) | Medio-alto: conversión en Safari iOS y compartidos en WhatsApp/iMessage | Bajo | ✅ |
| 5 | CTA secundario en el hero (L6) | Medio: patrón estándar; había copy sin usar | Bajo | ✅ |
| 6 | Contenido visible sin JS y sin esperar al observer (A7) | Medio: primer pintado vacío | Bajo | ✅ |
| 7 | Fuentes sin bloquear el render (FCP 2,6 → 0,9 s) | Medio | Bajo | ✅ |
| 8 | Quitar `/privacy_content` del índice (F2) | Medio: duplicado legal sin estilo, indexado | Bajo | ✅ |
| 9 | Robustez de la invitación (F3, F4) | Medio: un enlace compartido que da 500 | Bajo | ✅ |
| 10 | Autoalojar Inter (RGPD DE/FR/IT/PT + LCP) | Medio | Medio: binarios woff2 en el repo, decisión de identidad tipográfica | ⏳ §9 |
| 11 | Imagen hero más ligera (WebP/AVIF, `srcset`) → LCP < 2,5 s | Medio | Medio: adoptar `<Image>` de Astro o regenerar assets | ⏳ §9 |
| 12 | CTA fijo inferior en móvil | Medio (hipótesis; sin dato propio) | Bajo-medio | ⏳ no hecho: cambia la UI móvil, mejor decidirlo con datos |
| 13 | Prueba social (rating, testimonios) | Alto **cuando haya cifras** | Bajo | ⏳ esperar a ≥ 50 valoraciones; hoy 4 |
| 14 | Vídeo demo (sección ya comentada en el código) | Medio | Alto: producir el vídeo | ⏳ |
| 15 | Content-Security-Policy | Medio-bajo | Medio: hay scripts inline y Google Fonts; una CSP mal puesta rompe la web en silencio | ⏳ |

## 7. Qué se implementó

Todo dentro de `Web/`. Sin dependencias nuevas, sin tocar el sistema de rutas i18n ni `marketing/`.

**Para el usuario:**

- Llega en su idioma si su navegador pide inglés, alemán, francés, italiano o portugués; si elige otro idioma a mano, esa elección gana.
- En modo claro todo el texto se lee (antes cian y teal casi invisibles); en oscuro el botón «Descargar gratis» del plan Gratis y el título «Lo que NO hacemos» ganan contraste.
- La web respeta el tema del sistema si nunca eligió uno, y ya no parpadea de oscuro a claro al cargar.
- Hero con dos botones: «Descargar gratis» y «Ver cómo funciona».
- La galería tiene un botón Pausar/Reanudar; pausada, se puede recorrer con el dedo.
- En Safari iOS aparece el banner nativo de la app arriba (abrir/descargar).
- Compartir la web en WhatsApp/iMessage/X muestra la imagen (antes la URL era relativa y no la renderizaban).
- Con teclado: enlace «Saltar al contenido», foco visible en los dos temas, Escape cierra los menús.
- Lector de pantalla: menús con estado, idioma de cada opción, imágenes descritas en su idioma, iconos decorativos silenciados, aviso de «pestaña nueva».
- Página 404 propia (ES + enlace EN).
- Enlace de invitación: ya no falla con un `%` en el nombre de un miembro; los chips de miembros se leen con cualquier color de grupo.
- Política de privacidad §6: describe la telemetría real (propia, en Cloudflare) en los 6 idiomas.

**Ficheros:**

| Fichero | Cambio |
|---|---|
| `vercel.json` | Redirecciones `/` → `/xx/` por `Accept-Language` (solo si no hay cookie `lang`); `/privacy_content` → `/privacy`; cabeceras de seguridad; caché para `/_astro/*` e `/images/*` |
| `src/layouts/Layout.astro` | `canonical` + `hreflang` ×6 + `x-default`; OG/Twitter completos con URL absoluta; `apple-itunes-app`; `theme-color`; `html.js`; tema antes del primer pintado (guardado o del sistema); Google Fonts no bloqueante; `<slot name="head">` |
| `src/styles/global.css` | Variables `--accent*` AA por tema y clases `.text-accent*`; `.btn-secondary` legible; overrides de marca en claro (cian, teal, indigo, rosa, violeta); reveal solo bajo `html.js`; `:focus-visible`; `.skip-link`; galería pausable; `.ribbon-pro`; reduced-motion también para el scroll |
| `src/components/HomePage.astro` | Skip link; `main#main`; ARIA en menús/tema/idioma; alts localizados y `width/height` en 31 imágenes; `fetchpriority="high"` en el hero; CTA secundario; botón de pausa de galería; acentos AA en 9 piezas de texto; sr-only en enlaces externos; script con estados y Escape; cookie `lang` |
| `src/i18n/translations.ts` | +14 claves ×6 (a11y, galería, alt) y `privacyAnalyticsText` reescrito ×6 |
| `src/pages/invite.astro` | Validación de `c`, decode tolerante, `<main>`, chips legibles, botón secundario compartido |
| `src/pages/404.astro` | Nuevo |
| `src/components/PrivacyPage.astro` · `TermsPage.astro` · `SupportPage.astro` | svg decorativos ocultos; enlaces `mailto` subrayados (distinguibles sin color) |
| `src/middleware.ts` | **Borrado**: no se ejecutaba en producción (páginas prerenderizadas); `invite.astro` detecta el idioma por su cuenta |
| `public/index.html` | **Borrado**: landing legada «Neto» |
| `src/pages/privacy_content.md` → `privacy_content.md` | Movido fuera de `pages/` (deja de ser ruta) |

**Un cambio que toca identidad y conviene mirar con ojo de dueño:** el texto de acento en tamaños pequeños
(badge «Finanzas, resueltas.», subtítulos de Yala IA y Grupos, botón secundario) pasa de `#6366F1` a `#818CF8`
en oscuro. El h1, los precios y los títulos siguen con el indigo de marca. Es un ajuste de una variable
(`--accent`) si se prefiere otro tono.

## 8. Verificación: antes y después

| Comprobación | Antes | Después |
|---|---|---|
| axe (home, oscuro, contenido forzado visible) | 0 violaciones | 0 |
| axe (home, **claro**) | **16** color-contrast | **0** |
| axe (soporte / privacidad / invitación) | 0 / 1 (`link-in-text-block`) / 3 (contraste chips, sin `main`, regiones) | 0 / 0 / 0 (pendiente re-medir invitación en el preview) |
| Lighthouse móvil (build estático) | 89 / 100 / 100 / 100 | **94** / 100 / 100 / 100 |
| FCP / LCP / CLS | 2,6 s / 3,2 s / 0 | **0,9 s** / 3,2 s / 0,012 |
| `npm run build` | ✓ (con el warning de `Astro.request.headers`) | ✓ sin warnings |
| Paridad i18n de claves nuevas | — | 14 claves × 6 = 84, ninguna `undefined` en el HTML generado |
| `bash qa/validate-coverage.sh` | — | `RESULT: OK` |
| `/invite?m=%ZZ` | 500 | 200 |
| `/privacy_content` en el build | generado | no existe (+ redirección 308) |
| `hreflang` / `canonical` en `/en/` | 0 / no | 7 / `https://yala-app.pe/en/` |

**Lo que solo Vercel ejecuta** (redirección por `Accept-Language`, cabeceras, 308 de `/privacy_content`) se
verificó hasta donde esta sesión pudo llegar:

- **Medido:** el `vercel.json` sí entró en el deploy. `.vercel/output/config.json` del build prebuilt contiene
  las 5 redirecciones con `has: accept-language` + `missing: cookie lang` (status 307), la 308 de
  `/privacy_content`, las cuatro cabeceras y la caché de `/_astro/*`. Y el mecanismo funciona en producción hoy:
  la cabecera del `apple-app-site-association` y la 308 de `yala-pe.com` vienen del mismo fichero
  (`curl -sI https://yala-pe.com/` → `308` a `yala-app.pe`).
- **No medido de punta a punta:** el preview tiene **protección SSO de Vercel** (todo `curl` sin sesión recibe
  `302` a `vercel.com/sso-api`) y esta sesión no tiene el login de Jürgen. Los pasos de §10 lo cierran en dos
  minutos desde un navegador con sesión en Vercel.

## 9. Qué queda pendiente y por qué

1. **Texto legal de Grupos (L2) — decisión del owner.** La web afirma en cuatro sitios y seis idiomas que los
   datos de un grupo viajan solo por iCloud/CloudKit. El repo tiene un backend propio de Grupos activo al 100 %
   en producción. No reescribí ese texto porque (a) es legal, (b) no he verificado qué ruta recorre hoy el dato de
   un usuario real, y (c) el cambio debe ir alineado con la ficha de la App Store (`marketing/`, que es de Lola)
   y las *nutrition labels*. **Paso concreto:** confirmar con el código de `GroupsSyncClient` qué se envía al
   gateway y reescribir `groupsBullet3`, `groupsNote`, `faq9A`, `privacyGroupsText` y `termsDataText`.
2. **Revisión legal (L1 y L2).** Jürgen lo revisa al lanzar 2.1.
3. ~~Revisión legal de §6 «Analítica anónima»~~ — Lo reescribí porque lo anterior era falso; sigue siendo un
   borrador. Confirmar además si Cloudflare debe figurar como encargado del tratamiento (RGPD) junto a OpenAI.
4. ~~**Autoalojar las fuentes**~~ — **hecho el 2026-09-04** (§11.7). Texto original: Hoy se carga de Google Fonts: manda la IP del visitante a Google (sentencia de
   Múnich 2022, relevante para DE/FR/IT/PT) y sigue siendo la principal dependencia externa. Lo dejé porque
   supone meter binarios woff2 en el repo o una dependencia (`@fontsource/inter`), y porque cambiar la tipografía
   (p. ej. a la del sistema, que en iPhone es la de la app) es una decisión de identidad. Con la carga no
   bloqueante el impacto en FCP ya está resuelto.
4. **LCP 3,2 s.** La imagen del hero es un JPEG de 860×1869 y 224 KB que se muestra a 320 px de ancho. Con
   `<Image>` de Astro (WebP/AVIF + `srcset`) o regenerando el asset a 640 px, LCP bajaría del umbral de 2,5 s.
   No lo hice porque `REDISENO-WEB-2.0.md` dejó explícitamente `sips` como pipeline y cambiarlo toca 32 assets.
5. **Prueba social.** Esperar a tener valoraciones suficientes; cuando las haya, un badge con cifra + fecha y
   `SoftwareApplication` JSON-LD con `aggregateRating` real.
6. **CTA fijo en móvil y vídeo demo.** Hipótesis razonables sin dato propio; la sección de vídeo ya está
   preparada (comentada) en `HomePage.astro`.
7. **Content-Security-Policy.** Requiere inventariar scripts inline y orígenes; una CSP equivocada rompe la web
   sin error visible. Mejor como cambio propio con su preview.
8. **Enlace a la App Store con país (`/pe/`).** Apple redirige el enlace sin país al storefront por geo-IP (medido:
   `apps.apple.com/app/id6758253109` → 301 a `/us/`). No hay doc de Apple que prescriba una forma; lo dejé como
   está. Si el mercado prioritario deja de ser Perú, revisar.
9. **`og-image.png` no se regeneró** (ya pendiente en `REDISENO-WEB-2.0.md`).

## 10. Cómo revisar el preview

1. Abre **https://yala-awn0b3ri7-jur211296s-projects.vercel.app** en el Mac. Debe verse la home en español con dos botones en el hero.
2. Pulsa el icono de sol (arriba a la derecha) para pasar a **modo claro**: fíjate en el badge «Pro» de la
   sección Yala IA, en «Con Yala» y en «Lo que SÍ hacemos» — antes eran cian casi blanco; ahora se leen.
3. Baja hasta la galería y pulsa **«Pausar galería»**: se detiene y puedes arrastrarla. Vuelve a pulsar para
   reanudar.
4. Pulsa **Tab** una vez desde el principio de la página: aparece «Saltar al contenido» arriba a la izquierda.
   Sigue con Tab: cada botón y enlace muestra un anillo de foco.
5. Prueba el idioma: en Terminal,
   `curl -sI -H "Accept-Language: en-US,en;q=0.9" https://yala-awn0b3ri7-jur211296s-projects.vercel.app/ | head -3` → debe responder `307`/`308` con
   `location: /en/`. Sin cabecera → `200` (español). Y `curl -sI https://yala-awn0b3ri7-jur211296s-projects.vercel.app/privacy_content | head -3` →
   `308` a `/privacy`.
6. Cabeceras: `curl -sI https://yala-awn0b3ri7-jur211296s-projects.vercel.app/ | grep -iE "x-content|referrer|x-frame|permissions"` → cuatro líneas.
7. En el **iPhone**, abre el preview en Safari: arriba debe aparecer el banner nativo de Yala («Abrir» o «Ver»).
   Nota: el preview **pide login de Vercel** (protección SSO): entra una vez con tu cuenta y el resto de pasos
   funcionan en ese navegador. Los `curl` de los pasos 5 y 6 necesitan la cookie de sesión, así que hazlos desde
   las DevTools (pestaña Network, recargando con «Disable cache») o directamente tras el merge contra
   `https://yala-app.pe`.
8. Invitación: `https://yala-awn0b3ri7-jur211296s-projects.vercel.app/invite?n=Viaje%20a%20Cusco&c=8B5CF6&m=Ana,Luis&u=Camila&i=airplane` — chips
   con texto claro; y `https://yala-awn0b3ri7-jur211296s-projects.vercel.app/invite?m=%ZZ` ya no da error.
9. Si algo no convence (el tono `#818CF8` del acento, el tema del sistema por defecto), son una línea cada uno:
   `--accent` en `global.css` y el script del `<body>` en `Layout.astro`.

---

## 11. Rediseño (2026-09-04): de auditar a rehacer la home

Tras la auditoría, Jürgen pidió una propuesta de rediseño: menos «landing hecha con IA», más producto con
criterio. Se trabajó así:

1. **Diagnóstico del look plantilla**: aurora con blobs, cards de cristal, texto en degradado, bento de 10
   iconos, comparativa ✗/✓, marquesina de capturas, cinco acentos a la vez.
2. **Dos direcciones en un canvas** (A · sobrio editorial, claro y serif; B · cálido con color local, oscuro
   y bloques de color), ambas con la misma estructura nueva y el hero interactivo funcionando. Jürgen eligió
   **B**, con dos correcciones: el indigo vuelve a ser el color principal (botones y Pro) y el rosa se queda
   en un solo golpe («hiciste.»); el crema/ámbar se sustituye por **teal profundo** en los dos temas.
3. **Revisión adversarial con tres lentes sin contexto** (una persona de Lima que quiere «controlar sus
   gastos», una de Madrid escéptica con la privacidad, un diseñador de producto). Se cruzaron, se refutó lo
   que no se sostenía y se incorporó lo que las tres vieron por separado (§11.2).

### 11.1 Qué cambia para quien entra en la web

- **Hero que enseña el producto**: una caja donde el visitante escribe un gasto —«gasté 24 soles en pizza
  con amigos»— y ve aparecer el registro como en la app (monto, categoría, cuenta). Es un parser de ~40
  líneas en el navegador, sin red; la app real usa su propio motor. Debajo: «Yala es la app para anotar
  gastos en lo que tarda el vuelto», el botón de descarga y dos líneas de hechos («Gratis. Sin registro. No
  se conecta a tu banco.» · «Solo iPhone, iOS 26 o superior»).
- **Orden que cuenta el bucle**: Anota → Entiende → Pregunta (Yala IA, Pro) → Comparte (Grupos, Beta) →
  Privacidad → Por qué existe Yala → Planes → Dudas → cierre.
- **Anota**: tres formas con la captura real; incluye la que faltaba y más preguntan en Perú: compartir a Yala
  la captura de Yape/Plin o del estado de cuenta con varios movimientos (extensión de compartir `YalaShare`;
  lectura de varias transacciones por imagen, strings `image.hintBankScreenshots` / `image.hintMultiple`).
- **Entiende**: un número (salud financiera 99/100), −49 % de gasto vs. el mes pasado, 30 movimientos — todas
  de la misma captura, sin mezclar meses.
- **Yala IA** como conversación en texto (cifras de la captura real), nota corta sin proveedor y enlace a
  Privacidad — decisión del owner.
- **Grupos** con un caso concreto (Viaje a Cusco, quién debe a quién), marcado como ejemplo.
- **Privacidad en tres frases**, coherentes con la FAQ (los tipos de cambio también salen).
- **«Por qué existe Yala» firmado**: Jürgen · Lima, Perú, y «En la App Store desde marzo de 2026» (fecha
  medida en la App Store: `releaseDate 2026-03-03`).
- **Planes** con lo que dos lentes preguntaron: 1 mes de prueba (StoreKit `introductoryOffer P1M free`) y
  «si dejas Pro conservas tus datos; solo se apagan las funciones Pro».
- **Seis dudas** en vez de nueve, incluidas Yape/Plin/tarjeta, «¿solo iPhone?» y «¿y si dejo de pagar Pro?».
- **Móvil**: botón «Descargar gratis» fijo abajo cuando el del hero sale de pantalla.
- **Sistema visual**: fondo sólido (slate de marca / casi blanco), titulares en Bricolage Grotesque, indigo
  como único color de acción, teal para los dos bloques de producto, rosa solo en «hiciste.». Sin aurora, sin
  cristal, sin degradados, sin iconos decorativos, sin marquesina.

### 11.2 Lo que la revisión adversarial cambió (y lo que se refutó)

| Hallazgo (lentes) | Qué se hizo |
|---|---|
| «¿Y mi Yape/Plin/tarjeta?» (Lima #1) | Forma 2 de anotar + FAQ 1, con la función real de compartir capturas |
| «¿A quién manda la IA mis datos?» (Lima, Madrid) | Nota corta + enlace a Privacidad; el owner decidió no nombrar al proveedor en la home |
| «¿Hay Android? ¿qué iPhone?» (las dos personas) | «Solo iPhone, iOS 26 o superior» bajo el botón y en FAQ |
| «¿Qué pasa si dejo Pro? ¿hay prueba?» (las dos) | Línea bajo el precio + FAQ 6, verificado en StoreKit |
| «¿Quién más la usa?» (las tres) | Sin cifras (4 valoraciones hoy); «En la App Store desde marzo de 2026» + contacto en el pie |
| El hero no dice qué es en 3 s (las tres) | Subtítulo explicativo justo bajo «Ya la hiciste.» |
| «Sin tarjeta · sin cuenta · sin banco» se lee como «no maneja cuentas» (dos) | «Gratis. Sin registro. No se conecta a tu banco.» |
| Cifras que se contradicen (dos) | Una captura por sección; fuera «está en riesgo» junto a «99» |
| «Ninguna es un formulario» junto a un formulario (diseñador) | «Ninguna toma más de diez segundos» |
| Ámbar le gana al indigo; cinco colores (diseñador + owner) | Teal profundo en los dos bloques; indigo único color de acción |
| Kickers numerados, chip repetido, teléfono saliente ×2 (diseñador) | Sin números; input ya relleno y tres chips distintos; teléfonos dentro del bloque en móvil |
| Contrastes en texto pequeño (diseñador) | Tokens `--v3-*` con ratios anotados; axe 0/0 |
| Refutado: «en España "ya la hiciste" es "la has liado"» | Es la marca y el mercado principal es Perú; el subtítulo lo desambigua |
| Refutado: «página de ancho fijo» | Era la maqueta; la implementación es fluida (medido a 390 px: sin desbordes) |

### 11.3 Verificación del rediseño

| Comprobación | Resultado |
|---|---|
| `npm run build` | ✓ · paridad i18n de las 84 claves nuevas × 6 = 504, 0 `undefined` |
| axe-core 4.10 (contenido visible, transiciones congeladas) · oscuro / claro | **0 / 0 violaciones** |
| Lighthouse móvil (build estático local) | **92** / 100 / 100 / 100 · FCP 0,9 s · CLS 0,002 · LCP 3,4 s (imagen hero, pendiente §9.4) |
| Móvil real a 390 px (Chrome) | `scrollWidth` 382, ningún elemento desborda; H1 44–56 px; una columna |
| Fuentes cargadas | Bricolage Grotesque + Inter (Google Fonts, no bloqueantes) |
| Prueba en vivo | «gasté 24 soles en pizza con amigos» → Pizza con amigos · Restaurantes · Efectivo · S/ 24.00 |

**Lo que no se hizo y por qué:** capturas nuevas del simulador (Jürgen lo ofreció; las actuales bastan si
cada sección usa una sola) — queda como opción si se quiere un nombre de usuario distinto o cifras únicas en
toda la página; y el vídeo demo, la prueba social y el resto de §9 siguen igual.

### 11.4 Capturas nuevas del simulador (2026-09-04) y lo que corrigieron

Jürgen ofreció el simulador; se rehízo el set entero (ES y EN) con semilla determinista, usuaria
**Camila**, período **Últimos 30 días**. Receta y ficheros: `Web/Screenshots/v3-2026-09-04/README.md`.

**Dos afirmaciones de la web resultaron falsas al medirlas en la app**, y las dos se corrigieron:

1. **«Escríbelo: "24 en pizza" basta: monto, categoría y cuenta quedan puestos.»** La pantalla de nuevo
   registro **no** interpreta lenguaje natural libre — comprobado escribiendo «Taxi al aeropuerto» en la
   descripción: el monto se queda en 0.00. Lo que ofrece es `@cuenta !categoría #etiqueta`. El copy pasa a
   describir eso. Y la caja interactiva del hero, que sí parsea una frase entera, declara ahora lo que es:
   **Yala IA, función Pro** (el lenguaje libre vive en Yala IA y en voz, ambas Pro).
2. **El saludo «Hola, Camila» del hero** no existe en la app actual: `panel.greeting` está en `L10n` y no
   lo usa ningún view. La captura anterior venía de una versión previa; el alt se reescribió sin él.

**Las cifras del copy ahora salen de la captura que tienen al lado** (antes mezclaban tres capturas y se
contradecían): salud financiera **95**/100, **27 movimientos** en 30 días, **S/ 66.55** de gasto diario
medio, gastos S/ 2,063; y las deudas del grupo son las tres filas que muestra la pantalla Balances
(Beto→Ana S/ 30 · Ana→Camila S/ 80 · Beto→Camila S/ 110).

**Dos límites en inglés, documentados y no disimulados:** los nombres de los gastos del grupo y el del
grupo son datos de la semilla, en español (son datos de usuario, no interfaz); y la captura de grupo en EN
usa la pestaña **Gastos** en vez de **Balances**, porque en Balances el miembro actual sale como «Tú» y el
nombre del perfil no se propaga a esa fila sin volver a sembrar.

**Medido tras el cambio:** imágenes de 860 → 620 px de ancho (1,0 MB las ocho) · Lighthouse móvil
**95**/100/100/100 · LCP 3,4 s → **2,9 s** · CLS 0,001 · axe **0 violaciones** en oscuro y claro.

### 11.5 Ajuste de ritmo: un solo bloque teal

La primera versión implementada puso los dos bloques de producto («Anota» y «Entiende») en teal, seguidos
y con la misma composición. Jürgen lo señaló: no era ritmo, era repetición, y en móvil eran dos torres de
~1000 px. **«Entiende» pasó a sección abierta**, así la página alterna bloque → abierta → bloque indigo →
abierta, y el teal vuelve a ser un acento. En móvil el bloque lleva menos padding y el teléfono más pequeño.

### 11.6 Dos ajustes finales del owner

- **Oscuro por defecto.** La auditoría había hecho que la web siguiera el tema del sistema; Jürgen lo
  revirtió: oscuro siempre, y el claro solo si el visitante lo elige aquí (se recuerda). El script sigue
  antes del contenido, así que no hay parpadeo. Esto cierra la decisión que §9 dejaba abierta.
- **La tarjeta del resultado del hero era blanco puro sobre el slate** — el punto más brillante de la
  página, compitiendo con el titular. Pasa a superficie oscura `#16203A` (texto 15.4:1, meta 6.3:1, icono
  teal translúcido); en claro se queda blanca, que ahí sí es la superficie natural. axe: 0 violaciones en
  ambos temas.

### 11.7 Que las máquinas la lean bien: estructura, datos estructurados y fuentes propias

**Lo que ya estaba bien** (medido sobre el HTML servido, sin ejecutar JavaScript, que es como entran
Google y la mayoría de lectores de IA): **4.762 caracteres de texto real** —la página no depende de JS—,
**un solo `<h1>`**, siete `<h2>` (uno por sección) y los `<h3>` colgando del suyo, sin saltos de nivel;
`header`/`nav`/`main`/`footer` únicos; las cifras y la FAQ en `<dl>/<dt>/<dd>` y la cita en
`<blockquote>`; canonical, 13 `hreflang`, meta description, `og:image` absoluta, sitemap y `robots.txt`
abierto.

**Dos huecos, ya cerrados:**

- **No había datos estructurados.** Ahora hay JSON-LD con `Organization`, `WebSite` y
  `MobileApplication`: qué es la app, para qué sistema (iOS 26+), quién la publica, desde cuándo
  (2026-03-03) y los dos planes con su precio. **Sin `aggregateRating`** — la nota de la App Store es
  real (5,0) pero se apoya en 4 valoraciones; decisión del owner: se añade cuando haya volumen.
- **No había `llms.txt`.** Se añadió: qué es Yala y qué no es, las cinco formas de anotar un gasto, la
  postura de privacidad y el mapa de páginas, en texto plano. `robots.txt` lo apunta.

**Fuentes propias (cierra el pendiente §9.3).** Inter y Bricolage se sirven desde `yala-app.pe`; no queda
ninguna llamada a Google en el HTML. Motivo: cargarlas de Google manda la IP del visitante a Google, y eso
costó una condena en Múnich (LG München I, 20-01-2022) — Yala vende en DE/FR/IT/PT.

**El coste, dicho sin adornos: Lighthouse móvil baja de 95 a 86** (LCP 2,9 → 3,9 s). Esos bytes siempre
existieron; venían de otro dominio y en diferido, así que la métrica no los contaba. Para amortiguarlo se
sirven **tres caras y no seis** (Inter 500 y 700 caen a 400 y 600; la cita pasa de Bricolage a Inter):
170 KB en la primera visita y caché de un año. La imagen del hero baja de 141 a 114 KB. Accesibilidad,
buenas prácticas y SEO siguen en 100, y axe en 0 violaciones en los dos temas.

Si en algún momento pesa más la métrica que el argumento legal, volver a Google Fonts es revertir un
commit; y el camino intermedio —subsetear las caras a los caracteres que la web usa de verdad, con
`pyftsubset`— recortaría ese 170 KB a la mitad, pero pedía instalar `fonttools` en esta máquina y no lo
hice.
