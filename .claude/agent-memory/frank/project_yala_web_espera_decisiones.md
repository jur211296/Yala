---
name: yala-web-espera-decisiones
description: Yala web: lotes 0 a 3 en staging desde el 14-nov (lote 3 = Grupos en lectura); escribir en Grupos espera la decisión A/B/C de Jürgen; las 13 decisiones van con la recomendada; device-QA de la beta y del QR pendientes.
metadata:
  type: project
---

Plan y decisiones en el artifact https://claude.ai/artifact/JN7jw8J1UXBQGNNpLNErAe y en `docs/web-app/index.html`. La
colección `decisiones` de su db seguía VACÍA el 14-nov (medido con `ArtifactData list`): vale la recomendada en las 13.
El 14-nov Jürgen cambió D10: los lotes 2 y 3 se hacen ya en 2.3 (`docs/DECISIONS.md`, lote del 14-nov).

Estado al 14-nov: lote 0 (entrar y sesión) y lote 1 (Panel, Registros, Bandeja, Apuntar, sesiones y «Navegadores
conectados» en el iPhone) desplegados en staging; producción, nada. El device-QA de la beta en el iPhone 14 espera la
mano de Jürgen: entrar con Apple en Yala Dev y en la web (Face ID). Guion en `tickets/done/yala-web-lote-1-beta.md`.

Lote 2 (14-nov): Estadísticas, Pagos planificados y entrar con el iPhone por QR, en staging. Del lote 2 del plan
quedaron fuera, por no pedirlos el encargo, Presupuestos, Grupos en lectura, ⌘K, CSV y los 16 idiomas: van en el
siguiente encargo. Device-QA del QR (cámara y Face ID reales) en `tickets/done/yala-web-lote-2.md`.

Lote 3 (14-nov): Grupos en LECTURA, cuentas «solo Grupos» y editar o descartar borradores de la web, en staging. Lee
Grupos por la entrada interna `WebGroupsReader` del gateway (la llave de Grupos no sale de ahí) con `web3_01` en
Supabase staging. **Escribir en Grupos (añadir gasto, saldar, invitar) está parado** a la espera de Jürgen, preguntado
el 14-nov 10:14 por `preguntar-bot`: A (rol propio de escritura por el gateway, recomendada), B (borradores que sube el
iPhone) o C (nada hasta 3.0). El plan lo deja abierto («hace falta una puerta para la web»): no lo adivines. Datos de
prueba en staging: «Viaje a Cusco» (A, B y C) y «Depa Miraflores» (A y B). El lote 3 llevó al PR del lote 2 el arreglo
del texto que tumbaba su CI (decisión 51: «la nube de Yala» retirado como nombre de sitio).

**Why:** la web reusa el núcleo de `shared-core` y la cola de borradores del gateway; cada lote lo aprueba él.

**How to apply:** al abrir el lote 2, lee la db del artifact por si contestó algo y parte del README de `webapp/`. Lo
que el lote 1 dejó fuera (origen «Yala web» propio en la Bandeja, cerrar sesión en el iPhone no cierra la web, la
política de privacidad) está en el README. Relacionado: [[secretos-de-staging-en-la-mini]],
[[propuestas-como-artifact-visual]].
