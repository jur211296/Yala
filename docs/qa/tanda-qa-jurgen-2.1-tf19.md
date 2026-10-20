# Tanda de QA de Jürgen — 2.1 sobre el TestFlight 19

Sale del QA guiado del 19-oct sobre el TestFlight 18 (PR #563): 23 de 27 pasaron, y las ocho cards de 2.1 que salieron
de ahí ya están arregladas en los PR **#564** (`cq2i`, `9ttd`, `ewkw`, `8171`) y **#566** (`axgf`, `ppxk`, `t2q8`,
`n2xn`). Esta tanda las prueba en un iPhone de verdad y cierra lo que quedó pendiente (D · E2 y el paso 3 del micrófono).

- **Build:** TestFlight **19**, desde `2.1` con el #564 y el #566 dentro. Todo va contra **producción**.
- **Fuera de la tanda (2.2):** `n5zw` (iCloud Drive apagado con la app cerrada) y `ewvm` (consentimiento y nombre otra vez
  al re-entrar en Grupos, la mitad que falló de A · C6).
- **Tiempo:** unos **2 h 15 min**, casi todo esperas.

## Montaje

- **iPhone de QA** (iPhone 14, iCloud `test@yala-app.pe`): es el aparato **A**. En Archivos sigue
  `movimientos-qa-1500.csv`.
- **iPad**: es el aparato **B**. Para E1 y E2 tiene que tener iCloud con **`test@yala-app.pe`**, como el 19-oct. Si ya
  volviste a tu iCloud personal, cámbialo otra vez solo para el bloque 5 y 6; con tu iCloud personal, la invitación
  tocaría tus datos reales.
- **Producción está vacía** desde el 19-oct: `jur211296@gmail.com`, `admin@yala-app.pe` y `test@yala-app.pe` (Google)
  cuentan como cuentas nuevas. La app de Google ya está «En producción».
- El iPhone tiene la Yala de TestFlight apuntando a una cuenta borrada: el bloque 1 empieza borrándola.

## Orden

| # | Bloque | Card | Aparato | Min |
|---|---|---|---|---|
| 1 | Actualizar desde la 2.0.4: «Mira lo nuevo» al primer arranque | `n2xn` | A | 15 |
| 2 | La música vuelve tras la voz | `8171` | A | 5 |
| 3 | «Empezar sin ellos» con 1.500 movimientos en iCloud | `9ttd` | A | 30 |
| 4 | Grupos sin relanzar, la cuenta de grupos correcta y «Activar la nube» sin pararse | `ewkw`, `cq2i`, `axgf`, `ppxk` | A | 35 |
| 5 | D · E2: reintentar «Volver a iCloud» en el segundo aparato | `gk5w` | A + B | 25 |
| 6 | D · E1 paso 3: unirse por enlace tras reinstalar | `t2q8` | A + B | 25 |

Cada bloque deja el aparato como lo necesita el siguiente: no se salta ninguno.

---

## 1 · Actualizar desde la 2.0.4 — `n2xn` · bloquea

1. iPhone: borra **Yala** (la de TestFlight). Instala **Yala desde la App Store** (2.0.4).
2. Ábrela y haz el alta **restaurando desde iCloud** (tus datos de prueba: «Prueba», los «D4», «D5 cena»…).
3. Sin volver a abrirla, instala el **TestFlight 19 encima** y ábrelo.
4. **Esperado:** «Mira lo nuevo en Yala» sale en el **primer** arranque, con «Grupos», «Anotar nunca fue tan fácil» y
   «Tus datos, tus reglas». Toca «Continuar».
5. Cierra Yala del todo y ábrela: sale la **oferta de prueba de Pro** (si no eres Pro) y Novedades **no** vuelve.

## 2 · La música vuelve tras la voz — `8171`

1. Pon música en otra app. En Yala › Panel › **Voz**: la música se para.
2. Toca **«Cancelar»**. **Esperado:** la música vuelve sola.
3. Repite diciendo «taxi 12» y toca **«Listo»**. **Esperado:** la música vuelve al terminar de grabar. Puedes descartar
   el borrador.

Cierra también `h52f` (IA sesión 2), que solo esperaba esto.

## 3 · «Empezar sin ellos» con un iCloud grande — `9ttd` · bloquea

Montaje: 1.500 movimientos en tu iCloud y una cuenta en la nube nueva.

1. iPhone, en la sesión privada: Perfil › **«Importar archivo»** › `movimientos-qa-1500.csv`, a una cuenta en soles.
2. Espera un par de minutos con Yala abierta, para que suban a iCloud. Perfil › **«Cerrar sesión»**. Si sale «Guardando
   tus cambios pendientes…» y luego un aviso con cifra, toca **«Esperar»** hasta que cierre sola. **No** toques nada con
   «igualmente» ni «borrar».
3. **«Es mi primera vez en Yala»** › **«Tu cuenta en la nube»** › **Google jur211296@gmail.com**. Termina el onboarding
   y crea un gasto **«TF19 A1»**.
4. Perfil › **«Dónde viven tus datos»** › **«Volver a iCloud»** → «Tu iCloud ya tiene datos de Yala», con unos 1.500.
5. **«Empezar sin ellos»** › **«Borrar y volver a iCloud»**.
6. **Esperado:** el botón dice **«Borrando los datos de antes… N hasta ahora»** y la cifra sube; termina en **un solo
   intento** y la vuelta sigue sola (reabre si lo pide). Al final, en Registros solo está «TF19 A1».
7. Si se corta, apunta la cifra y el texto: no debe decir «Revisa tu conexión» salvo que no haya red.

## 4 · Grupos, la cuenta de grupos correcta y «Activar la nube» — `ewkw`, `cq2i`, `axgf`, `ppxk` · bloquea

Montaje de `cq2i`: el iCloud del Apple ID tiene que recordar **otra** cuenta de grupos.

1. iPhone, en la sesión privada que dejó el bloque 3: Perfil › **«Dónde viven tus datos»** › **«Asociar una cuenta para
   grupos»** › **Google test@yala-app.pe**. Esa es la cuenta «vieja».
2. Borra Yala, instala el TestFlight 19. **«Vengo por un grupo»** › **«Crear mi primer grupo»** › **Google
   admin@yala-app.pe** › crea el grupo **«QA TF19»**. Perfil › **«Cerrar sesión»**.
3. Borra Yala y reinstálala. **«Ya tengo una cuenta»** › **Google admin@yala-app.pe**.
4. **`ewkw` · esperado:** al entrar en **Grupos**, «QA TF19» aparece en unos segundos, **sin cerrar Yala**.
5. Perfil › **«Activar Yala completo»** › **«Tu cuenta en tu iCloud privado»** › **«Traer mis datos»**, reabriendo si lo
   pide.
6. **`cq2i` · esperado:** en «Dónde viven tus datos», Grupos dice **«Tus grupos usan admin@yala-app.pe»**, no
   test@yala-app.pe, y «Activar la nube» **no** sale bloqueado. **No** toques «Desasociar».
7. **«Activar la nube»** › consentimiento (usa la sesión de admin@, no pide entrar) y **quédate en la pantalla**.
8. **`axgf` · esperado:** la barra pasa del 55 % y termina **sin cerrar Yala**. Si se para más de 2 min, apunta la hora.
9. **`ppxk` · esperado:** si sale «Esperando a que iCloud termine de sincronizar…», **«Cancelar la activación» está
   activo** (no lo toques esta vez) y la barra **no** vuelve del 75 % al 60 %. Apunta cuánto tardó en llegar a «Tu cuenta
   en la nube».
10. Opcional, si sobra tiempo: en otro intento, toca «Cancelar la activación» durante esa espera; se cancela en cuanto
    iCloud se calme.

## 5 · D · E2: reintentar «Volver a iCloud» en el segundo aparato — `gk5w`

El iPhone quedó en la nube con admin@ (una cuenta **migrada** desde iCloud, la única que puede volver a iCloud desde otro
aparato).

1. iPad (iCloud `test@yala-app.pe`): borra Yala, instala el TestFlight 19. **«Ya tengo una cuenta»** › **Google
   admin@yala-app.pe** → Panel con los mismos datos.
2. iPhone: «Dónde viven tus datos» › **«Volver a iCloud»** hasta terminar. Si sale «Tu iCloud ya tiene datos de Yala»,
   **«Sumarlos a mis datos»**.
3. iPad: **«Volver a iCloud»** → sale la espera; **cancélala**.
4. iPad: **reintenta**. **Esperado:** avanza, y **no** sale «tu cuenta no lo permitía».

## 6 · D · E1 paso 3: unirse por enlace tras reinstalar — `t2q8` · bloquea

1. iPhone: Grupos › crea **«QA unión 19»** › sus ajustes › **«Invitar por enlace»** › mándalo al iPad por AirDrop.
2. iPad: borra Yala y reinstálala **sin abrirla**. Abre el enlace › **«Unirme al grupo»** › **Google jur211296@gmail.com**
   (cuenta completa del bloque 3).
3. **Esperado:** **no** sale «Este dispositivo tiene datos de otra cuenta» ni «Antes de unirte, este teléfono queda en
   blanco»; «Conectando con tu grupo…» pasa a **«Esperando aprobación»** sin esperar minutos. En el iPhone llega la
   solicitud.
4. iPad: borra Yala y reinstala sin abrir. Abre el enlace › «Unirme al grupo» › **Google test@yala-app.pe**. En la hoja
   de Unirme, **cierra Yala del todo** y vuelve a abrir el enlace.
5. **Esperado:** no pide dejar el teléfono en blanco ni se queda minutos en «Conectando…»; acaba en «Esperando
   aprobación».

---

## Al terminar

- Cada card que pase, a done; `gk5w`, `h52f` y los tickets de `tickets/qa/` que cuelgan de ellas, también.
- El iPad vuelve a tu iCloud personal.
- Producción queda con las tres cuentas de prueba de la tanda: se borran con «Eliminar mi cuenta» o en bloque, como el
  19-oct.
