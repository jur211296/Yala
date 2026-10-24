---
name: verificacion-gmail-espera
description: Verificación de Google de gmail.readonly (yala-502622) parada el 2026-10-23 esperando a Jürgen — PR #613 en borrador, qué falta y qué no tocar en la consola
metadata:
  type: project
---

«Conectar Gmail» fase 1 está hecha en Yala Dev (PR #613, borrador, contra 2.2 pero es de 2.3: no mergear en 2.2).
La verificación de Google está **parada en Jürgen** desde el 2026-10-23 por cuatro cosas: grabar el video con su
cuenta de Gmail que recibe avisos del BCP, publicar la política (hotfix web desde 1.0), verificar yala-app.pe en
Search Console, y decidir si se verifica la lectura en el teléfono (hecha) o la del servidor (roadmap).

**Why:** Google no deja pedir la verificación de datos sin la marca verificada, y la marca pide el dominio en
Search Console. Y Google aprueba el uso que se le enseña: verificar el teléfono y publicar el servidor obliga a
repetirla.

**How to apply:** al retomar, empieza por `docs/verificacion-google/checklist-consola.md` y re-mide la consola.
La app OAuth está **en producción**: nunca volver a modo prueba (corta el login con Google de la nube), y el tope
de 100 usuarios sin verificar no se reinicia nunca (3 usados el 23-oct). Ver [[credencial-pendiente-se-aparca]].
