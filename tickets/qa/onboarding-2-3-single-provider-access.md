---
id: onboarding-2-3-single-provider-access
status: qa
priority: high
area: "bienvenida 2.3, cuenta de Yala"
created: 2026-11-12
updated: 2026-11-12
source: "docs/onboarding-2-3/SPEC.md, card Y23-02 · lote 02 de la bienvenida 2.3"
qa-status: needs-testing
---

# Acceso con Google o Apple: un botón que crea o entra

Un solo botón por proveedor. Tras la hoja del sistema, «Verificando tu cuenta…». Sin cuenta: «Vamos a crear tu cuenta»
con el consentimiento de la nube en la misma hoja y el aviso «¿Creaste tu cuenta con Apple? Entra con Apple…» (el
servidor no dice con qué proveedor se creó: decisión A de Jürgen, mejora de servidor en
`tickets/backlog/account-exists-should-return-the-creation-provider.md`). Con cuenta: «¿Cargamos tus datos y entramos?»
(también con el consentimiento) y «Conectando con tu cuenta…». Los casos especiales son las pantallas de siempre.

El simulador no inicia sesión: las dos hojas se vieron con `-uitest-unified-access-phase`. Falta el recorrido real.

## Guion en el iPhone 14 (Yala Dev)

1. Borra Yala Dev del iPhone 14 e instala la build del PR.
2. Abre Yala: sale la vitrina. Toca «Entrar con Google» con una cuenta de Google que NO tenga cuenta de Yala.
3. Tras la hoja de Google debe salir «Vamos a crear tu cuenta» con los tres puntos de la nube y el aviso de Apple.
   Toca «Crear mi cuenta»: «Creando tu cuenta…» y la conversación de tres preguntas, con tu nombre propuesto.
4. Borra Yala Dev otra vez. Toca «Entrar con Google» con la MISMA cuenta: debe salir «¿Cargamos tus datos y
   entramos?». Toca «Cargar mis datos y entrar»: «Conectando con tu cuenta…» y entra con tus datos.
5. Borra Yala Dev. Toca «Entrar con Apple» con un Apple ID sin cuenta de Yala, y luego «Usar otra cuenta»: vuelve a la
   vitrina. Vuelve a tocar «Entrar con Google»: tiene que abrir la hoja de Google (no seguir con la sesión de Apple).
