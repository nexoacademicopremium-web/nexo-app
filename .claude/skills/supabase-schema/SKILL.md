# Nexo Académico — Supabase Schema

> **Mantener al día**: actualizar esta skill siempre que se añadan/modifiquen tablas, columnas o políticas.

## Funciones SECURITY DEFINER (helpers RLS)

Todas están en `public`, son `STABLE` y **bypasean RLS** en su propia tabla para evitar recursión infinita entre policies de distintas tablas.

| Función | Devuelve | Uso |
|---|---|---|
| `is_admin()` | `BOOLEAN` | `TRUE` si `auth.uid()` tiene `rol = 'admin'` en `usuarios` |
| `get_profesor_id()` | `UUID` | `id` de la fila de `profesores` del usuario actual |
| `get_alumno_id()` | `UUID` | `id` de la fila de `alumnos` del usuario actual |
| `get_alumno_nivel()` | `TEXT` | `nivel` del alumno actual (`'1ESO'`…`'2BACH'`) |

> `get_alumno_asignaturas()` **no existe todavía** — mencionada en el diseño, pendiente de crear si se necesita en una policy.

---

## Tablas principales

### `usuarios`
Espeja `auth.users` (mismo UUID como PK).

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | FK → `auth.users(id)` ON DELETE CASCADE |
| `email` | `TEXT NOT NULL` | |
| `rol` | `TEXT NOT NULL` | `'alumno' \| 'profesor' \| 'admin'` |
| `nombre` | `TEXT NOT NULL` | |
| `apellidos` | `TEXT NOT NULL` | default `''` |
| `activo` | `BOOLEAN` | default `TRUE` |
| `created_at` | `TIMESTAMPTZ` | |

**RLS:**
- `usuarios_self_read` — SELECT donde `id = auth.uid()`
- `usuarios_admin_all` — ALL donde `is_admin()`
- `usuarios_prof_for_alumno` — SELECT: permite a un alumno leer la fila del usuario de su profesor; cubre 2 vías: `alumnos.profesor_id` o junction `alumno_profesor`. **NO incluye sesiones** — causaría bucle infinito con `sesiones_profesor_own` → `profesores` RLS → `sesiones` → ∞
- `usuarios_alumnos_for_prof` — SELECT: permite a un profesor leer las filas de usuarios de sus alumnos (via FK `alumnos.profesor_id` o via `alumno_profesor`); necesario para que el panel profesor muestre nombre/apellidos en "Mis alumnos"

---

### `alumnos`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `usuario_id` | `UUID NOT NULL` | FK → `usuarios(id)` ON DELETE CASCADE |
| `nivel` | `TEXT` | `'1ESO'\|'2ESO'\|'3ESO'\|'4ESO'\|'1BACH'\|'2BACH'` |
| `asignaturas` | `TEXT[]` | **Legacy** — ya no se usa; las asignaturas reales están en `alumno_asignaturas` |
| `horario_habitual` | `TEXT` | |
| `modalidad` | `TEXT` | `'presencial'\|'online'`, default `'presencial'` |
| `direccion` | `TEXT` | |
| `telefono_familia` | `TEXT` | |
| `horas_bono_total` | `NUMERIC(6,2)` | default `0` |
| `horas_bono_restantes` | `NUMERIC(6,2)` | default `0` — se descuenta vía `_consumir_horas_sesion` |
| `horas_deuda` | `NUMERIC(6,2)` | default `0` — horas consumidas sin bono activo; se descuentan del siguiente bono al activarse |
| `fecha_inicio` | `DATE` | |
| `profesor_id` | `UUID` | FK → `profesores(id)` — profesor principal (legacy, añadido vía ALTER) |
| `observaciones` | `TEXT` | Añadido vía migración; notas internas |
| `activo` | `BOOLEAN` | default `TRUE` |
| `created_at` | `TIMESTAMPTZ` | |

**RLS:**
- `alumnos_self_read` — SELECT donde `usuario_id = auth.uid()`
- `alumnos_admin_all` — ALL donde `is_admin()`
- `alumnos_profesor_read` — SELECT: EXISTS en `alumno_profesor` donde `alumno_id = alumnos.id AND profesor_id = get_profesor_id()` (solo junction, no más FK directa)

---

### `profesores`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `usuario_id` | `UUID NOT NULL` | FK → `usuarios(id)` ON DELETE CASCADE |
| `especialidades` | `TEXT[]` | **Legacy** — ya no se usa; las asignaturas reales están en `profesor_asignaturas` |
| `zona` | `TEXT` | |
| `telefono` | `TEXT` | |
| `estudios` | `TEXT` | |
| `nivel_max` | `TEXT` | `'1ESO'`…`'2BACH'` |
| `fecha_inicio` | `DATE` | |
| `observaciones` | `TEXT` | Añadido vía migración; notas internas |
| `activo` | `BOOLEAN` | default `TRUE` |
| `created_at` | `TIMESTAMPTZ` | |

**RLS:**
- `profesores_self_read` — SELECT donde `usuario_id = auth.uid()`
- `profesores_admin_all` — ALL donde `is_admin()`
- `profesores_alumno_read` — SELECT: alumno puede leer su profesor; cubre 2 vías: `alumnos.profesor_id` o junction `alumno_profesor`. **NO incluye sesiones** — causaría bucle infinito con `sesiones_profesor_own` → `profesores` RLS → `sesiones` → ∞

---

### `asignaturas` *(añadida vía SQL editor — no en schema.sql)*

Catálogo cerrado de materias. Lista fija definida por el admin.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `SMALLINT PK` | |
| `nombre` | `TEXT UNIQUE NOT NULL` | Ej: `'Matemáticas'`, `'Lengua'` |

**RLS:** sin RLS (lectura pública — o policy `SELECT TRUE` para todos).

---

### `alumno_asignaturas` *(añadida vía SQL editor — no en schema.sql)*

Junction table: qué asignaturas necesita repasar cada alumno (los checkboxes de la ficha).

| Columna | Tipo | Notas |
|---|---|---|
| `alumno_id` | `UUID NOT NULL` | FK → `alumnos(id)` ON DELETE CASCADE |
| `asignatura_id` | `SMALLINT NOT NULL` | FK → `asignaturas(id)` |
| UNIQUE | `(alumno_id, asignatura_id)` | |

**Uso en UI:** determina qué material ve el alumno y qué asignaturas aparecen en el desplegable al asignar profesor.

**RLS:** `admin_all` + `alumno_read` (alumno_id = get_alumno_id()) — pendiente confirmar si está creada.

---

### `profesor_asignaturas` *(añadida vía SQL editor — no en schema.sql)*

Junction table: qué asignaturas imparte cada profesor (los checkboxes de la ficha).

| Columna | Tipo | Notas |
|---|---|---|
| `profesor_id` | `UUID NOT NULL` | FK → `profesores(id)` ON DELETE CASCADE |
| `asignatura_id` | `SMALLINT NOT NULL` | FK → `asignaturas(id)` |
| UNIQUE | `(profesor_id, asignatura_id)` | |

**Uso en UI:** determina la columna "Especialidades" de la lista de profesores.

**RLS:** `admin_all` + `profesor_read` (profesor_id = get_profesor_id()) — pendiente confirmar si está creada.

---

### `alumno_profesor`

Many-to-many: un alumno puede tener varios profesores, cada uno para una asignatura concreta.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `alumno_id` | `UUID NOT NULL` | FK → `alumnos(id)` ON DELETE CASCADE |
| `profesor_id` | `UUID NOT NULL` | FK → `profesores(id)` ON DELETE CASCADE |
| `asignatura` | `TEXT` | **Legacy vacío** — no se usa; la fuente real es `asignatura_id` |
| `asignatura_id` | `SMALLINT` | FK → `asignaturas(id)` — añadido vía SQL editor; es el campo real |
| `created_at` | `TIMESTAMPTZ` | |
| UNIQUE | `(alumno_id, profesor_id, asignatura_id)` | permite un profesor por asignatura (≠ UNIQUE antiguo que era solo alumno+profesor) |

**Nota crítica**: el admin inserta con `asignatura_id`, nunca con `asignatura TEXT`. Para leer el nombre de la asignatura hay que hacer join: `.select('asignatura_id, asignaturas(nombre)')` y usar `r.asignaturas?.nombre`.

**RLS:**
- `alumno_profesor_admin_all` — ALL donde `is_admin()`
- `alumno_profesor_alumno_read` — SELECT donde `alumno_id = get_alumno_id()`
- `alumno_profesor_profesor_read` — SELECT donde `profesor_id = get_profesor_id()`

---

### `bloques` *(añadida vía SQL editor — no en schema.sql)*

Bloques temáticos del material, filtrados por asignatura y nivel.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `SERIAL PK` | |
| `asignatura_id` | `SMALLINT NOT NULL` | FK → `asignaturas(id)` |
| `nivel` | `TEXT NOT NULL` | `'1ESO'`…`'2BACH'\|'todos'` |
| `nombre` | `TEXT NOT NULL` | |

**RLS:** admin_all; lectura abierta (o sin RLS).

---

### `temas` *(añadida vía SQL editor — no en schema.sql)*

Subtemas dentro de un bloque.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `SERIAL PK` | |
| `bloque_id` | `INTEGER NOT NULL` | FK → `bloques(id)` |
| `nombre` | `TEXT NOT NULL` | |

**RLS:** admin_all; lectura abierta.

---

### `material`

Fichas de material educativo (PDFs y recursos).

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `titulo` | `TEXT NOT NULL` | |
| `descripcion` | `TEXT` | |
| `nivel` | `TEXT` | `'1ESO'`…`'2BACH'\|'todos'` |
| `asignatura` | `TEXT` | **Legacy** — reemplazado por `asignatura_id` |
| `asignatura_id` | `SMALLINT` | FK → `asignaturas(id)` — añadido vía migración |
| `bloque_tema` | `TEXT` | **Legacy** — reemplazado por `bloque_id` + `tema_id` |
| `bloque_id` | `INTEGER` | FK → `bloques(id)` — añadido vía migración |
| `tema_id` | `INTEGER` | FK → `temas(id)` — añadido vía migración |
| `archivo_url` | `TEXT` | URL pública de Supabase Storage (bucket `nexo-files`) |
| `tipo` | `TEXT` | `'pdf'\|'recurso'`, default `'pdf'` |
| `subido_por` | `UUID` | FK → `usuarios(id)` |
| `visible` | `BOOLEAN` | default `TRUE` |
| `created_at` | `TIMESTAMPTZ` | |

**RLS:**
- `material_admin_all` — ALL donde `is_admin()`
- `material_alumno_read` — SELECT: `visible=TRUE` AND (asignado vía `material_alumno` OR nivel coincide con `get_alumno_nivel()`)

---

### `material_alumno`

Asignación explícita de material a un alumno concreto.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `material_id` | `UUID NOT NULL` | FK → `material(id)` ON DELETE CASCADE |
| `alumno_id` | `UUID NOT NULL` | FK → `alumnos(id)` ON DELETE CASCADE |
| `asignado_at` | `TIMESTAMPTZ` | |
| `asignado_por` | `UUID` | FK → `usuarios(id)` |
| UNIQUE | `(material_id, alumno_id)` | |

**RLS:**
- `material_alumno_admin_all` — ALL donde `is_admin()`
- `material_alumno_read_own` — SELECT donde `alumno_id = get_alumno_id()`

---

### `sesiones`

Registro de clases impartidas por un profesor. Formulario de 22 campos en 3 secciones.

**Sección 1 — Identificación (6 campos)**

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `profesor_id` | `UUID NOT NULL` | FK → `profesores(id)` |
| `alumno_id` | `UUID NOT NULL` | FK → `alumnos(id)` |
| `asignatura` | `TEXT NOT NULL` | Nombre libre (no FK a asignaturas) |
| `fecha` | `DATE NOT NULL` | |
| `hora_inicio` | `TIME` | |
| `duracion_minutos` | `INTEGER NOT NULL` | default `60`; valores típicos: 60, 90, 120 |

**Sección 2 — Narrativa de sesión (10 campos)**

| Columna | Tipo | Notas |
|---|---|---|
| `contenido_trabajado` | `TEXT` | Qué se hizo en la sesión |
| `estado_alumno_inicio` | `TEXT` | CHECK: `'Activo y receptivo'\|'Normal, sin más'\|'Cansado o apagado'\|'Nervioso o bloqueado'\|'Disperso, con la cabeza en otro lado'` |
| `momento_bloqueo` | `TEXT` | En qué momento se bloqueó / con qué |
| `resolvio_solo` | `TEXT` | Si resolvió o cómo lo resolvió solo |
| `necesito_ayuda` | `TEXT` | Qué tipo de ayuda necesitó |
| `falta_base` | `TEXT` | Si falta base previa y cuál |
| `comparacion_anterior` | `TEXT` | Comparación con sesiones anteriores |
| `nota_estimada` | `NUMERIC(3,1)` | CHECK 0–10; nota estimada al finalizar |
| `arranque_proxima` | `TEXT` | Por dónde arrancar la próxima sesión |
| `tarea_casa` | `TEXT` | Tarea asignada para casa |

**Sección 3 — Progreso y valoraciones (5 campos + observaciones)**

| Columna | Tipo | Notas |
|---|---|---|
| `valoracion_comprension` | `SMALLINT` | CHECK 1–10 |
| `valoracion_aplicacion` | `SMALLINT` | CHECK 1–10 |
| `valoracion_concentracion` | `SMALLINT` | CHECK 1–10 (nuevo; columna añadida vía ALTER) |
| `valoracion_motivacion` | `SMALLINT` | CHECK 1–10 (campo reusado, antes "motivación") — ahora = "Actitud/motivación" |
| `valoracion_autonomia` | `SMALLINT` | CHECK 1–10 (nuevo; columna añadida vía ALTER) |
| `observaciones` | `TEXT` | Observaciones visibles para la familia |
| `observaciones_nexo` | `TEXT` | Notas internas de Nexo (no visibles al alumno) |

**Metadatos y estado**

| Columna | Tipo | Notas |
|---|---|---|
| `estado` | `TEXT NOT NULL` | `'pendiente_confirmacion'\|'confirmada'\|'rechazada'\|'cancelada'`; default `'pendiente_confirmacion'` |
| `excede_bono` | `BOOLEAN` | default `FALSE`; `TRUE` cuando la duración supera las horas restantes del bono — el profesor puede continuar pero queda marcado para revisión admin |
| `registrada_at` | `TIMESTAMPTZ` | default `NOW()` |
| `confirmada_at` | `TIMESTAMPTZ` | |
| `cancelada_por` | `TEXT` | CHECK: `'admin'\|'sistema'` |
| `confirmation_token` | `UUID` | Token único para enlace de email sin auth; default `uuid_generate_v4()` |
| `bono_id` | `UUID` | FK → `bonos(id)`; **añadido vía ALTER TABLE** (no en CREATE TABLE de sesiones — `bonos` se define después de `sesiones` en schema.sql); identifica el primer bono que pagó las horas |
| `horas_deducidas` | `NUMERIC(6,2)` | Horas descontadas del bono `bono_id` (puede ser < duracion si hubo cascada); se registra al confirmar |

**RLS:**
- `sesiones_profesor_own` — ALL: EXISTS profesor del usuario con `id = sesiones.profesor_id`
- `sesiones_alumno_read` — SELECT: EXISTS alumno del usuario con `id = sesiones.alumno_id`
- `sesiones_alumno_confirm` — UPDATE: misma condición; WITH CHECK `estado IN ('confirmada','rechazada')`
- `sesiones_admin_all` — ALL donde `is_admin()`

---

### `informes`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `alumno_id` | `UUID NOT NULL` | FK → `alumnos(id)` |
| `tipo` | `TEXT NOT NULL` | `'mensual'\|'semanal'` |
| `titulo` | `TEXT NOT NULL` | |
| `fecha` | `DATE NOT NULL` | default `CURRENT_DATE` |
| `archivo_url` | `TEXT` | URL Storage |
| `subido_por` | `UUID` | FK → `usuarios(id)` |
| `visible` | `BOOLEAN` | default `TRUE` |
| `created_at` | `TIMESTAMPTZ` | |

**RLS:**
- `informes_alumno_read` — SELECT: `visible=TRUE` AND EXISTS alumno del usuario
- `informes_admin_all` — ALL donde `is_admin()`

---

### `tarifas_bonos`

Catálogo de precios cerrado, editable por admin. Primaria solo tiene Presencial. **Presencial es siempre más caro que Online.**

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `SERIAL PK` | |
| `grupo` | `TEXT NOT NULL` | `'Primaria'\|'ESO'\|'Bachillerato'\|'Universidad'` |
| `modalidad` | `TEXT NOT NULL` | `'Presencial'\|'Online'` |
| `horas` | `SMALLINT NOT NULL` | `2\|4\|8\|12` |
| `precio` | `NUMERIC(8,2) NOT NULL` | Presencial > Online para el mismo grupo/horas |
| `activo` | `BOOLEAN` | default `TRUE` |
| UNIQUE | `(grupo, modalidad, horas)` | |

**Precios vigentes (€):**
- Primaria Presencial: 32 / 70 / 135 / 200
- ESO Online: 40 / 90 / 175 / 260 · ESO Presencial: 44 / 94 / 185 / 270
- Bach Online: 42 / 92 / 180 / 265 · Bach Presencial: 46 / 98 / 195 / 285
- Univ Online: 44 / 96 / 190 / 280 · Univ Presencial: 48 / 105 / 205 / 300

**Nivel → grupo mapping (para panel alumno):** `1ESO-4ESO → ESO`, `1BACH-2BACH → Bachillerato`. Primaria/Universidad no existen aún en `alumnos.nivel`.

**RLS:**
- `tarifas_bonos_read_all` — SELECT TRUE (todos los autenticados)
- `tarifas_bonos_admin_all` — ALL donde `is_admin()`

---

### `bonos`

Historial de bonos contratados o solicitados por alumno. Cada bono tiene sus propias columnas de seguimiento de horas; `alumnos.horas_bono_restantes/total` se mantiene en sync como caché del bono activo.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `alumno_id` | `UUID NOT NULL` | FK → `alumnos(id)` ON DELETE CASCADE |
| `horas_contratadas` | `NUMERIC(6,2) NOT NULL` | |
| `horas_consumidas` | `NUMERIC(6,2) NOT NULL DEFAULT 0` | Actualizado por RPCs al confirmar sesiones |
| `horas_restantes` | `NUMERIC(6,2) NOT NULL DEFAULT 0` | Actualizado por RPCs al confirmar sesiones |
| `modalidad` | `TEXT NOT NULL` | `'Presencial'\|'Online'` |
| `precio_base` | `NUMERIC(8,2)` | Precio del catálogo sin descuento |
| `descuento` | `NUMERIC(5,2)` | Porcentaje 0–100; default 0 |
| `precio_final` | `NUMERIC(8,2)` | Calculado: `precio_base * (1 - descuento/100)` |
| `fecha_compra` | `DATE` | default `CURRENT_DATE` |
| `pagado` | `BOOLEAN` | default `FALSE`; admin lo marca cuando recibe el pago |
| `fecha_pago` | `DATE` | Fecha en que el admin marca pagado; determina orden de cola |
| `estado` | `TEXT NOT NULL` | `'reservado'\|'pagado_en_espera'\|'activo'\|'agotado'\|'cancelado'`; default `'reservado'` |
| `notas` | `TEXT` | |
| `agotado_at` | `TIMESTAMPTZ` | Fecha en que el bono quedó agotado; seteada por `_consumir_horas_sesion` / `_activar_siguiente_bono` |
| `created_at` | `TIMESTAMPTZ` | |

**Flujo de estados:**
1. Alumno reserva → `estado='reservado'`, `pagado=false` + botón WhatsApp para confirmar pago
2. Admin marca pagado → si alumno sin bono activo: `estado='activo'`; si ya tiene activo con horas: `estado='pagado_en_espera'`
3. Bono activo se agota → `_consumir_horas_sesion` llama a `_activar_siguiente_bono()` → activo pasa a `agotado`, el primer `pagado_en_espera` (por `fecha_pago`) pasa a `activo`; si hay `horas_deuda` acumulada se descuenta al activar

**Lógica de horas (implementada en `_consumir_horas_sesion` con bucle LOOP):**
- Si hay bono `activo`: consume de él. Si no hay bono `activo` pero sí uno `pagado_en_espera`, lo activa (aplicando `horas_deuda`) y consume de él.
- Si la sesión supera un bono → lo agota y el bucle continúa al siguiente `pagado_en_espera` (N niveles de cascada).
- Si se agotan todos los bonos → el exceso va a `alumnos.horas_deuda`; el siguiente bono al activarse descuenta esa deuda primero.
- La tabla de bonos en admin usa `bono.horas_consumidas/restantes` directamente (no calcula desde `alumnos`)
- `recalcular_bonos_alumno` actualiza también `sesiones.bono_id` y `horas_deducidas` durante el replay

**RLS:**
- `bonos_admin_all` — ALL donde `is_admin()`
- `bonos_alumno_read` — SELECT: EXISTS alumno del usuario con `id = bonos.alumno_id`
- `bonos_alumno_insert` — INSERT: mismo check + `estado = 'reservado'` (reservas desde panel alumno)
- `bonos_profesor_read` — SELECT: EXISTS alumno del profesor (via `profesor_id`, `alumno_profesor`, o `sesiones`); necesario para que el profesor verifique estado de bono antes de registrar sesión

---

### `tests` / `preguntas_test` / `resultados_test`

Tests de autoevaluación.

**`tests`:** `id, titulo, asignatura(TEXT), nivel(TEXT), bloque_tema(TEXT), creado_por, visible, created_at`
- RLS: `tests_alumno_read` (SELECT, `visible=TRUE`) · `tests_admin_all`

**`preguntas_test`:** `id, test_id(FK), enunciado, opcion_a/b/c/d, respuesta_correcta('a'|'b'|'c'|'d'), orden`
- RLS: `preguntas_alumno_read` (SELECT, join a test visible) · `preguntas_admin_all`

**`resultados_test`:** `id, test_id(FK), alumno_id(FK), respuestas(JSONB), nota(NUMERIC), completado_at` · UNIQUE(test_id, alumno_id)
- RLS: `resultados_alumno_own` (ALL, EXISTS alumno del usuario) · `resultados_admin_all`

---

### `calendario_alumno` / `calendario_profesor`

**`calendario_alumno`:** `id, alumno_id(FK), titulo, asignatura, fecha, hora_inicio, duracion_minutos, profesor_nombre, notas, created_at`
- RLS: `cal_alumno_own` (ALL, EXISTS alumno del usuario) · `cal_alumno_admin`

**`calendario_profesor`:** `id, profesor_id(FK), alumno_id(FK nullable), asignatura, fecha, hora_inicio, duracion_minutos, notas, created_at`
- RLS: `cal_profesor_own` (ALL, EXISTS profesor del usuario) · `cal_profesor_admin`

---

### `avisos`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID PK` | |
| `destinatario_rol` | `TEXT` | `'alumno'\|'profesor'\|'todos'` |
| `destinatario_id` | `UUID` | FK → `usuarios(id)`; NULL = por rol |
| `titulo` | `TEXT NOT NULL` | |
| `contenido` | `TEXT NOT NULL` | |
| `creado_por` | `UUID` | FK → `usuarios(id)` |
| `visible` | `BOOLEAN` | default `TRUE` |
| `created_at` | `TIMESTAMPTZ` | |

**RLS:**
- `avisos_read` — SELECT: `visible=TRUE` AND (`destinatario_id = uid` OR `destinatario_rol = 'todos'` OR rol del usuario coincide con `destinatario_rol`)
- `avisos_admin_all` — ALL donde `is_admin()`

---

## RPCs SECURITY DEFINER

| Función | Auth requerida | Descripción |
|---|---|---|
| `_consumir_horas_sesion(p_alumno_id, p_duracion_h, p_fecha_ts?)` | Interno | **Bucle** de cascada bono a bono. Si no hay bono `activo` pero sí `pagado_en_espera`, lo activa aplicando `horas_deuda` antes de consumir. Si se agotan todos los bonos, acumula el exceso en `alumnos.horas_deuda`. Soporta N bonos encadenados. |
| `_activar_siguiente_bono(p_alumno_id, p_fecha_ts?)` | Interno | Vence bono activo (con `agotado_at`), activa siguiente `pagado_en_espera` aplicando `horas_deuda`; si no hay cola, pone alumnos a 0/0 |
| `_revertir_horas_sesion(p_session_id)` | Interno | Revierte horas de una sesión cancelada al bono correcto; usa `bono_id`+`horas_deducidas` de la sesión para reversión precisa con detección de cascada |
| `process_session_confirmation(p_session_id, p_token, p_action)` | No (enlace email) | Confirma/rechaza sesión por token; busca bono activo o `pagado_en_espera` para registrar `bono_id`+`horas_deducidas`; llama `_consumir_horas_sesion` si confirma |
| `confirmar_sesion_alumno(p_session_id, p_action)` | Sí (alumno) | Igual pero verifica `auth.uid()` = alumno; busca activo o `pagado_en_espera` para `bono_id`+`horas_deducidas` |
| `cancelar_sesion_admin(p_session_id, p_revertir_horas)` | Sí (admin) | Cancela sesión; si `p_revertir_horas=TRUE` y sesión confirmada, llama `_revertir_horas_sesion` para devolución real al bono correcto (con soporte de cascada) |
| `auto_confirm_old_sessions()` | Sí (authenticated) | Confirma sesiones `pendiente_confirmacion` con `registrada_at < NOW() - 72h`; busca activo o `pagado_en_espera` para `bono_id`+`horas_deducidas`; GRANT EXECUTE a `authenticated`; pg_cron cada hora |
| `recalcular_bonos_alumno(p_alumno_id)` | Admin/service | Resetea bonos del alumno y reproduce sesiones confirmadas en orden cronológico; actualiza `sesiones.bono_id` y `horas_deducidas` además de recalcular `horas_consumidas`, `horas_restantes`, `agotado_at` y `horas_deuda`. El DO block al final de schema.sql lo ejecuta para todos los alumnos. |
| `eliminar_sesion_cancelada(p_session_id)` | Sí (alumno) | Elimina físicamente una sesión cancelada propia; verifica `auth.uid()` = alumno y `estado = 'cancelada'` |

---

## Edge Functions

| Función | Descripción |
|---|---|
| `create-user` | Crea usuario en `auth.users` + fila en `usuarios`; usa `SUPABASE_SERVICE_ROLE_KEY`; requiere caller admin |
| `update-user-password` | Actualiza contraseña de un usuario por `user_id`; usa `SUPABASE_SERVICE_ROLE_KEY`; requiere caller admin |

---

## Diagrama de relaciones clave

```
auth.users ──→ usuarios ──→ alumnos ──→ alumno_asignaturas ──→ asignaturas
                         │           └──→ alumno_profesor   ──→ profesores
                         └──→ profesores ──→ profesor_asignaturas ──→ asignaturas
material ──→ bloques ──→ asignaturas
         └──→ temas  ──→ bloques
material_alumno: (material_id, alumno_id)
sesiones: (profesor_id, alumno_id)
```

---

## Notas de mantenimiento

- Los campos `alumnos.asignaturas TEXT[]` y `profesores.especialidades TEXT[]` son **legacy** — el panel admin ya los ignora y usa las junction tables.
- `alumno_profesor.asignatura TEXT` también es legacy — se dejó como TEXT; si se migra a `asignatura_id SMALLINT FK` habrá que actualizar la UI y las policies.
- Las tablas creadas vía SQL editor (marcadas *"no en schema.sql"*) deben añadirse al schema.sql cuando se haga un reset o migración limpia.
