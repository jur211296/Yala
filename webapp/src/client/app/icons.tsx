/** Los iconos de la maqueta aprobada, en SVG de trazo. Decorativos: el texto de al lado los nombra. */
const P = { "aria-hidden": true, viewBox: "0 0 24 24", focusable: false } as const;

export const Icons = {
  panel: (
    <svg {...P}>
      <rect x="3" y="3" width="7" height="9" rx="2" />
      <rect x="14" y="3" width="7" height="5" rx="2" />
      <rect x="14" y="12" width="7" height="9" rx="2" />
      <rect x="3" y="16" width="7" height="5" rx="2" />
    </svg>
  ),
  bandeja: (
    <svg {...P}>
      <path d="M3 13h5l2 3h4l2-3h5" />
      <path d="M5 5h14l2 8v6H3v-6z" />
    </svg>
  ),
  registros: (
    <svg {...P}>
      <path d="M8 6h13M8 12h13M8 18h13" />
      <circle cx="4" cy="6" r="1" />
      <circle cx="4" cy="12" r="1" />
      <circle cx="4" cy="18" r="1" />
    </svg>
  ),
  presupuestos: (
    <svg {...P}>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 3v9l6 5" />
    </svg>
  ),
  pagos: (
    <svg {...P}>
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M3 10h18M8 3v4M16 3v4" />
    </svg>
  ),
  estadisticas: (
    <svg {...P}>
      <path d="M4 20V10M10 20V4M16 20v-7M22 20H2" />
    </svg>
  ),
  grupos: (
    <svg {...P}>
      <circle cx="9" cy="8" r="3.5" />
      <path d="M2.5 20c.8-3.6 3.4-5.5 6.5-5.5s5.7 1.9 6.5 5.5" />
      <circle cx="17" cy="9" r="2.5" />
      <path d="M17 14.5c2.3 0 4 1.4 4.5 4" />
    </svg>
  ),
  ia: (
    <svg {...P}>
      <path d="M12 3l1.8 4.7 4.7 1.8-4.7 1.8L12 16l-1.8-4.7-4.7-1.8 4.7-1.8z" />
      <path d="M19 15l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z" />
    </svg>
  ),
  configurar: (
    <svg {...P}>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1" />
    </svg>
  ),
  mas: (
    <svg {...P}>
      <circle cx="5" cy="12" r="1.3" />
      <circle cx="12" cy="12" r="1.3" />
      <circle cx="19" cy="12" r="1.3" />
    </svg>
  ),
  plus: (
    <svg {...P}>
      <path d="M12 5v14M5 12h14" />
    </svg>
  ),
  eye: (
    <svg {...P}>
      <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  ),
};
