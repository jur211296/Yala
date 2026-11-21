---
id: 2026-11-21-hotfix-1-0-politica-sin-conectar-gmail
status: done
priority: medium
area: "web, privacidad"
created: 2026-11-21
updated: 2026-11-21
source: "decisión de Jürgen 21-nov 08:39 (OK de producción), punto 122 de docs/auditorias/2026-11-21-decisiones-vs-2-3.md"
---

# La política y los términos de la web explicaban «Conectar Gmail», que nunca llegó a la app publicada

La política de privacidad dedicaba su sección 5 a «Si conectas tu Gmail» (permiso de lectura gmail.readonly,
borradores, desconexión) y la citaba desde datos, proveedores, derechos y conservación. Los términos la mencionaban
en «Descripción del servicio» y en «Tus datos». Conectar Gmail quedó fuera de la app (18-nov: los avisos del banco
llegan por reenvío al correo de Yala, sin Gmail).

## Hecho cuando

Ni la política ni los términos de yala-app.pe mencionan Conectar Gmail ni el permiso de lectura, en los seis idiomas,
y `2.3` lleva el mismo cambio.

## Resolución (2026-11-21)

`Web/src/i18n/translations.ts`, seis idiomas: fuera la sección 5 entera y sus menciones en «Dónde viven tus datos»,
«Proveedores» (Google queda como «Iniciar sesión con Google»), «Tus datos, tu control» y «Cuánto tiempo guardamos»,
y las frases de los términos. La política pasa de 15 a 14 secciones, con títulos y referencias «(sección N)»
renumerados. `PrivacyPage.astro` pierde el bloque `id="gmail"`; nadie enlazaba a ese ancla.

Queda una sola mención de Gmail por idioma, a propósito: el código con el que Gmail confirma la dirección de
reenvío, que es parte del reenvío de avisos del banco y sigue vigente.

Hotfix contra `1.0` (Vercel publica desde ahí) y el mismo commit en `2.3`, donde el conflicto con la versión de
`privacyCloudText` de 2.3 se resolvió aplicando el mismo cambio sobre el texto de 2.3.

## Verificación en producción

Medido en yala-app.pe tras el deploy de Vercel del merge del hotfix (21-nov, 18:26 Lima), con Chromium a 390 px,
en las 12 páginas (política y términos × es, en, de, fr, it, pt):

- Política: 14 secciones (antes 15), cero frases de Conectar Gmail (antes 7 por idioma), una mención de Gmail (la
  del reenvío). «5.» es ya «Grupos y gastos compartidos».
- Términos: cero menciones de Gmail (antes 3 por idioma).

Capturas antes y después en `~/Claude/entregas/2026-11-21-hotfix-1-0-politica-sin-conectar-gmail/evidencia/`.
