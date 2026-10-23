---
id: reopen-yala-mirror-off-in-place-needs-an-iphone-measurement
status: blocked
priority: medium
area: "modo-nube, onboarding, grupos"
created: 2026-10-23
updated: 2026-10-23
source: "tablero-reabre-yala-solo-cuando-la-persona-entra-ypit (encargo 2026-10-23-grupos-refresco-y-entrada-2-2)"
---

# Cuatro «Reabre Yala» de la nube y de Grupos esperan una medición en un iPhone real

## Qué queda

De la regla de Jürgen del 22-oct («Reabre Yala» solo al entrar en el iCloud privado), cuatro sitios siguen pidiendo reabrir
porque cierran con el espejo de iCloud MONTADO (inventario en `reopen-yala-only-for-private-icloud`, filas 4 a 7):

| # | Qué ve la persona | Cuándo |
|---|---|---|
| 4 | «Ya casi está · Tus datos ya están en tu cuenta de la nube» | final de «Activar la nube» y de «Activar la nube en este dispositivo» |
| 5 | «Tus datos siguen en la nube · La vuelta a iCloud se detuvo» | «Cancelar y seguir en la nube» tras montar el espejo, o el techo de la espera |
| 6 | «Un último paso: reabre Yala» | Ya tengo una cuenta › nube, o Es mi primera vez › Tu cuenta en la nube, con el espejo montado |
| 7 | «Abre Yala otra vez para unirte» | Tengo una invitación con una cuenta de la nube recién activada |

## Por qué está bloqueado

`PersonalContainerSwap` cambia el contenedor sin relanzar, pero se niega con el espejo montado
(`PersonalSwapReleaseLogic.mountAdmitsSwap`): el spike R3 midió en device **5 eventos de CloudKit en los 10 s posteriores
a soltar el contenedor con espejo**. Si al apagar el espejo con la app abierta CloudKit sigue escribiendo en el fichero que
se remonta sin espejo, el riesgo es perder o duplicar filas. El simulador no tiene iCloud ni exporta a CloudKit: no puede
contestar. Pide el iPhone de QA conectado a la Mini.

## Lo que hace falta (Jürgen + Frank, una sesión de ~30 min)

1. Jürgen conecta el iPhone de QA por cable a la Mini, lo desbloquea y avisa a Frank.
2. Frank instala un build de medición (Yala Dev con una sonda en `PersonalContainerSwap`, no se publica) y le pide a
   Jürgen: «Activar la nube» con una cuenta de prueba de staging hasta la pantalla «Ya casi está».
3. En ese punto Frank suelta el contenedor con el espejo y monta el mismo fichero sin él, con la app abierta, y cuenta
   durante 60 s qué escribe CloudKit después (eventos del espejo y cambios en el fichero).
4. Con cero escrituras en dos corridas, se amplía el cambio en caliente a las filas 4-7 con sus tests. Con alguna, las
   cuatro quedan como excepción y se le pide a Jürgen que la apruebe.

## Hecho cuando

Las cuatro cierran sin reabrir con la medición en verde, o quedan como excepción aprobada por Jürgen.
