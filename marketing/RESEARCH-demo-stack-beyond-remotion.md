# Más allá de Remotion — ¿hay algo más potente y más listo para las demos de Yala?

**Investigación, 2026-09-15. Solo lectura: no toca código de la app, ni Swift, ni Web, ni
`marketing/remotion/`.** El encargo era buscar herramientas *más potentes y más inteligentes*
que Remotion sin salirse de la línea de producto de Yala: **CAPA A** = grabación real del
iPhone, innegociable; **CAPA B** = motion encima; sistema diario que saque 9:16 y 16:9.

Todo precio, versión y fecha de aquí está fechado y enlazado en § 7. Lo que **medí** y lo que
**inferí** van marcados por separado — en este repo la documentación envejece más rápido que
el código.

---

## 1 · Recomendación ejecutiva

**Híbrido, y el cambio va en la CAPA A — Remotion se queda.** Ninguna herramienta de
vídeo-por-código le gana hoy: Motion Canvas no publica release estable desde diciembre de 2024,
Revideo sigue en 0.11.0, y Cavalry —que sí es más potente— dejó el render por CLI detrás de una
licencia Enterprise. Remotion publicó 4.0.524 el 12 de septiembre; el repo va una versión por detrás.

Lo que sí existe fuera es algo **más listo aguas arriba**. El paso más caro del bucle de Yala no
es animar: es **medir `focusY` con ffmpeg y un píxel de regla** — nueve medidas a mano para 16
segundos de piloto. Screen Studio deriva ese encuadre solo, **recalcula los zooms al exportar en
vertical** y graba el iPhone por USB, que de paso mata la píldora roja de grabación.

Y hay que decirlo claro: **el piloto no falló por falta de motor.** El teléfono ocupa 722 px de
1080 y la UI de la app se ve al **59 % de la escala que tenía en el móvil que la grabó**. Eso son
dos números en `layout.ts`, no un cambio de herramienta.

**Plan:** semana 1 arreglar geometría (0 $), semana 2 probar Screen Studio un mes suelto (29 $). Si
el clip no para el pulgar en mute, no se ha gastado nada.

---

## 2 · El punto de partida, medido

Antes de comparar con nada hay que saber contra qué se compara. Estos números salen de leer
`marketing/remotion/` en el árbol de hoy, no de la memoria.

### Lo que ya funciona y ninguna alternativa iguala

| | |
|---|---|
| **Props bilingües** | `text: { es, en }` en `copy.ts`. Un render por idioma, mismo árbol. Ninguna app de timeline hace esto sin duplicar el proyecto |
| **Un origen, dos lienzos** | `FeatureDemo-9x16` y `-16x9` comparten plantilla y guion |
| **Git de verdad** | El guion es un `.ts` que se revisa en un diff. Cambiar una palabra es un commit, no un fichero binario de 300 MB |
| **Agente nativo** | Claude Code escribe la composition. Remotion mantiene Agent Skills oficiales (`npx remotion skills add`) |
| **Determinismo** | `useCurrentFrame()`. El render de hoy es idéntico al de dentro de un año |
| **Coste** | 0 $. Licencia libre hasta 3 personas, confirmado en la página de Remotion |

### Lo que el piloto hace mal — y no es culpa de Remotion

**Calculado desde `layout.ts` y `copy.ts`. No medido sobre un render: confírmalo en Studio con
`showSafeAreas: true` antes de tocar nada.**

1. **El teléfono es pequeño.** `PHONE.screenWidth = 690` + `bezel 16` ⇒ **722 px de ancho sobre
   un lienzo de 1080 = 67 %**. La pantalla sola son 690/1080 = 64 %.

2. **La UI de la app se ve al 59 % de su tamaño original.** El origen es `1170×2532`; se dibuja a
   690 px de ancho ⇒ **690/1170 = 0,59**. Un texto de 17 pt en el iPhone que grabó pasa a leerse
   como ~10 pt en el Reel, que se ve *en otro iPhone del mismo tamaño*. Los nueve `shots` del
   piloto van de `scale: 1.0` a `1.22`, con mediana 1,10 ⇒ **la app pasa dos tercios del clip por
   debajo del 67 % de su escala nativa** (hace falta `scale: 1.14` solo para llegar a ese 67 %).
   **Este es el «teléfono pequeño» del feedback, y es aritmética, no gusto.**

3. **El fondo del teléfono se lo come Instagram.** `phoneHeight` da ~1398 px y el teléfono arranca
   en `phoneTop: 520`. `REELS_SAFE.bottom = 400` ⇒ de y=1520 para abajo lo tapa la UI de Instagram.
   Aplicando `phoneTransform` plano a plano, la parte del teléfono que cae bajo esa línea o
   directamente fuera del lienzo va del **8 % al 41 % según el plano** — **38 % en el plano de
   apertura** (focusY 0,40 / scale 1,02: el teléfono ocupa de y≈639 a y≈2066) y 41 % en el de 8,4 s.
   `SafeAreas` existe y restringe el TEXTO (`REELS_TEXT`), pero **nada restringe el teléfono**.

4. **Los rótulos no son finos — son finos *en relación al teléfono*.** `heroPx: 104` sobre 1080 de
   ancho es 9,6 %, y ya se subió una vez desde 64. El problema de composición es que el teléfono
   se queda el centro y al texto le toca una banda. No es el tamaño de la fuente.

**Conclusión del diagnóstico: tres de los cuatro problemas se arreglan con números, no con
herramientas.** Cualquier evaluación que empiece por «hay que cambiar de motor» está saltándose
esto. Por eso la semana 1 del plan de § 6 no compra nada.

---

## 3 · Comparativa contra Remotion

«Calidad» = techo de lo que se puede conseguir con esfuerzo, no lo que sale por defecto.
«Encaje git/Claude Code» = ¿el artefacto se revisa en un diff y lo escribe un agente sin manos?

| | Calidad de motion | Ayuda de agente / IA | Curva | Props bilingües | Reels 9:16 | Coste / licencia | Encaje git + Claude Code |
|---|---|---|---|---|---|---|---|
| **Remotion 4.0.524** *(actual)* | Alta. Springs, easing, 3D CSS. Techo = lo que sepas de CSS | **Agent Skills oficiales.** El MCP está deprecado a favor de `/remotion-docs` | Media si sabes React | **Nativo** — props tipados | Composition de 1080×1920 | **0 $ ≤3 personas.** Luego 25 $/asiento/mes o 0,01 $/render (mín. 100 $/mes) | **El mejor del cuadro.** TS en el repo |
| **Screen Studio 3.7.5** | Alta *en su nicho*: zoom automático, suavizado de cursor, motion blur. Fuera de ahí, no hace nada | Ninguna. **Sin API, sin CLI** | Muy baja | No. Un proyecto por idioma | Preset `Vertical` que **recalcula los zooms** | **108 $/año o 29 $/mes.** Sin licencia perpetua desde oct-2025 | **Malo.** Binario opaco. En mantenimiento: 3.7.x son cinco parches sin función nueva desde feb-2026 |
| **ScreenKite 1.18** | Media-alta. Frames SVG, `magicMove`, B-roll generado | **83 herramientas MCP.** Claude Code / Codex conducen el editor | Baja | No documentado | Sí, export manual | **Gratis con marca de agua; 79,99 $ pago único** (3 Macs) | **Bueno en intención, opaco en formato.** `.skbundle` no es un diff |
| **After Effects + puente MCP** | **La más alta del cuadro.** Es el estándar | Puentes MCP de comunidad sobre CEP/ExtendScript. UXP **no** expone el DOM de AE | **Alta.** Meses | Con expresiones y scripting | Sí | Suscripción Adobe + el puente | **Malo.** `.aep` binario. Y el puente pilota una app abierta |
| **Cavalry 2.7** | **Muy alta.** Procedural, data-driven, rigs | API JS completa (`api.create`, `keyframe`, `magicEasing`) | Alta | Por script | Sí | **Gratis para individuos** desde abr-2026 (Canva) | **Se cae por el render.** `Cavalry CLI render` **requiere Enterprise**, y la doc avisa de que el CLI no está disponible en 2.7+ |
| **DaVinci Resolve Studio 21.1 + Fusion** | Muy alta | API Python, `-nogui` headless | Alta | Por script | Sí | **295 $ perpetuo.** La API **no existe en la versión gratis** | **Regular.** Scripting sí, pero el proyecto vive en una base de datos |
| **Apple Motion 6.3** | Alta, y es la estética de referencia | **Prácticamente nula.** Solo responde a `activate`, `open`, `quit` | Media-alta | No | Sí | Pago único | **Malo.** Solo editando el XML `.motn` a mano |
| **Rotato** | Alta **solo** en el dispositivo 3D | Ninguna | Baja | No | Sí | Pago único (Pro Premium listado a 239 $ — **verificar**) | **Malo**, pero exporta **alpha/8K**: encaja como capa, no como sistema |
| **Jitter** | Alta. Muy «Apple» de fábrica | **Superagents** (jul-2026): redimensionar, traducir, variantes | Baja | **Traducción automática** por IA | Sí | Gratis con marca de agua; de pago por créditos | **Malo.** SaaS, proyecto en la nube |
| **Revideo 0.11.0** | Media. Menos ecosistema que Remotion | «Claude o Codex pueden producir una escena» (su README) | Media | Por código | Sí | Open source | Bueno — **pero sub-1.0 y de una sola empresa** |
| **Motion Canvas** | Media | No | Media | Por código | Sí | MIT | **Descartado: última estable 3.17.2, dic-2024** |
| **Plainly** | La de AE, en la nube | API REST + webhook | Media (necesitas AE igual) | Por parámetros | Sí | **Desde 48 $/mes anual** (50 min/mes) | Regular. Resuelve el render, no el diseño |

### Lo que dice la tabla

- **En su propia clase, Remotion gana y no está cerca.** `remotion` 4.0.524 se publicó el
  2026-09-12; `@motion-canvas/core` 3.17.2 el 2024-12-14. Son **21 meses** de diferencia en
  mantenimiento.
- **Lo más potente pierde por el mismo sitio: el artefacto.** AE, Cavalry, Resolve y Motion tienen
  techo más alto que Remotion. Los cuatro guardan el trabajo en un formato que no se revisa en un
  diff, y tres de los cuatro no rinden sin abrir la app. Eso mata «sistema diario» y mata
  «Claude Code lo escribe».
- **Cavalry es el más doloroso de descartar.** Es gratis desde abril de 2026, es procedural de
  verdad y tiene una API JS seria. Se cae por un detalle concreto: **el render por línea de
  comandos es de licencia Enterprise**, y su propia doc dice que el CLI no está en 2.7+.

---

## 4 · Los tres candidatos, a fondo

### 4.1 · Screen Studio — el que arregla el paso más caro **[recomendado para probar]**

**Qué es.** Grabador de pantalla de macOS que aplica diseño de movimiento en el export en vez de
en una timeline.

**Por qué entra aquí y no en la lista de descartes.** No compite con Remotion: compite con el
**paso 3 de `OPERACION.md`**, que hoy es:

```
ffmpeg -ss 8.4 -i public/footage/<slug>.mp4 -frames:v 1 /tmp/f.png
# abre /tmp/f.png, mide a qué altura está el elemento (px / alto total)
# y aplica la fórmula
```

Eso se hizo **nueve veces** para el piloto. Screen Studio detecta los puntos de interés y genera
los keyframes de zoom solo; los manuales se arrastran por la timeline y se animan solos. Y —lo
importante para Yala— **al exportar en vertical reajusta todos los zooms** para ese lienzo.

**Lo que resuelve de la deuda ya escrita en `OPERACION.md`:**

| Deuda apuntada | Qué pasa con Screen Studio |
|---|---|
| Píldora roja de grabación los 16 s | **Desaparece.** Graba el iPhone por USB, igual que QuickTime |
| `crop: { top: 0.05 }` como parche | Se recupera ese 5 % |
| Teléfono al 67 % | Su propio marco, con el modelo y el color detectados por USB — pero ojo: **esto ya se arregla gratis en la semana 1**, no hace falta comprar nada |
| Nueve `focusY` a mano | Automático o arrastrando |

**Lo que NO resuelve y hay que decirlo:** no habla ni español ni inglés — un proyecto por idioma,
y ahí se pierde la mejor propiedad del sistema actual. Por eso esto es **híbrido, no sustitución**:
Screen Studio entrega una *placa* (footage + marco + cámara ya horneados) y Remotion sigue poniendo
titulares, callouts, end card y safe areas desde `copy.ts`.

**El riesgo que hay que comprobar el día 1, y es serio.** La documentación describe el zoom
automático como disparado por **acciones del cursor** (clics, arrastres, campos). **En una
grabación de iPhone por USB no hay cursor.** No encontré ninguna fuente primaria que confirme que
el auto-zoom se dispare con toques en pantalla. **Si no se dispara, el zoom automático —que es
justo el motivo para comprarlo— no aplica al caso de Yala**, y queda solo el zoom manual animado,
que sigue siendo mejor que ffmpeg pero vale bastante menos. Esto es lo primero que se prueba.

**Más avisos honestos:**
- **Está en mantenimiento.** Cinco parches en la línea 3.7.x desde mayo sin una sola función nueva.
  El último cambio con nombre propio es de febrero de 2026.
- **La licencia perpetua ya no existe** para compradores nuevos (retirada en octubre de 2025). Son
  **108 $/año, a perpetuidad**. Sin reembolsos según sus términos.
- **Sin API y sin CLI.** El bucle diario gana un paso manual en una app con ratón.
- Solo macOS.

**Coste de probarlo:** **29 $** un mes suelto. Los 9 $/mes que se anuncian son el plan anual, y eso
son **108 $ por adelantado** — para una prueba de dos semanas no compensa. **Veredicto: la única
compra del informe que defendería.**

---

### 4.2 · After Effects + puente MCP — el techo de verdad, y por qué pierde igual

**Qué es.** El estándar de motion graphics, más un puente MCP de comunidad que deja a Claude Code
leer el proyecto, tocar keyframes y expresiones, **renderizar un frame y volver a mirarlo** para
corregirse.

**Por qué merece el hueco.** Es el único candidato del que se puede decir sin discusión que es
**más potente** que Remotion. Y en 2026 dejó de ser inaccesible para un agente: existen varios
servidores MCP con inspección, edición y render.

**Por qué pierde, en orden de gravedad:**

1. **El artefacto.** `.aep` es binario. Se acabó revisar el guion en un diff, y con él se acaba el
   `copy.ts` bilingüe. Es exactamente lo que Yala tiene y ningún competidor iguala.
2. **El puente pilota una app abierta.** No es render headless: es AE ejecutándose con un panel CEP
   conectado. Como sistema diario, eso es una pieza más que se cuelga.
3. **Todos los puentes son de comunidad.** Adobe no publica uno. Y **UXP, el marco nuevo de AE 2026,
   no expone el DOM**, así que todos pasan por CEP + ExtendScript — la vía antigua.
4. **La curva.** Meses, y la paga una persona.

**Dónde sí tendría sentido:** un único *hero* anual para la App Store, encargado fuera. Para el
Reel del martes, no.

---

### 4.3 · ScreenKite — el nativo agéntico: la apuesta interesante y la que más riesgo tiene

**Qué es.** Grabador y editor nativo en Swift para macOS que **expone su editor por MCP**: Claude
Code o Codex abren el proyecto, transcriben, planifican cortes, aplican zooms y exportan. 83
herramientas, cada una con dry-run: el agente propone, tú ves el cambio, luego se aplica.

**Por qué es conceptualmente lo más cercano a «más inteligente que Remotion».** Es la única
herramienta del informe donde el agente **conduce la edición del footage**, no solo escribe la capa
de encima. Y encaja en la CAPA A: graba iPhone y iPad por USB, detecta el modelo por la resolución
y aplica el marco —incluido iPhone 17 Pro con sus tres colores—.

**Pago único de 79,99 $ para 3 Macs.** Sin suscripción. Gratis para grabar y editar; la marca de
agua solo afecta al export.

**Por qué NO lo recomiendo como primera compra:**

1. **Su propia documentación se contradice sobre lo único innegociable aquí.** La guía
   «Recording iOS Devices» dice que graba iPhone por USB. Su página comparativa contra Screen
   Studio, en la misma web, pone **«iOS device recording: ScreenKite — No»**. Sobre la CAPA A no
   puede haber ambigüedad. Esto se comprueba antes de pagar nada.
2. **Sus benchmarks se comparan contra una versión que ya no existe.** La portada mide sus exports
   contra «Screen Studio 2.x». Screen Studio va por **3.7.5**, y la 3.5 trajo un motor de export
   nuevo con **exports hasta 4× más rápidos**. El número puede ser cierto; la comparación, como está
   publicada, no vale.
3. **Casi todo lo que se sabe sale de su propio marketing.** Proveedor pequeño, producto joven.
4. **`.skbundle` no es un diff.** Mismo problema de artefacto que AE, con menos años encima.

**Veredicto: vigilar, no comprar todavía.** Si en la prueba resulta que Screen Studio no hace
auto-zoom con toques de iPhone, ScreenKite pasa a ser el candidato número uno — y entonces la
pregunta 1 es lo primero que se resuelve.

---

### 4.4 · Mención aparte: Rotato, el seguro barato de la CAPA A

No es un sistema y no compite con nada de arriba, pero hace tres cosas que valen aquí:

- **Espeja y graba el iPhone por USB**, y pone el reloj a las **9:41 con batería llena y cobertura
  completa**, como pide la guía de Apple. Eso es la deuda de la status bar del piloto, resuelta de
  fábrica.
- **Exporta con transparencia** (ProRes 4444 / lossless, hasta 8K). Es decir: puede entregar **la
  capa del teléfono con alpha** y que Remotion la componga encima del fondo, sin horneado y sin
  perder `copy.ts`. Es el híbrido que menos rompe la arquitectura actual.
- Pago único, macOS 11+.

Su cámara es manual: no aporta la parte «inteligente». **Es plan B de la § 6, no plan A.**

---

## 5 · Kill list y trampas

### 5.1 · Kill list — no se evalúan, y por qué

| | Por qué se cae |
|---|---|
| **Sora 2 · Veo 3.x · Kling 3.0 · Runway · Wan · Higgsfield · Grok Imagine** | **Regla de la CAPA A.** Y además está medido: en 2026 *todos* los modelos siguen fallando con texto legible en pantalla. Las comparativas del año lo repiten literalmente: «rendering precise legible text in-frame remains weak». Una UI de finanzas es **texto denso con cifras**. El peor caso posible |
| **Runway Solaris / «generar la interfaz»** | Genera interfaces frame a frame sin DOM. Tecnológicamente notable, y **exactamente lo prohibido**: no sería Yala, sería un dibujo de Yala |
| **Motion Canvas** | `@motion-canvas/core` estable **3.17.2, 2024-12-14**. 21 meses. Lo único posterior es una alpha de feb-2025 |
| **Los pipelines de `video-shotcraft` / `ai-product-video`** | Ya está escrito en `OPERACION.md` y la investigación lo confirma: reconstruyen la app con capturas y traen la estética Ink Press. **Su catálogo de planos sigue sirviendo para decidir; su pipeline no** |
| **CapCut / plantillas de Reels** | Estética genérica. Yala tiene tokens 2.1 congelados |
| **Traducción por IA de vídeo (Higgsfield, ElevenLabs dubbing)** | Resuelve el idioma equivocado. El problema de Yala son **rótulos** bilingües, y eso ya lo hace `copy.ts` mejor y gratis |

### 5.2 · Trampas — el orden es de probabilidad de tropiezo

1. **«Gen-video solo para el pulido».** Es la trampa fina, porque suena razonable: no regeneras la
   UI, solo le pasas un modelo por encima «para que quede mejor». Un modelo vídeo-a-vídeo **repinta
   píxeles**, y los píxeles de Yala son cifras. Una coma que se mueve de sitio en el saldo es una
   captura falsa de un producto financiero. **La regla no es «no generar la UI»: es que ningún
   modelo generativo toque el rectángulo de la pantalla.** El B-roll de ambiente fuera del teléfono
   sigue permitido, como ya dice `OPERACION.md`.

2. **Hornear la cámara mata «un footage, dos salidas».** Si Screen Studio entrega la placa con el
   zoom ya dentro, el 16:9 no puede reencuadrar: son **dos exports por toma**. Es un coste real y
   va contra un principio escrito del repo. Pagable, pero hay que decidirlo a sabiendas.

3. **Marco doble.** Si la placa ya trae marco de dispositivo y `DeviceFrame` sigue puesto, sale un
   iPhone dentro de un iPhone. El seam tiene que ser explícito: **o el marco lo pone la placa, o lo
   pone Remotion. Nunca los dos.**

4. **GSAP y Framer Motion dentro de Remotion no animan: se congelan.** Remotion renderiza con un
   reloj sintético; todo lo que dependa de tiempo real —`requestAnimationFrame`, transiciones CSS,
   `Date.now()`— sale quieto en el mp4 **aunque se vea bien en el preview del navegador**. La doc
   oficial es explícita y no hay integración de Framer Motion prevista. Si la búsqueda de «motion
   más rico» acaba importando una librería de animación, este es el muro.

5. **SF Pro no se puede empaquetar.** Ya está en `LICENSE-NOTES.md`. Vale para cualquier
   herramienta nueva: una app de escritorio que *use* SF Pro instalada localmente es otra cosa que
   *redistribuirla* en un render. No lo resuelve cambiar de motor.

6. **La licencia de Remotion se mira por cabezas, no por uso.** Libre hasta **3 personas**. Y la
   letra pequeña de 2026 importa: un asiento cubre a quien escribe código de Remotion **«o usa
   herramientas de codificación agénticas»**. Hoy Yala entra en el uso libre; el umbral es el
   tamaño del equipo, no el volumen de vídeo.

7. **El auto-zoom puede no aplicar a grabaciones de iPhone.** Ver § 4.1. Es la hipótesis que hace o
   deshace la recomendación, y por eso es el día 1.

8. **La ficha de la App Store no acepta 1920×1080 para iPhone.** Si alguna de estas piezas va a ir
   de app preview: **886×1920**, 15–30 s, 30 fps, H.264 High Profile o ProRes 422 HQ, 500 MB máximo,
   y el poster frame por defecto cae en el **segundo 5**. HEVC se rechaza — que es justo lo que
   graban por defecto iOS y macOS. Hoy el repo saca 1080×1920 y 1920×1080: **ninguno de los dos
   sirve para el hueco de iPhone.**

---

## 6 · Prueba de dos semanas

Diseñada para que **la semana 1 no cueste nada** y para que, si la semana 2 falla, lo aprendido en
la 1 se quede igual.

### Semana 1 — arreglar lo que ya es de Yala (coste: 0 €)

Sin comprar nada, sin instalar nada. Sirve de **línea base honesta**: si el problema era la
geometría, se ve aquí y la compra de la semana 2 se cancela.

| # | Qué | Dónde |
|---|---|---|
| 1 | **Toma nueva del piloto**, en Liquid Glass oscuro, grabada desde QuickTime con el iPhone conectado — sin píldora roja. Es la deuda ya escrita | — |
| 2 | Quitar el parche `crop.top: 0.05` que la toma sucia obligaba a llevar | `copy.ts` |
| 3 | **Subir el teléfono** de `screenWidth: 690` a ~**920** (pantalla al 85 % del lienzo, 88 % con marco). La UI pasa de 59 % a **79 %** de su escala nativa | `layout.ts` |
| 4 | **Meter el teléfono en la zona visible**: hoy se pierde entre el 8 % y el 41 % según el plano. Ajustar `phoneTop` / `REELS_CAMERA.centerY` y **verificarlo con `showSafeAreas: true`**, que es lo que el punto 3 del diagnóstico deja sin confirmar | `layout.ts` |
| 5 | Renderizar `ia-gasto-pizza` en es y en. **Esta es la línea base contra la que se compara todo** | — |

**Puerta de salida:** si el clip de la semana 1 pasa el test de mute de § 6.2, **se cierra la
investigación y no se compra nada.** Es un desenlace posible y sería el mejor.

### Semana 2 — Screen Studio, con la pregunta que lo decide primero

| Día | Qué | Qué se decide |
|---|---|---|
| 1 | Suscribir 1 mes suelto (29 $ — **no el anual**). Grabar el iPhone por USB. **Comprobar si el auto-zoom se dispara con toques en pantalla** | **Si NO se dispara: parar.** El motivo de la compra no aplica; cancelar y evaluar ScreenKite con la pregunta de § 4.3 |
| 2 | Export `Vertical` 9:16 y `Wide` 16:9. Confirmar que reencuadra los zooms | Si hacen falta dos tomas por función, el coste diario sube |
| 3 | Decidir el seam: ¿marco de Screen Studio o `DeviceFrame`? **Uno de los dos, escrito** | Evita el iPhone dentro del iPhone |
| 4 | Meter la placa en `FeatureDemo` como fondo a sangre; Remotion solo rótulos + end card + safe areas | Confirma que `copy.ts` bilingüe sobrevive |
| 5 | Render de los dos idiomas × dos lienzos. **Cronometrar el bucle entero** | El número que decide: ¿menos de 10 minutos, como promete `OPERACION.md`? |
| 6–7 | A/B contra la línea base de la semana 1, en mute, en un teléfono | § 6.2 |

### 6.2 · Criterios de éxito — el test de mute

**La prueba:** clip de Yala IA Pizza, 9:16, **sin sonido**, en la pantalla de un iPhone, a alguien
que no conozca Yala. Dos variantes: semana 1 y semana 2.

**Pasa si, y solo si, las cuatro:**

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 1 | **Se entiende qué hace la app sin sonido y sin explicación** | La persona lo cuenta con sus palabras al acabar. Si hace falta una aclaración, no pasa |
| 2 | **La UI de la app se lee.** Las cifras y las categorías, en el teléfono, sin acercar los ojos | Es el fallo medido del piloto. Objetivo: ≥75 % de escala nativa |
| 3 | **Nada importante bajo la UI de Instagram** — ni texto, ni el gesto, ni la card estrella | `showSafeAreas: true` **y** una captura del clip en Reels de verdad |
| 4 | **Los primeros 3 segundos ganan solos.** Texto legible **en el frame 0**, no en el 20, y movimiento desde el principio | Los benchmarks de 2026 sitúan el skip de los 3 s entre el 25 % y el 35 %; por encima del 40 % el hook está mal |

**Métricas con fuente, para no discutir de gustos:**

- **Duración.** Los Reels de menos de 15 s retienen el **66 %** de su duración; los de más de 60 s,
  el **16,4 %**. El piloto va a 16 s + end card: **está en el filo. Recortar antes que alargar.**
- **Retención buena** en 2026: **>65 %** por debajo de 15 s, **>50 %** por debajo de 30 s.
- **Y un dato incómodo que no se puede ignorar:** en una muestra de 346 Reels, el texto sobreimpreso
  **subió** el engagement (7,6 % vs 5,7 %) pero **bajó** el watch ratio (36,6 % vs 45,8 %). O sea:
  el sistema entero de Yala está construido sobre «6–8 beats grandes», y esa decisión **compra
  interacción a cambio de retención**. Es una decisión defendible; no es gratis, y hasta ahora no
  estaba escrita en ningún sitio.

### 6.3 · Coste total y qué se lleva si sale mal

| | Coste | Qué queda si falla |
|---|---|---|
| Semana 1 | **0 $** | Toma limpia, geometría arreglada, línea base. **Se queda pase lo que pase** |
| Semana 2 | **29 $** (un mes suelto) | La respuesta a la pregunta del auto-zoom, que hoy no tiene nadie |
| **Total** | **29 $** | |

Si las dos pasan, se pasa al anual: **108 $/año**. Si se cancela el día 1, 29 $ y una hipótesis
resuelta. **No hay ningún escenario en el que esta investigación cueste más que una cena.**

**Plan B, si la semana 2 se cae el día 1.** Por orden, y solo si la semana 1 no bastó:

1. **Rotato** (§ 4.4) — pago único. No aporta inteligencia, pero resuelve la status bar de fábrica
   (9:41, batería llena) y puede entregar el teléfono **con alpha** para que Remotion lo componga.
   Es el híbrido que menos rompe la arquitectura: `copy.ts` y «un footage, dos salidas» sobreviven.
2. **ScreenKite** (§ 4.3) — empezando por resolver la contradicción de su propia documentación
   sobre si graba iPhone por USB. Es gratis probarlo: la marca de agua solo afecta al export.

### 6.4 · Lo que queda fuera a propósito

Para que nadie lo busque en este documento: voz (ElevenLabs sigue sin decidir, y § 5.1 explica que
no resuelve el problema bilingüe de Yala), el explainer `explainer-que-es-yala-ia`, y las piezas
para la ficha de la App Store, que necesitan **886×1920** (§ 5.2, trampa 8) y son un encargo
distinto.

---

## 7 · Fuentes

Consultadas el **2026-09-15**. Preferencia por documentación primaria; las terceras partes van
marcadas.

**Remotion**
- Licencia (primaria) — https://www.remotion.pro/license · https://www.remotion.dev/docs/license/faq
- MCP deprecado a favor de Agent Skills — https://www.remotion.dev/docs/ai/mcp
- Agentes de código — https://www.remotion.dev/docs/ai/coding-agents
- Librerías de terceros / animación por frame — https://www.remotion.dev/docs/third-party
- Recorder — https://www.remotion.dev/docs/recorder/is-it-for-me
- **Medido**: `remotion` 4.0.524 publicado 2026-09-12 (registry npm y GitHub Releases API)

**Screen Studio**
- Producto y grabación de iPhone por USB — https://screen.studio/
- Zoom automático — https://www.screen.studio/guide/auto-zoom
- Relación de aspecto (Vertical 9:16) — https://screen.studio/guide/aspect-ratio
- Changelog — https://screen.studio/changelog · versión 3.7.5-4595 en https://formulae.brew.sh/cask/screen-studio
- *Terceros* — precio 2026 y fin de la licencia perpetua: https://cursorclip.com/blog/cursorclip-vs-screenstudio/ · https://nubiapage.com/screen-studio-review-2026/ · «sin API»: https://thegtmdirectory.com/tools/screen-studio

**ScreenKite** *(todo del propio proveedor — leer con eso en mente)*
- https://www.screenkite.com/ · https://www.screenkite.com/guide/agentic-video-editing
- https://www.screenkite.com/guide/recording-ios-devices · https://www.screenkite.com/guide/device-frames
- La contradicción de § 4.3 — https://www.screenkite.com/compare/screen-studio-vs-screenkite

**Rotato** — https://rotato.app/features · https://rotato.app/pricing · https://rotato.app/ai-info

**After Effects + MCP** — https://glama.ai/mcp/servers/solomondivyananth/aftereffects-mcp · https://github.com/Fansist/MCP · UXP sin DOM de AE: https://community.adobe.com/questions-712/why-doesn-t-uxp-expose-a-direct-evalscript-like-api-to-run-existing-extendscript-jsx-files-1183642

**Cavalry** — https://cavalry.studio/ · API JS: https://cavalry.studio/docs/tech-info/scripting/api-module/ · **CLI = Enterprise**: https://cavalry.studio/docs/applications/cavalry-cli/ · *terceros*, gratis bajo Canva: https://www.cgchannel.com/2026/04/canva-makes-motion-graphics-and-animation-app-cavalry-free/

**DaVinci Resolve** — https://www.blackmagicdesign.com/products/davinciresolve (295 $) · API y `-nogui`: https://deric.github.io/DaVinciResolve-API-Docs/ · *terceros*, 21.1 sep-2026: https://www.cgchannel.com/2026/09/blackmagic-design-releases-resolve-21-1/

**Apple Motion / Final Cut** — notas de versión 6.3 (30-jun-2026): https://support.apple.com/en-gb/102746 · plantillas para FCP: https://support.apple.com/guide/motion/create-a-title-template-motn141bb14b/mac · scriptabilidad limitada a tres verbos: https://github.com/waliex3/motion-mcp-server

**Motion Canvas / Revideo** — https://github.com/motion-canvas/motion-canvas · https://github.com/midrender/revideo · **medido** en el registry npm: `@motion-canvas/core` 3.17.2 (2024-12-14), `@revideo/core` 0.11.0 (2026-07-10)

**Jitter** — https://jitter.video/product/ · Superagents: https://jitter.video/changelog/2026-07-09-ai-agents

**Rive** — export de vídeo: https://rive.app/docs/editor/exporting/exporting-for-video-and-static-design

**Plainly** — https://help.plainlyvideos.com/docs/developer-guide · https://www.plainlyvideos.com/pricing

**Apple — ficha de la App Store** — https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications

**Vídeo generativo (kill list)** — *todo de terceros*: https://www.web3aiblog.com/blog/ai-video-generation-models-compared-sora-veo-kling-runway-pika-2026 · https://adlibrary.com/posts/ai-video-ad-generators-comparison · https://ofox.ai/blog/ai-video-generation-apis-sora-veo-kling-compared-2026/ · Higgsfield: https://higgsfield.ai/ai-video

**Rendimiento en Reels** — *todo de terceros, muestras pequeñas, tratar como orden de magnitud*: 346 Reels: https://www.highviz.io/instagram-reels-report/ · skip rate: https://retensis.com/blog/instagram-reels-skip-rate-benchmarks-2026 · retención: https://retensis.com/blog/good-instagram-reels-retention-rate

---

## 8 · Qué NO se verificó

Para que nadie reutilice estas cifras como si estuvieran medidas:

- **Precios de Rotato, Jitter y Adobe**: leídos de páginas de producto o de terceros, no de una
  compra. El de Rotato (239 $ «Pro Premium») venía de un listado y **su propia página avisa de que
  hay que confirmarlo**.
- **Que Screen Studio haga auto-zoom con toques de iPhone**: **no confirmado**. Es la incógnita
  central del informe y el día 1 de la prueba.
- **Que ScreenKite grabe iPhone por USB**: su propia documentación se contradice.
- **Los benchmarks de export de ScreenKite**: se comparan contra Screen Studio 2.x, versión que ya
  no es la actual.
- **Los números de geometría de § 2**: **calculados leyendo `layout.ts` y `copy.ts`, no medidos
  sobre un render.** El del 8–41 % de teléfono perdido bajo la UI de Instagram es el que más cadena
  de cálculo lleva —hay que reproducir `phoneTransform` a mano— y el que más falta hace comprobar en
  Studio antes de mover un número.
- **Las cifras de Reels**: de blogs de herramientas de analítica con muestras pequeñas y con interés
  comercial. Sirven para fijar un objetivo, no para justificar una decisión por sí solas.
