---
id: onboarding-2-3-groups-entry
status: qa
priority: high
area: "bienvenida 2.3, Grupos"
created: 2026-11-12
updated: 2026-11-12
source: "docs/onboarding-2-3/SPEC.md, card Y23-06 · lote 02 de la bienvenida 2.3"
qa-status: needs-testing
---

# Entrada por Grupos encajada en la bienvenida nueva

«Dividir gastos con amigos» (en las funciones de grupos de la vitrina) abre la puerta de Grupos: «Cuentas claras con
tus amigos.», tres funciones, solo Google y Apple con la nota de la cuenta de Yala. El proveedor lleva a los tres
caminos: «Crear mi primer grupo», «Me invitaron a un grupo» y «Solo crear mi cuenta» (Grupos vacío: pide solo tu
nombre). La hoja de inicio de sesión de Grupos usa el proveedor ya tocado. La invitación por enlace sigue en el orden de
hoy. Splitwise y Tricount no estaban en el alta. Visto en el simulador hasta los tres caminos (XCUITest).

## Guion en el iPhone 14 (Yala Dev)

1. Borra Yala Dev e instala la build del PR. En la vitrina, espera o toca «Divide cualquier gasto» y toca «Dividir
   gastos con amigos».
2. Toca «Entrar con Apple»: salen los tres caminos. Toca «Solo crear mi cuenta», acepta «Grupos en la nube».
3. La hoja de Apple tiene que abrirse sola (sin volver a preguntar con qué entrar). Tras firmar, sale la pregunta de
   tu nombre; escribe uno y continúa: aterrizas en Grupos, sin grupo.
4. Repite con «Crear mi primer grupo»: termina en el formulario del grupo, como hoy.
