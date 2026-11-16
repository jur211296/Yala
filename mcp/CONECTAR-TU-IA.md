# Conectar tu IA a Yala — Claude, ChatGPT y Grok

Con el conector, tu IA lee tus finanzas de la nube de Yala y **apunta** gastos e ingresos como borradores en tu
Bandeja: le dices «apunta 25 soles de almuerzo» y, al abrir Yala, lo tienes en la Bandeja para confirmarlo de un
toque. Nada cuenta en tus saldos ni presupuestos hasta que lo confirmas, y la IA no puede cambiar ni borrar nada.

Solo funciona con la nube de Yala (Ajustes → «Dónde viven tus datos» → «Activar la nube»).

**Si ya tenías Yala conectado** de antes de esta función, tu IA sigue solo leyendo: vuelve a conectar (quitar y añadir
el conector) para aceptar el permiso nuevo, que es el que dice que podrá apuntar.

**La dirección del conector**

| Entorno | URL |
|---|---|
| Staging (pruebas) | `https://yala-mcp-staging.misty-surf-6866.workers.dev/mcp` |
| Producción | aún sin desplegar: falta elegir el dominio (`workers.dev` o `mcp.yala-app.pe`) |

En staging se inicia sesión con un usuario de prueba (email y contraseña, `~/Secrets/yala-supabase-test/`). En
producción, con Apple o Google, la misma cuenta que en la app.

## Claude (probado)

- **claude.ai, Claude Desktop o el móvil:** Ajustes → Conectores → *Añadir conector personalizado* → la URL.
- **Claude Code:** `claude mcp add --transport http yala <URL>` y luego `/mcp` → `yala` → *Authenticate*.

Se abre la pantalla de permiso de Yala (*Continuar*) y después el inicio de sesión.

## ChatGPT (según la documentación de OpenAI; sin probar con una cuenta real)

Los conectores propios de ChatGPT viven en el **modo desarrollador**, que es el que deja usar herramientas que
escriben. Hace falta un plan de pago (Plus, Pro, Business, Enterprise o Edu, según la fuente); en Business y
Enterprise, que un administrador permita conectores propios.

1. ChatGPT → Ajustes → *Apps y conectores* → *Ajustes avanzados* → activar **Modo desarrollador**. OpenAI ha movido
   este interruptor durante 2026: si no está ahí, buscar «Developer mode» en su centro de ayuda.
2. *Crear* un conector: nombre «Yala», la URL de arriba, autenticación **OAuth**.
3. Se abre la pantalla de permiso de Yala y el inicio de sesión. Al volver, el conector queda en la lista.
4. En un chat nuevo, elegir el conector y pedir «apunta 25 soles de almuerzo». ChatGPT pide confirmación antes de
   cada herramienta que escribe.

Del lado de Yala ya está todo: el conector acepta las dos vueltas OAuth que documenta OpenAI
(`https://chatgpt.com/connector_platform_oauth_redirect` y `https://chatgpt.com/connector/oauth/{id}`) y el registro
dinámico de clientes, que es lo que usa ChatGPT.

## Grok (medido en su documentación: SÍ acepta conectores propios; sin probar con una cuenta real)

xAI documenta conectores MCP remotos en grok.com: *grok.com/connectors* → *New Connector* → *Custom* → la URL. El
inicio de sesión se abre en una ventana emergente (el navegador tiene que permitirlas para grok.com). Según guías de
terceros, son de los planes de pago; en Grok Business y Enterprise los da de alta un administrador. Un conector
añadido a mitad de una conversación puede no verse: abrir una nueva.

**Lo que falta en Yala:** xAI no publica la vuelta OAuth que usa Grok, y el conector solo acepta las que conoce. El
primer intento sale con «Esta aplicación no está autorizada a conectarse con Yala» y deja la vuelta en el log del
Worker (`mcp_autorizacion`, motivo `vuelta_no_permitida`). Se añade exacta en `EXTRA_REDIRECT_URIS`
(`wrangler.toml`) y se despliega; el segundo intento entra. Pasos: `RUNBOOK-produccion.md`, «Tu IA registra en Yala».

## Qué puede hacer la IA

| Herramienta | Qué hace |
|---|---|
| `listar_cuentas`, `listar_categorias`, `buscar_movimientos`, `resumen_periodo`, `estado_presupuestos`, `listar_recurrentes` | Leen. No cambian nada. |
| `apuntar_movimiento` | Deja UN borrador en la Bandeja: importe, gasto o ingreso, divisa, nota, fecha (hoy o antes) y, si los nombras, cuenta y categoría. |

Si nombras una cuenta o una categoría que no existe, o que encaja con varias, la IA recibe las opciones y te pregunta.
Si no las nombras, el borrador las pide en la Bandeja (salvo que tengas una sola cuenta en esa divisa). Límites: 50
movimientos al día y 100 esperando en la Bandeja.
