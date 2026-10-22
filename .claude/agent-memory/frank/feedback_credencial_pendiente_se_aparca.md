---
name: credencial-pendiente-se-aparca
description: Una credencial que tiene que crear Jürgen se pide una vez con pasos, la sesión sigue sin ella, y cuando llega se mide su ALCANCE antes de usarla (el primer token era de otra cuenta)
metadata:
  type: feedback
---

Cuando un encargo autónomo necesita una credencial que solo Jürgen puede crear (token de gestión, dashboard), se
pide **una vez con los pasos numerados** y la sesión sigue construyendo lo que no depende de ella. Si no llega, él
elige «hazlo sin»: el tramo se aparca como ticket `blocked`, con sus pasos y el e2e listo para correr. Y puede
llegar más tarde, a mitad de sesión, con un cambio de plan: hay que estar listo para retomar.

**Cuando llega, se mide su alcance antes de tocar nada.** Un «responde 200» no dice a qué proyecto llega.

**Why:** 2026-09-26, fase 0 del conector de Claude. Pidió el token de gestión de Supabase, a las dos horas dijo
«Hazlo sin token», y poco después lo guardó con «úsalo solo sobre staging». El primero era de otra cuenta: solo
veía la organización «Tests», y el staging de Yala daba 403. Se detectó listando proyectos (`GET /v1/projects`)
y leyendo la config de Auth antes del primer `PATCH`. Su «verificado: la API responde 200» era cierto y no
bastaba.

**How to apply:**
- En la primera pregunta de acceso, ofrece ya la salida «sigo sin eso y lo dejo como ticket».
- Con la credencial en la mano, antes de escribir nada:
  1. lista a qué alcanza;
  2. confirma que el recurso objetivo está y que el de producción no;
  3. apunta el estado de antes.
- Lo que cambies se documenta como «antes → después», para que Jürgen pueda revertirlo y revocar la credencial.

Relacionado: [[autonomo-hasta-el-final]] · [[un-limite-de-plataforma-se-explica-en-la-pregunta]] ·
[[verificar-backend-yala]].
