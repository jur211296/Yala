---
id: shell-and-wipe-alert-read-the-session-axis-differently
status: backlog
priority: medium
area: "sesiones"
created: 2026-09-14
source: "review adversarial de `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`, lente de producto"
---

# Con la marca de sesión ausente, la app enseña todas las pestañas y calla el aviso de datos borrados

## Lo medido (2026-09-14)

Las dos superficies leen el MISMO eje con lecturas de signo opuesto, y sobre fuentes distintas:

| Superficie | Lectura | Ausente ⇒ | Fuente |
|---|---|---|---|
| La shell (qué pestañas se ven) | **laxa** (`hasPrivateSession`) | `true` | el espejo EN MEMORIA de `SessionState` |
| El aviso de vaciado remoto | **estricta** (`confirmedPrivateSession`) | `false` | el valor PERSISTIDO |

Cada una está bien por su cuenta —la shell falla conservando, el aviso falla callando, que es el lado
barato de cada una— pero con la marca ausente se combinan mal: la persona ve **la app entera** (todas
las pestañas personales, porque la shell la cree privada) **vacía y sin ninguna explicación**, porque
el aviso se calló al no poder confirmar que la sesión sea privada.

## Por qué la ventana es estrecha, y por qué aun así se anota

El backfill de arranque escribe la marca en todo teléfono con el onboarding hecho
(`PrivateSessionMark.backfillIfNeeded`, `AppBootstrapper` paso 0.0-bis), y el aviso exige
`hasCompletedOnboarding` para arrancar su gracia. Así que para caer aquí hace falta que la marca
desaparezca **después** del boot sin que nadie la reponga.

Lo que hace que valga la pena: la asimetría no está anotada en ningún sitio, y la siguiente superficie
que lea el eje elegirá una de las dos lecturas sin saber que la otra existe al lado.

## Criterios de aceptación

- [ ] Decidido si la combinación «shell `.full` + aviso callado» es aceptable o necesita un tercer
      comportamiento (por ejemplo, que la shell también falle cerrado cuando no hay marca).
- [ ] La asimetría queda escrita donde la vea quien añada el siguiente consumidor del eje.
