# Centinela Project

Monorepo principal del backend **CENTINELA** (UNEMI — Milagro, Ecuador). Orquesta microservicios mediante **Git submodules** y **Docker Compose**.

El panel web está en un repo aparte: [CentinelaFrontend / webcentinela](https://github.com/Kaisitop/CentinelaFrontend).

---

## Estructura

```text
./
├── c-gateway/           → API Gateway (NestJS) — HTTP + WebSocket
├── ms-auth/             → Autenticación, JWT, roles, email (eventos NATS)
├── ms-core/             → Alertas, eventos, reportes, zonas, patrullaje
├── ms-notificaciones/   → Push, Telegram, SMTP
├── ms-ia/               → Clasificación de audio (YAMNet)
├── ms-IoT-Bridge/       → Bridge MQTT → NATS
├── docs/                → Arquitectura, contexto, MER, requisitos
└── docker-compose.yml
```

---

## Documentación

| Documento | Descripción |
|-----------|-------------|
| [**docs/contexto.md**](docs/contexto.md) | **Empezar aquí** — convenciones, flujos, roles, despliegue |
| [docs/DOCUMENTACION_DESARROLLO.md](docs/DOCUMENTACION_DESARROLLO.md) | Documentación completa del desarrollo — backend |
| [docs/DOCUMENTACION_DESARROLLO_FRONTEND.md](docs/DOCUMENTACION_DESARROLLO_FRONTEND.md) | Documentación completa del desarrollo — panel web |
| [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) | Índice de arquitectura |
| [docs/ARQUITECTURA_BACKEND.md](docs/ARQUITECTURA_BACKEND.md) | Backend detallado |
| [docs/ARQUITECTURA_FRONTEND.md](docs/ARQUITECTURA_FRONTEND.md) | Panel Next.js y app |
| [docs/CENTINELA_MER_Seguridad.md](docs/CENTINELA_MER_Seguridad.md) | Diagrama entidad-relación |
| [docs/CENTINELA_Inseguridad_Violencia_Urbana.md](docs/CENTINELA_Inseguridad_Violencia_Urbana.md) | Requisitos de negocio |

Cada microservicio tiene su propio `README.md` con endpoints y patrones NATS.

---

## Clonar

```bash
git clone --recurse-submodules https://github.com/Kaisitop/CentinelaProject.git
cd CentinelaProject
cp .env.example .env   # completar SMTP, Cloudinary, Telegram, JWT, etc.
docker compose up --build -d
```

Si ya clonaste sin submódulos:

```bash
git submodule update --init --recursive
```

Frontend (otro repo):

```bash
cd ../webcentinela
cp .env.example .env.local
npm install && npm run dev
```

Variables mínimas frontend: `NEXT_PUBLIC_API_URL=http://localhost:3000/api`, `NEXT_PUBLIC_WS_ENABLED=true`.

---

## Actualizar submódulos

Tras merge en `main` de un microservicio:

```bash
git submodule update --remote --merge
git add ms-auth ms-core c-gateway ms-notificaciones   # los que cambien
git commit -m "chore: actualizar punteros de submódulos"
git push origin main
```

En otra máquina: `git pull --recurse-submodules`

---

## Flujo de trabajo en un submódulo

```bash
cd ms-core
git checkout main && git pull
# ... cambios ...
git commit -m "feat: ..." && git push origin main
cd ..
git add ms-core
git commit -m "chore: actualizar puntero ms-core"
git push origin main
```

> Los submódulos apuntan a commits SHA concretos. `HEAD detached` dentro de un submódulo es normal.

---

## Servicios Docker (local)

| Contenedor | Puerto | Notas |
|------------|--------|-------|
| centinela-gateway | 3000 | `/api`, WebSocket `/realtime` |
| centinela-db | 5433→5432 | PostgreSQL + PostGIS |
| centinela-nats | 4222, 8222 | Healthcheck en 8222 |
| centinela-mqtt | 1883 | Mosquitto |

---

## Usuarios seed (desarrollo)

| Rol | Email | Contraseña |
|-----|-------|------------|
| Admin | `admin@centinela.com` | `Admin123!` |
| Operador | `operador@centinela.com` | `Operador123!` |
| Policía | `policia@centinela.com` | `Policia123!` |

---

## Cloudinary (fotos y evidencia)

```text
Cliente → POST /api/media/upload?tipo=reporte|evidencia (c-gateway)
       → URLs en reportes (fotosUrls) o alertas (evidenciaUrls) vía ms-core
```

Variables: `CLOUDINARY_*` en `.env` raíz. Detalle en [c-gateway/README.md](c-gateway/README.md).

---

## Modelo IA

Copiar manualmente `my_yamnet_classifier.h5` en `ms-ia/models/` antes de `docker compose build ms-ia`. Ver [ms-ia/README.md](ms-ia/README.md).

---

## Filosofía

Microservicios versionados de forma independiente, orquestación central sin acoplar código en el monorepo — solo punteros Git reproducibles.
