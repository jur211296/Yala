/**
 * Los íconos de la navegación y de los botones, en Lucide: el equivalente de cada SF Symbol de la app (tabla de la
 * maqueta aprobada, `docs/web-app/parecida-a-la-app/`). Decorativos: el texto de al lado los nombra. El tamaño y el trazo
 * los pone la hoja de estilos de cada sitio (`.nv svg`, `.mt svg`, `.ib svg`…).
 *
 * Los de categoría, subcategoría y cuenta no van aquí: salen de lo que guardó la persona, con `simbolos.ts`.
 */
import { Calendar, CalendarClock, ChartColumn, ChartPie, Ellipsis, Eye, Inbox, LayoutGrid, List, Plus, Search, Settings, Sparkles, UserRound, Users } from "lucide-react";

const P = { "aria-hidden": true, focusable: false } as const;

export const Icons = {
  /** rectangle.grid.2x2.fill */
  panel: <LayoutGrid {...P} />,
  /** tray.full */
  bandeja: <Inbox {...P} />,
  /** list.bullet.rectangle */
  registros: <List {...P} />,
  /** calendar: la pestaña Planificación, que reúne Presupuestos y Pagos planificados */
  planificacion: <Calendar {...P} />,
  /** chart.pie.fill */
  presupuestos: <ChartPie {...P} />,
  /** calendar.badge.clock */
  pagos: <CalendarClock {...P} />,
  /** chart.bar.fill */
  estadisticas: <ChartColumn {...P} />,
  /** person.2.fill */
  grupos: <Users {...P} />,
  /** sparkles */
  ia: <Sparkles {...P} />,
  /** gearshape */
  configurar: <Settings {...P} />,
  /** ellipsis */
  mas: <Ellipsis {...P} />,
  plus: <Plus {...P} />,
  /** magnifyingglass */
  search: <Search {...P} />,
  eye: <Eye {...P} />,
  /** person.crop.circle: el avatar que abre los ajustes */
  avatar: <UserRound {...P} />,
};
