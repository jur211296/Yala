---
id: 2026-11-26-compartido-3-invitar-persona-y-entrada-sin-grupo
status: done
priority: high
area: groups
created: 2026-11-26
updated: 2026-11-26
---

# Compartido (lote 3): invitar a una persona y entrar sin crear grupo

Lote 3 de 3 de «Compartido (Grupos y Personas)», sobre la maqueta v2 que aprobó Jürgen el 26-nov (13:18 Lima), con su
ajuste del punto 6: Nuevo gasto, Voz, Foto e Yala IA de Personas son las MISMAS pantallas de Grupos.

## Qué cambia para quien usa Yala

- **Entrar sin grupo:** sin grupos, Compartido enseña los chips «Grupos | Personas», la fila «Nuevo gasto · Voz · Foto ·
  Yala IA» y un vacío por chip. La cuenta se pide al crear algo (una persona o un grupo), nunca al entrar.
- **¿Con quién?:** el selector de grupo de Nuevo gasto, Voz, Foto e Yala IA lista grupos y personas y deja «Escribir un
  nombre». Sin nadie con quien apuntar, «Nuevo gasto» y Voz/Foto/IA abren primero ese selector.
- **Añadir persona:** la barra del chip Personas abre la hoja del nombre; al crearla sale la hoja de siempre de invitar,
  con su texto («Marta ya está en Compartido»).
- **Invitar a una persona:** el mismo enlace (con `k=p`). Quien lo abre ve «Jürgen te invita a Yala», entra con «Unirme a
  Yala» y queda dentro sin aprobación; al entrar, «Ya estás conectado con Jürgen». La web de invitación dice lo mismo.
- **La hoja «Grupo» del + sin grupos** ya no corta el camino: «Apuntarlo con una persona» primero, «Crear grupo» después.

## Por dentro

- `create_person_group` (g38_01, aplicada en staging): la persona nace en el servidor con su sitio reservado (miembro sin
  cuenta). `join_group` deja que quien abre el enlace ocupe ese sitio y entre activo; un tercero no entra.
- El Worker deja pasar `create_person_group` con la llave de cifrado y avisa a quien creó la persona cuando la otra entra.

## Hecha cuando

Una cuenta nueva termina el onboarding, entra a Compartido sin crear grupo, registra un gasto con una persona por Nuevo
gasto, Voz, Foto o Yala IA (las pantallas de Grupos) y la invita con el enlace; quien abre el enlace ve el texto nuevo y
entra sin aprobación.

## Device-QA (iPhone, contra staging)

1. Con «Yala Dev» y una cuenta de staging, en Compartido sin grupos: «Nuevo gasto» → «Escribir un nombre» → «Marta» →
   «Añadir». Esperado: se abre Nuevo gasto con Marta; guardar deja a Marta en Personas con su saldo.
2. «Añadir persona» → «Beto» → «Invitar por WhatsApp u otra app». Abrir el enlace en otro teléfono con otra cuenta.
   Esperado: «Jürgen te invita a Yala», «Unirme a Yala» y «Ya estás conectado», sin «Esperando aprobación». En el primer
   teléfono llega el aviso y Beto aparece con cuenta.
3. Repetir el enlace de Beto con una tercera cuenta. Esperado: «Enlace no válido».
4. Voz y Foto con una persona: el reparto sale entre tú y la persona.

## Pendiente fuera de este lote

- g38_01 y g37_01 en producción, y el Worker v4 desplegado: los decide Jürgen (orden SQL → Worker → app).
