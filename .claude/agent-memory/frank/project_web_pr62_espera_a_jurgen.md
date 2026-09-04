---
name: web-pr62-espera-a-jurgen
description: Revisión + rediseño de la web (PR #62, preview Vercel, 2026-09-03/04) — qué espera de Jürgen, qué decidió él y qué dejé sin tocar a propósito
metadata:
  type: project
---

**El PR #62 (`encargo/2026-09-03-revision-web-ux-a11y-preview`) espera a Jürgen: revisar el preview y
mergear.** Contiene la auditoría (3-sep) y el **rediseño de la home** (4-sep). Informe formal en
`Web/REVISION-WEB-UX-A11Y-2026-09-03.md` (§11 = rediseño). Preview con SSO:
`https://yala-54tv7bb0p-jur211296s-projects.vercel.app`. Canvas de las dos direcciones:
`https://claude.ai/code/artifact/838b792c-e494-444a-ae1a-237e505e7bfb` (él no pudo abrirlo; le sirvieron
las imágenes por `SendUserFile`).

**Why:** el encargo pedía preview y PR, nada en producción — aunque `CLAUDE.md` deja pasar `Web/` directo
a `2.1`, `2.1` es lo que Vercel publica; su encargo escrito ganó a la regla general. Y con «implementa lo
que consideres razonable» por escrito no esperé aprobación por «más de 3 ficheros».

**Lo que Jürgen decidió en la sesión del 4-sep (no volver a preguntar):**

- Dirección **B** (oscuro, bloques de color, Bricolage Grotesque) con **indigo como principal**, rosa solo en
  «hiciste.», y **teal profundo** en vez de crema/ámbar («el ámbar me chirriaba»), igual en claro y oscuro.
- Firma «Jürgen · Lima, Perú» en «Por qué existe Yala»: sí. **No** «la app hecha en Lima» como rótulo.
- Nota de Yala IA **corta y sin nombrar al proveedor**; enlace a Privacidad/Términos.
- Solo iPhone, iOS 26+ («de momento»). Al dejar Pro no se pierden datos; trial 1 mes (StoreKit P1M).
- Yape/Plin/estado de cuenta: se mencionan como captura compartida a Yala (share sheet, varios
  movimientos a la vez) — verificado en `YalaShare` y strings `image.hintBankScreenshots`.
- Autorizó capturas del simulador: se rehizo el set entero el 4-sep (ver [[capturas-simulador-para-la-web]]).
- **Oscuro por defecto** (revirtió el «tema del sistema» que puso la auditoría) y la tarjeta del hero sin blanco.
- Un solo bloque teal: dos seguidos eran repetición. Le importa el ritmo de la página, no solo el color.

**Lo que sigue siendo decisión suya (caduca cuando decida):**

- **Texto legal de Grupos (4 claves × 6 idiomas)** dice «vía iCloud, no por servidores nuestros»; el repo
  tiene backend propio de Grupos al 100 % en prod (`gateway/wrangler.toml:166`). Medido: existencia del
  backend y del flag. Inferido: qué ruta usa hoy un usuario. No reescribo texto legal sin su verificación.
- **Autoalojar Inter/Bricolage** (RGPD DE/FR/IT/PT, sentencia Múnich 2022).


**How to apply:** si vuelve a pedir trabajo en `Web/`, primero `gh pr view 62` (¿mergeado?) y si tomó
alguna de las tres; no repetir la auditoría ni el canvas — están en el informe con fecha y método.

Relacionado: [[decisiones-que-esperan-a-jurgen]] · [[medir-la-web-a11y-y-preview]]
