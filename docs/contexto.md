# Contexto del proyecto Centinela

Documento de referencia para desarrolladores e IAs que trabajan en el monorepo. Para clonado y submódulos ver [README.md](../README.md). Para diagramas y arquitectura detallada ver [ARQUITECTURA.md](./ARQUITECTURA.md).

## 1. Visión general

**Centinela** es un sistema de seguridad ciudadana para Milagro (Ecuador): reportes ciudadanos, detección de audio por IA (disparos, gritos), alertas operativas, notificaciones push/Telegram/email y panel web para operadores y patrulleros.

| Parte | Repo / carpeta | Stack |
|-------|----------------|-------|
| Backend | `centinela-project` (este repo) | NestJS, NATS, PostgreSQL/PostGIS, Docker |
| Panel web | `webcentinela` ([CentinelaFrontend](https://github.com/Kaisitop/CentinelaFrontend)) | Next.js, Tailwind, Leaflet, Socket.IO |
| App ciudadana | Flutter (repo aparte) | HTTP + deep links |

---

## 2. Microservicios

Comunicación interna por **NATS**. Solo **c-gateway** expone HTTP/WS al exterior.

| Servicio | Responsabilidad |
|----------|-----------------|
| **c-gateway** | REST `/api`, WebSocket `/realtime`, Cloudinary, proxy de auth y dominio |
| **ms-auth** | Usuarios, JWT, roles, permisos, email vía eventos NATS, mantenimiento usuarios |
| **ms-core** | Zonas, nodos, eventos, reportes, alertas, patrullaje GPS, mapa de calor, mantenimiento operativo |
| **ms-notificaciones** | Push OneSignal/FCM, Telegram (grupo staff + canal ciudadanos), SMTP (verificación y reset) |
| **ms-ia** | Clasificación YAMNet sobre WAV |
| **ms-IoT-Bridge** | MQTT → NATS (eventos y heartbeat) |

**Base de datos:** un PostgreSQL (`centinela_db`), esquemas `identity` (auth) y `app` (operación).

---

## 3. Roles y clientes

| Rol | Cliente | Acceso |
|-----|---------|--------|
| **Admin** | Panel web | Todo + mantenimiento (purge demo) + usuarios |
| **Operador** | Panel web | Alertas, reportes, mapa, cierre de casos |
| **Policia** | Panel `/patrullaje` (vista móvil) | GPS, en camino, informe en sitio, ruta OSRM |
| **Ciudadano** | App móvil | Reportes, registro, reset password vía deep link app |

El login del panel **rechaza** rol Ciudadano (`webcentinela/lib/auth-service.ts`).

---

## 4. Ciclo de vida de alertas

Estados en `app.alertas.estado`:

```text
activa → en_proceso → reconocida → cerrada | falsa_alarma | completada
         (patrulla      (informe      (operador
          en camino)     en sitio)     cierra)
```

| Transición | Quién | Endpoint |
|------------|-------|----------|
| `activa` → `en_proceso` | Patrullero | `POST /api/alertas/:id/en-camino` |
| `en_proceso` → `reconocida` | Patrullero | `POST /api/alertas/:id/atender-campo` (informe + evidencia) |
| `activa` / `en_proceso` / `reconocida` → cierre | Operador/Admin | `POST /api/alertas/:id/cerrar` |

El patrullero **no puede cerrar** alertas; solo reconocer en campo. Al cerrar desde el operador, el panel patrulla cancela la ruta activa vía WebSocket `alerta.updated`.

Push al crear alerta: **solo al patrullero más cercano** (GPS reciente); fallback a todos los policías (`ms-notificaciones` + NATS `patrullaje.findNearest`).

### Severidad y prioridad (escala 1–5)

Existen **dos escalas independientes** según el origen de la alerta:

**a) Reportes ciudadanos** — catálogo fijo en `ms-core/src/reportes/constants/reporte-tipos.ts` (`prioridad` del reporte = `severidadAlerta` de la alerta generada):

| Tipo | Prioridad / Severidad |
|------|----------------------|
| Pánico/SOS, Homicidio/Sicariato, Secuestro | **4** |
| Robo, Extorsión | **3** |
| Persona sospechosa, Vehículo sospechoso | **2** |

**b) Eventos de audio IA (nodos IoT)** — sugerida por `ms-ia/inference/engine.py` al clasificar:

| Detección | Severidad |
|-----------|-----------|
| Disparo | **3** |
| Grito u otro sonido de alerta | **2** |
| Sonido normal (sin alerta) | **1** |

**Decisión de diseño:** el pánico ciudadano (4) pesa más que un disparo detectado por IA (3) porque el botón SOS es una **confirmación humana activa**, mientras que la clasificación acústica es probabilística (un "disparo" de YAMNet puede ser un petardo o un escape). Por eso la detección IA además pasa un filtro de confirmación antes de generar alerta operativa: confianza mínima o corroboración de un **segundo nodo** en la misma zona (`ms-core/src/eventos/confirmacion-alertas.service.ts`).

En el panel: severidad ≥ 4 pinta rojo, 3 ámbar, ≤ 2 verde.

### Nivel de riesgo por zona (`app.zonas.riesgo_nivel`, 1–5)

Evaluación por parroquia del cantón Milagro (reportes de incidentes, presencia policial y contexto de bandas):

| Zona | Riesgo | Justificación |
|------|--------|---------------|
| Milagro (cabecera urbana) | **4** | Mayor población; concentra homicidios, sicariatos, robos y extorsiones |
| Roberto Astudillo (rural) | **4** | Alta incidencia criminal; sicariatos y disputas territoriales; zona de tránsito |
| Chobo (rural) | **3** | Incidentes violentos notables; violencia que migra desde la cabecera y las vías |
| Mariscal Sucre / Huaques (rural) | **3** | Menor densidad y menos violencia letal reportada |

Valores seed en `ms-core/prisma/zonas_milagro.json`. Las geometrías (polígonos parroquiales) provienen del **Geoportal del INEC** (Geografía Estadística → [descargas](https://www.ecuadorencifras.gob.ec/documentos/web-inec/Geografia_Estadistica/Micrositio_geoportal/descargas.html), GeoPackage del clasificador geográfico).

---

## 5. Autenticación y correos

| Flujo | Enlace en email |
|-------|-----------------|
| Verificar email (registro) | `PUBLIC_WEB_URL/verify-email?token=...` |
| Reset / establecer contraseña **panel** | `PUBLIC_WEB_URL/reset-password?token=...` (`channel: web`) |
| Reset **app ciudadana** | `PUBLIC_API_URL/api/auth/reset-password/open?token=...` (bridge → `centinela://`) |

Alta de usuario por admin: email de reset con canal **web** (no deep link app).

Eventos NATS de email (emitidos por `ms-auth`, consumidos por `ms-notificaciones`):

- `email.send_verification`
- `email.send_password_reset` (payload incluye `channel: 'web' | 'app'`)

SMTP obligatorio en Docker (`SMTP_*`, `MAIL_FROM` en `.env` raíz).

---

## 6. Tiempo real

- Gateway publica en Socket.IO: `alerta.created`, `alerta.updated`, `reporte.*`, `evento.*`, `patrullero.position`
- Frontend: `webcentinela/lib/use-centinela-realtime.ts` (`NEXT_PUBLIC_WS_ENABLED=true`)
- Patrullaje usa eventos para refrescar mapa y **quitar ruta** si la alerta se cierra

---

## 7. Convenciones técnicas (obligatorias)

### NATS

- Variable estándar: `NATS_SERVICE=nats://nats:4222` (nombre del servicio Docker)
- En `docker-compose.yml`, microservicios dependen de NATS con `condition: service_healthy`

### Prisma 7+

- Cliente generado en `./generated/prisma`
- Excluir `prisma` en `tsconfig.build.json` de servicios Nest
- Arranque: `docker-entrypoint.sh` → espera Postgres → `prisma db push` → `seed`

### PostgreSQL en Docker

- Host interno: `postgres:5432` (no el puerto mapeado al host)

### Submódulos Git

- Código vive en repos hijos; el monorepo guarda **punteros SHA**
- Tras push en un microservicio: `git submodule update --remote --merge` + commit del puntero en el repo principal

### NestJS — módulos nuevos

- Importar dependencias explícitas (`PrismaModule`, `JwtModule`, etc.) en cada módulo; no asumir providers globales

---

## 8. Panel web (webcentinela) — módulos principales

| Ruta | Uso |
|------|-----|
| `/` | Dashboard: zonas, nodos, alertas, mapa |
| `/alertas` | Gestión operador (reconocer, cerrar, filtros) |
| `/reportes` | Reportes ciudadanos |
| `/patrullaje` | Vista policía: GPS, en camino, ruta, informe |
| `/configuracion` | Cuenta, alertas push, capas mapa, mantenimiento (admin) |
| `/forgot-password`, `/reset-password` | Recuperación contraseña panel |

Servicios clave: `lib/api.ts`, `lib/auth-service.ts`, `lib/core-service.ts`, `lib/routing.ts` (proxy OSRM).

---

## 9. Despliegue local

```bash
# Raíz del monorepo
cp .env.example .env   # completar SMTP, Cloudinary, Telegram, etc.
docker compose up --build -d

# Frontend (repo aparte)
cd ../webcentinela
cp .env.example .env.local   # NEXT_PUBLIC_API_URL=http://localhost:3000/api
npm run dev
```

Modelo IA: copiar `my_yamnet_classifier.h5` → `ms-ia/models/` antes del build.

Usuarios seed: `admin@centinela.com` / `Admin123!`, `operador@`, `policia@` (ver `ms-auth/prisma/seed.ts`).

---

## 10. Mantenimiento (solo admin)

- `POST /api/admin/purge-demo-data` — limpia datos operativos + usuarios no seed (`confirmPhrase: LIMPIAR DATOS`)
- UI en `webcentinela` → Configuración → Mantenimiento

---

## 11. Documentación relacionada

| Archivo | Contenido |
|---------|-----------|
| [DOCUMENTACION_DESARROLLO.md](./DOCUMENTACION_DESARROLLO.md) | Documentación completa del desarrollo — backend |
| [DOCUMENTACION_DESARROLLO_FRONTEND.md](./DOCUMENTACION_DESARROLLO_FRONTEND.md) | Documentación completa del desarrollo — panel web |
| [ARQUITECTURA.md](./ARQUITECTURA.md) | Índice de arquitectura |
| [ARQUITECTURA_BACKEND.md](./ARQUITECTURA_BACKEND.md) | Backend detallado |
| [ARQUITECTURA_FRONTEND.md](./ARQUITECTURA_FRONTEND.md) | Frontend y app |
| [CENTINELA_MER_Seguridad.md](./CENTINELA_MER_Seguridad.md) | Modelo entidad-relación |
| [CENTINELA_Inseguridad_Violencia_Urbana.md](./CENTINELA_Inseguridad_Violencia_Urbana.md) | Requisitos de negocio |
| `c-gateway/README.md` | Endpoints HTTP |
| `ms-auth/README.md`, `ms-core/README.md`, … | Guías por microservicio |
