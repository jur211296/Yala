# Propuesta: política de privacidad y términos para leer Gmail

> **Propuesta para Jürgen. No está publicada ni aplicada a `Web/`.** La web de producción sale de la rama
> `1.0`; estos textos se escribieron contra `origin/1.0:Web/src/i18n/translations.ts` del 23-oct-2026.

Google revisa la política de `https://yala-app.pe/privacy` (la que está en la consola) y comprueba tres cosas
de su *User Data Policy*: que diga **qué datos de Google** se tocan, **para qué**, con **quién** se comparten y
**cuánto** se guardan; que incluya la **declaración de Uso Limitado** (*Limited Use*); y que la página de
inicio enlace a la política. La declaración la quiere **literal y en inglés** en la versión inglesa: es la única
frase en inglés de esta propuesta.

## Política de privacidad

### Sección nueva, después de la 4 («Si eliges tu cuenta en la nube»): «Si conectas tu Gmail»

**Título:** `5. Si conectas tu Gmail` (y se renumeran las siguientes).

**Texto (fase 1, lectura en el teléfono):**

> Conectar Gmail es opcional. Si lo activas, Yala te pide permiso con la pantalla de Google para **leer** tu
> correo (permiso `gmail.readonly`) y lo usa para una sola cosa: convertir los avisos de movimientos de tu
> banco en borradores de la Bandeja, que tú revisas y guardas.
>
> • **Qué lee:** solo los correos de aviso de tu banco. Yala busca por la dirección del remitente (por
> ejemplo, la del BCP) y no abre ningún otro mensaje.
> • **Qué guarda:** de cada aviso, el borrador (importe, divisa, comercio y fecha) y un extracto corto del
> texto, igual que con una foto o una nota de voz. No guarda el resto del correo.
> • **Dónde se lee:** en tu teléfono. El correo no pasa por nuestros servidores ni por ningún servicio de IA.
> • **Qué no hace:** no envía, no modifica y no borra correos; no lee tus contactos; no usa tu correo para
> publicidad, no lo vende y no lo usa para entrenar modelos de IA.
> • **Tu acceso, tu decisión:** puedes quitar el permiso cuando quieras desde la app o en tu cuenta de Google
> (Seguridad › Apps de terceros con acceso a la cuenta). Los borradores que ya guardaste siguen en Yala como
> el resto de tus datos.
> • **Uso limitado:** el uso que hace Yala de la información recibida de las APIs de Google, y su transferencia
> a cualquier otra app, cumplirá la Política de Datos de Usuario de los Servicios de API de Google, incluidos
> los requisitos de Uso Limitado.

**Declaración literal para la versión inglesa** (texto que Google exige tal cual):

> Yala's use and transfer to any other app of information received from Google APIs will adhere to the
> Google API Services User Data Policy, including the Limited Use requirements.

con «Google API Services User Data Policy» enlazado a
`https://developers.google.com/terms/api-services-user-data-policy`.

**Si la versión final lee el correo en el servidor** (roadmap 2.3), el punto «Dónde se lee» se sustituye por
lo que de verdad pase, y hay que decirlo entero:

> • **Dónde se procesa:** con tu cuenta en la nube, en nuestros servidores (Cloudflare y Supabase, sección 4).
> Para entender el aviso, su texto pasa por nuestro proveedor de IA, que no puede usarlo para entrenar modelos.
> El correo completo se borra en cuanto se crea el borrador; el permiso de Google se guarda cifrado y se borra
> al desconectar Gmail o al eliminar tu cuenta.
> • **Quién puede verlo:** nadie de nuestro equipo lee tus correos, salvo que nos lo pidas para darte soporte,
> por seguridad o porque la ley lo exija.

Esa segunda versión **no se puede publicar antes de que exista**: cada frase tiene que ser verdad el día que se
publique (el borrado inmediato, el cifrado del token y el proveedor sin entrenamiento son trabajo de 2.3).

### Cambios en secciones existentes

| Sección | Hoy | Propuesta |
|---|---|---|
| 2 · «Sin conexión bancaria» | «Yala no se conecta a tu banco ni te pide claves bancarias, en ninguno de los dos modos.» | Añadir: «Si conectas tu Gmail, Yala lee los avisos que tu banco ya te manda por correo; sigue sin conectarse a tu banco ni pedirte claves (sección 5).» |
| 9 · Proveedores, Google | «**Google:** Iniciar sesión con Google, si lo eliges.» | «**Google:** Iniciar sesión con Google y, si conectas tu Gmail, la API de Gmail para leer los avisos de tu banco (sección 5).» |
| 10 · Lo que NO hacemos | 4 viñetas | Quinta viñeta: «No leemos tu correo más allá de los avisos de tu banco, y nunca para publicidad ni para entrenar modelos de IA.» |
| 11 · Cuánto tiempo | — | Viñeta: «**Gmail:** los borradores, como el resto de tus datos; el permiso de Google, hasta que lo quites.» |
| 12 · Tus datos, tu control | — | Viñeta: «**Desconectar Gmail:** desde la app o desde tu cuenta de Google, cuando quieras.» |
| Fecha | «Última actualización: Octubre 2026» | La del día que se publique. |

## Términos de uso

| Sección | Propuesta |
|---|---|
| 2 · Descripción del servicio | Añadir al final: «Si conectas tu Gmail, Yala lee los avisos de tu banco para proponerte borradores; tú decides cuáles guardar.» |
| 5 · Tus datos | Añadir: «Conectar Gmail es opcional y puedes retirarlo cuando quieras. Al usarlo aceptas también las condiciones de Google para tu cuenta. El uso de los datos de Gmail se rige por la sección 5 de la Política de Privacidad y por la Política de Datos de Usuario de los Servicios de API de Google.» |

## Lo que hace falta además del texto

1. **Los seis idiomas de la web** (`es`, `en`, `de`, `fr`, `it`, `pt`, según `translations.ts` de `1.0`).
   Google lee el inglés; la versión española es la de referencia.
2. **La página de inicio enlaza a la política**: la consola lo comprueba al verificar la marca. Medido el
   23-oct en `origin/1.0`: el pie de `HomePage.astro` (línea 351) enlaza `privacyUrl`. Se mantiene así.
3. **Publicar es un hotfix** de la web (rama `1.0`, ver `docs/FLUJO-RAMAS-Y-HOTFIX.md`): en `2.2` no se
   publicaría hasta la siguiente versión. Tiene que estar publicada **antes** de enviar la verificación.
