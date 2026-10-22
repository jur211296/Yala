# Cuenta de Yala en X — presencia mínima (borrador)

> **Nada de esto está publicado.** No hay cuenta creada, ni handle reclamado, ni post programado.
> Es un documento para leer, corregir o tirar. No hay siguiente paso automático.
>
> Fecha: 2026-09-02 · Sale del radar de contenidos en X del mismo día.
>
> **Cerrado por Jürgen el 2026-09-02:** el enlace es el neutro; el nombre visible se copia de App
> Store Connect, no del slug; el post de privacidad sigue bloqueado hasta que lo confirme Frank.

## Por qué una cuenta de marca, y qué esperar de ella

El radar dejó dos cosas claras y conviene no perderlas de vista al leer lo de abajo:

- **La conversación la llevan personas, no logos.** Lo que circula es «I built X», «would you use
  this?», founders con cara. Las cuentas oficiales de la categoría o están paradas (YNAB, meses)
  o repiten copy sin respuesta (Fintonic, 0 likes).
- **Yala no existe en X.** Cero posts nuestros, cero menciones. `@yala` está ocupada, vacía y no
  es nuestra.

De ahí que esta cuenta **no se justifique por engagement**. Se justifica por una sola cosa:
que quien oiga «Yala» y la busque en X encuentre algo vivo, oficial, y el enlace para bajarla.
Ese es el trabajo completo. Si además conversa, es ganancia, no requisito.

---

## 1 · Handle

| Handle | Estado | Nota |
|---|---|---|
| **`@yalaapp`** | **Libre** (radar 2-sep) | **Recomendado.** Es el patrón que ya usa la casa (`yala-app.pe`) y lo que la gente teclea al buscar «yala app». No promete categoría. |
| `@yalafinance` | Libre (radar 2-sep) | En inglés y estrecha el producto a «finance» — la app es ES primero. Vale como defensiva, no como principal. |
| `@yalafinanzas` | **Sin verificar** | ES nativo, 13 caracteres (cabe en los 15 de X). Más largo de teclear y más difícil de decir en voz alta. |
| `@yala` | **Ocupada y vacía** (0 posts), no es nuestra | Se puede pedir por marca registrada, pero es un trámite con X que puede no salir. **No bloquea nada:** no esperes a resolverlo para abrir `@yalaapp`. |

**Recomendación: `@yalaapp`.**

⚠️ La disponibilidad es del radar del 2-sep. **Se vuelve a comprobar el día que se reclame** —
un handle libre hace tres semanas puede no estarlo hoy.

## 2 · Perfil

**Nombre visible** (límite 50): **el nombre exacto de la ficha publicada, leído en App Store
Connect.** Decidido el 2026-09-02: se copia de ASC y **no se deriva del slug de la URL**.

El slug (`yala-finanzas-sin-esfuerzo`) es lo único medible desde este repo, y no sirve como fuente:
lo genera Apple y puede no coincidir con el nombre vivo. Si ASC dice `Yala` a secas, en X va `Yala`
a secas y la bio carga el resto — no se le añade coletilla por adornar.

Lo único que hay que respetar al copiarlo es el límite de 50 caracteres de X. Como referencia,
`Yala — Finanzas sin esfuerzo` son 28.

**Bio ES** (límite 160) · 155 caracteres:

```
Anotar un gasto toma segundos: le hablas, le haces foto al recibo o lo escribes. La IA lo ordena. Tus finanzas, claras y en un solo lugar. App para iPhone.
```

Variante corta, por si el nombre visible ya dice mucho · 126 caracteres:

```
Anotar un gasto toma segundos: voz, foto o teclado. La IA lo ordena. Tus finanzas, claras y en un solo lugar. App para iPhone.
```

**Bio EN** (por si se abre cuenta en inglés más adelante; **no** para mezclar en la misma) · 144:

```
Logging an expense takes seconds: talk to it, snap the receipt, or type it. The AI sorts it out. Your money, clear and in one place. iPhone app.
```

**Enlace del perfil** (campo Website, no va dentro de la bio):

```
https://apps.apple.com/app/id6758253109
```

El `id6758253109` está **medido**, no inventado: sale de `Web/src/components/HomePage.astro`,
donde el sitio enlaza la ficha. Ahí se usa la variante con tienda peruana
(`apps.apple.com/pe/app/yala-finanzas-sin-esfuerzo/id6758253109`); la de arriba es la misma ficha
sin fijar país, que redirige a la tienda de quien la abra. **Decidido el 2026-09-02: en X va la
neutra** —la de arriba—, la misma en el perfil y en el post fijado. Quien la abra desde fuera de
Perú aterriza en su propia tienda y no en una que no es la suya.

**Imagen y cabecera:** no las invento aquí. El generador de `screenshots-appstore/` puede sacarlas
con datos de ejemplo cuando se decida el resto.

## 3 · Posts de arranque

Cuatro. El primero se fija arriba. Listos para copiar; todos por debajo de 280 caracteres.

Dos cosas deliberadas: **casi no hay emoji** —en X el emoji denso lee a cuenta de logo, que es
justo lo que el radar vio muerto— y **ninguno promete cadencia**. Nada de «síguenos para tips» ni
«pronto más»: prometer ritmo y no cumplirlo es lo que hace que un perfil parezca abandonado.

---

**POST 1 — fijado. Qué es y dónde se baja.** (252 car.; X cuenta el enlace como 23 → ~231)

```
Yala es una app de finanzas personales para iPhone.

Anotas un gasto en segundos —le hablas, le haces foto al recibo o lo escribes— y la IA lo ordena por ti: categoría, cuenta, presupuesto.

Está en la App Store: https://apps.apple.com/app/id6758253109
```

---

**POST 2 — el posicionamiento.** (248 car.)

```
Casi nadie deja de llevar sus cuentas por falta de disciplina.

Lo deja por fricción: el Excel eterno, apuntar cada café a mano, acordarse tres días después de en qué se fue el dinero.

Yala existe para quitar esa parte. El resto ya lo sabes hacer.
```

*Este es el post que más importa que salga bien.* La última línea es la marca entera: le devuelve
la capacidad al usuario en vez de quitársela. Si alguna versión futura suena a «deberías llevar un
presupuesto», está mal aunque convierta.

---

**POST 3 — cómo es de verdad.** (251 car.)

```
Tres formas de anotar un gasto en Yala, y todas toman segundos:

— Le hablas: «gasté 30 en el almuerzo».
— Le haces foto al recibo y lee el monto.
— Lo escribes, como toda la vida.

Y si tienes el extracto del banco en CSV o Excel, lo importas de una.
```

---

**POST 4 — la novedad.** (187 car.)

```
Novedad de Yala 2.0: Grupos, en beta.

Creas un grupo para el viaje o el depa, cada quien anota lo que puso, y Yala calcula quién le debe a quién.

Sin la conversación incómoda del final.
```

El «en beta» va porque así lo dice la ficha publicada de 2.0. No se quita.

---

**POST 5 — opcional, y bloqueado hasta que Frank confirme.** (202 car.)

```
Yala no se conecta a tu banco.

No hay login del banco, no hay Plaid, no hay que darle tus claves a nadie. Anotas tú —en segundos— y la IA ordena el resto.

Tus datos financieros se quedan en tu iPhone.
```

Es el ángulo más fuerte que tenemos (la queja repetida de la categoría es exactamente ésa), y por
eso mismo el más caro de equivocar. **Bloqueado por Jürgen el 2026-09-02: no sale hasta que Frank
confirme qué es cierto de la build publicada.** Ver punto 5.

## 4 · Cuenta de marca vs. cuenta personal

No compiten. Hacen cosas distintas y el error caro sería pedirle a la de marca lo que solo puede
hacer una persona.

| | **`@yalaapp` (marca)** | **Cuenta personal, si se usa esa vía** |
|---|---|---|
| Para qué existe | Que Yala se pueda encontrar y descargar | Que haya alguien detrás con quien hablar |
| Qué publica | Qué es la app, novedades de release, respuestas a quien pregunta o menciona | Construir en público: por qué se quitó algo, qué se rompió, decisiones de producto, preguntas de verdad |
| Ritmo | Sin ritmo. Puede pasar un mes sin nada | El que aguante quien la lleve |
| Lo que **no** hace | Consejos de finanzas diarios, humor de marca, frases motivacionales | Sonar a comunicado |
| Cifras | Solo las de App Store Connect, y solo si se publican | Igual: si el número no existe, no se dice |

Dos avisos:

- **El valor de la personal es que no es delegable.** En cuanto la escribe «la marca», deja de
  funcionar — es literalmente lo que separa a los founders del radar de las cuentas oficiales
  paradas. No se automatiza y no la escribe Lola por su cuenta.
- **Si algún día existen las dos**, la de marca no retuitea todo lo de la personal ni al revés.
  La marca enlaza la ficha; la persona enlaza lo que quiera.

## 5 · Antes de publicar nada, confirmar cinco cosas

Publicar en X **no se deshace con un commit**. Estas cinco son rápidas y ninguna la puedo cerrar yo:

1. **El nombre vivo de la ficha — lo único que queda abierto del perfil.** Se lee en App Store
   Connect y se copia tal cual. Ni el slug ni `App Store/metadata/description-es.md` (que pone
   `App Name: Yala`) valen como fuente: uno lo genera Apple y el otro es un fichero del repo, no
   la ficha.
2. ~~La forma del enlace.~~ **Cerrado el 2026-09-02:** va la neutra,
   `apps.apple.com/app/id6758253109`, igual en perfil y en post fijado.
3. **La frase de privacidad, con Frank.** El copy publicado de 2.0 dice que los Grupos viajan «por
   tu iCloud privado, sin servidores nuestros», y `docs/ESTADO.md` dice `GROUPS_BACKEND 100` en
   producción. Puede que no haya contradicción ninguna —no es mi terreno y no lo he mirado— pero
   **el POST 5 y cualquier claim de privacidad no salen hasta que Frank confirme qué es cierto de
   la build publicada.**
4. **Que Grupos siga en beta** en esa misma build, por el POST 4.
5. **Que el handle siga libre** el día que se abra.

**Y una que no bloquea, pero está ahí:** `description-es.md` se contradice sola — el mismo bullet
dice «45+ divisas» y «más de 50 monedas». No lo toco (no es este encargo, y las siete descripciones
se tocan juntas o no se tocan), pero por eso **ningún post de arriba dice un número de divisas**.

## 6 · Qué cuenta como «existe»

La cuenta está lista —y se puede dejar quieta sin que se note— cuando se cumplen seis cosas:

1. El handle es nuestro.
2. El nombre visible coincide con el de la tienda.
3. La bio dice qué es y para qué teléfono.
4. El enlace del perfil abre la ficha.
5. Hay un post fijado que se entiende sin contexto y lleva al mismo sitio.
6. Debajo hay dos o tres posts más, para que el día 1 no parezca un perfil vacío.

Y una séptima que es de persona, no de sistema: **alguien mira las menciones una vez por semana.**
No hay automatismo aquí —ni routine, ni calendario, ni post diario— así que no hay nada que pueda
fallar en silencio; pero tampoco hay nada que avise si alguien pregunta algo. Eso se mira a mano o
no se mira.

**Lo que no hace falta:** calendario editorial, cadencia, hilo de lanzamiento, responder a todo,
ni volver a publicar nunca. Si en tres meses no sale nada más, el perfil sigue haciendo su trabajo.

**El riesgo que se acepta a cambio:** cuatro posts y silencio se ven «muertos» para quien te está
evaluando. Se acepta a propósito, porque la alternativa —publicar disciplina todos los días— es
peor: es el registro que Yala no usa y el que el radar vio sin respuesta.
