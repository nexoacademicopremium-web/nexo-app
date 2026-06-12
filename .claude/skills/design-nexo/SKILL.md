# Nexo Académico — Identidad Visual

## Paleta de colores

```css
--dark:    #04071b   /* fondo más oscuro, topbar, sidebar */
--navy:    #154ca9   /* azul primario, botones CTA, nav activo */
--blue:    #6eaef0   /* azul claro, acentos, iconos, links */
--bg:      #060d20   /* fondo página */
--surface: #0a1530   /* cards, modales */
--border:  #1a2a4a   /* bordes principales */
--border2: #0f1f35   /* bordes sutiles, separadores */
--txt:     #e0eaf8   /* texto principal */
--muted:   #4a6080   /* texto secundario, placeholders */
--soft:    #a8c8f0   /* texto suave, labels */
--green:   #1a7f5e   /* éxito, visible, confirmaciones */
--green-lt:#0d2d1e   /* fondo verde suave */
--amber:   #b45309   /* advertencias */
--amber-lt:#2d1e0d   /* fondo amber suave */
--red:     #c0392b   /* error, eliminar */
--red-lt:  #2d0d0d   /* fondo rojo suave */
```

### Crema (uso tipográfico/decorativo)
`#f4f1e8` — no se usa como fondo de UI sino como acento cálido o contraste en títulos sobre oscuro.

### Variaciones de azul para asignaturas (dentro de paleta)
Usar estas variaciones para identificar asignaturas, siempre con fondo oscuro derivado:
- Azul primario:  `#154ca9` / bg `#0a1a30`
- Azul claro:     `#6eaef0` / bg `#0f2240`
- Violeta-azul:   `#7c3aed` / bg `#1a0f30`
- Cian-azul:      `#0891b2` / bg `#0a1e2a`
- Verde-azul:     `#1a7f5e` / bg `#0d2d1e`
- Amber (cálido): `#b45309` / bg `#2d1e0d`

## Tipografía

- **DM Sans** (300, 400, 500, 600) — texto UI, labels, botones, tablas
- **DM Serif Display** — títulos de sección destacados, branding (no usado aún en panel, reservado para marketing/landing)

## Componentes reutilizables

### Cards
```css
.card {
  background: var(--surface);       /* #0a1530 */
  border: .5px solid var(--border); /* #1a2a4a */
  border-radius: 10px;
  overflow: hidden;
  margin-bottom: 16px;
}
.card-head {
  padding: 13px 16px;
  border-bottom: .5px solid var(--border);
  display: flex; align-items: center; justify-content: space-between;
}
.card-title { color: var(--soft); font-size: 13px; font-weight: 500; }
.card-title i { font-size: 15px; color: var(--blue); }
```

### Botones
```css
/* Primario (CTA) */
.btn-primary { background: var(--navy); color: #fff; border: none; border-radius: 7px; padding: 9px 16px; font-size: 13px; font-weight: 500; }
.btn-primary:hover { background: #1a5cc9; }

/* Ghost */
.btn-ghost { background: transparent; color: var(--blue); border: .5px solid var(--border); border-radius: 7px; padding: 7px 13px; font-size: 12px; }

/* Danger */
.btn-danger { background: var(--red-lt); color: var(--red); border: .5px solid var(--red); border-radius: 6px; padding: 6px 12px; font-size: 12px; }

/* Edit */
.btn-edit { background: #0a1a30; color: var(--blue); border: .5px solid var(--border); border-radius: 6px; padding: 6px 12px; font-size: 12px; }
```

### Pills / Badges
```css
.pill { font-size: 10px; padding: 2px 8px; border-radius: 20px; font-weight: 500; }
.pill-eso   { background: #0f2240; color: var(--blue); }
.pill-ok    { background: var(--green-lt); color: var(--green); }
.pill-grey  { background: var(--border2); color: var(--muted); }
.pill-warn  { background: var(--amber-lt); color: var(--amber); }
.pill-red   { background: var(--red-lt); color: var(--red); }
```

### Formularios (modales)
```css
label.fl { color: var(--soft); font-size: 11px; font-weight: 500; margin-bottom: 5px; margin-top: 14px; }
.fi { background: var(--dark); border: .5px solid var(--border); border-radius: 7px; padding: 10px 12px; color: var(--txt); font-size: 13px; }
.fi:focus { border-color: var(--blue); }
```

### Modales
```css
.modal-overlay { background: rgba(4,7,27,.88); }
.modal-box { background: var(--surface); border: .5px solid var(--border); border-radius: 14px; padding: 28px; max-width: 560px; }
```

### Tablas
```css
.tabla th { color: var(--muted); font-size: 10px; text-transform: uppercase; letter-spacing: .6px; border-bottom: .5px solid var(--border); }
.tabla td { padding: 11px 14px; border-bottom: .5px solid var(--border2); font-size: 13px; }
.tabla tr:hover td { background: var(--border2); }
```

## Iconos

Librería: **Tabler Icons** (`@tabler/icons-webfont@latest`) vía CDN.
Uso: `<i class="ti ti-[nombre]"></i>`

Iconos frecuentes en Nexo:
- Navegación: `ti-users`, `ti-chalkboard`, `ti-files`, `ti-list-check`, `ti-bell`, `ti-home`
- Material: `ti-folder` (bloque), `ti-bookmark` (tema), `ti-file-text` (PDF), `ti-layout-grid` (recurso)
- Acciones: `ti-pencil`, `ti-trash`, `ti-plus`, `ti-check`, `ti-x`
- Estado: `ti-eye`, `ti-eye-off`, `ti-shield-check`, `ti-alert-circle`
- Personas: `ti-user`, `ti-user-circle`

## Layout admin

- **Topbar**: fixed, 54px, `var(--dark)`, border-bottom `var(--border)`
- **Sidebar**: fixed left 220px, `var(--dark)`, nav-items con border-left activo en `var(--blue)`
- **Main**: `margin-left:220px; margin-top:54px; padding:24px 26px`
- **Secciones**: `display:none` por defecto, `display:block` cuando `.active`

## Principios de diseño

1. **Fondo siempre oscuro**: nunca fondos blancos ni grises claros en el panel
2. **Bordes finos**: `.5px solid` — no usar `1px` salvo acento izquierdo (3px)
3. **Color como información**: azul = acción/activo, verde = OK, amber = aviso, rojo = peligro
4. **Sin sombras fuertes**: `box-shadow` solo en dropdowns/menus flotantes
5. **Tipografía compacta**: `font-size` entre 10px-14px en UI, 20px máximo para títulos de página
6. **Coherencia de radio**: tarjetas 10px, botones 6-8px, pills 20px, modales 14px
