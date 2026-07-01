# 🗂️ Proyecto Principal — Arquitectura con Git Submodules

Este repositorio orquesta múltiples servicios usando **Git Submodules**.

Cada submódulo es un repositorio independiente versionado, y el repositorio principal solo almacena referencias (commits específicos) de cada uno.

> ⚠️ Importante: el repo principal NO contiene código de los servicios, solo punteros a commits exactos (snapshots controlados). Los submódulos están fijados a versiones concretas por diseño.

---

## 📁 Estructura

```
./
├── c-gateway/           → API Gateway (NestJS)
├── ms-auth/             → Autenticación y permisos
├── ms-core/             → Dominio: alertas, eventos, reportes, zonas
├── ms-notificaciones/   → Push (OneSignal), Telegram, Firebase
├── ms-ia/               → Clasificación de audio (YAMNet)
├── ms-IoT-Bridge/       → Bridge MQTT → NATS
└── docker-compose.yml   → Orquestación local
```

El frontend (`webcentinela`) vive en un repositorio aparte: [CentinelaFrontend](https://github.com/Kaisitop/CentinelaFrontend).

---

## 🚀 Clonar el proyecto por primera vez

```bash
git clone --recurse-submodules https://github.com/Kaisitop/CentinelaProject.git
```

Si ya clonaste sin submódulos:

```bash
git submodule update --init --recursive
git submodule sync --recursive
```

---

## 🔄 Actualizar submódulos

Cuando haces **merge a `main`** en un microservicio (en GitHub o local), el repo principal **no se entera solo**. Hay que traer esos commits nuevos y registrar el puntero actualizado en `CentinelaProject`.

### Paso 1 — Traer el `main` remoto de cada submódulo

Desde la raíz del monorepo:

```bash
# Todos a la vez (recomendado)
git submodule update --remote --merge

# O solo los que cambiaron
git submodule update --remote --merge ms-auth ms-core c-gateway
```

Equivale a entrar en cada carpeta y ejecutar `git pull origin main`.

### Paso 2 — Registrar los punteros en el repo principal

```bash
git add ms-auth ms-core c-gateway ms-notificaciones
# Solo los submódulos que aparezcan como modified en git status

git status
# Debe mostrar algo como: modified: ms-auth, modified: ms-core
```

### Paso 3 — Commit y push del monorepo

```bash
git commit -m "chore: actualizar punteros de submódulos tras merge en main"
git push origin main
```

> ⚠️ No incluyas `.env` en ese commit (contiene secretos).

---

### 🔹 Un submódulo específico (manual)

```bash
cd ms-auth
git checkout main
git pull origin main
cd ..
git add ms-auth
git commit -m "chore: actualizar puntero de ms-auth"
git push origin main
```

---

### 🔹 Sincronizar en otra máquina (después del push)

```bash
git pull
git submodule update --init --recursive
```

O en un solo paso:

```bash
git pull --recurse-submodules
```

---

## ✏️ Flujo dentro de un submódulo

```bash
cd ms-core
git checkout main
git pull origin main

git add .
git commit -m "feat: cambio en ms-core"
git push origin main
```

Luego, **siempre** en el repo principal:

```bash
cd ..
git add ms-core
git commit -m "chore: actualizar puntero de ms-core"
git push origin main
```

Si el cambio ya se mergeó en GitHub y solo necesitas alinear punteros, usa el flujo de [Actualizar submódulos](#-actualizar-submódulos) (pasos 1–3).

---

## ⚠️ Reglas importantes

- Los submódulos apuntan a commits específicos, no a ramas.
- El repo principal NO almacena código, solo referencias (SHA).
- Cada submódulo es independiente.
- Cambios en submódulos NO se reflejan solos en el repo principal.
- `HEAD detached` en submódulos es NORMAL.

---

## 👥 Onboarding

```bash
git clone --recurse-submodules https://github.com/Kaisitop/CentinelaProject.git
git submodule update --init --recursive
```

---

## 🧭 Filosofía

Arquitectura basada en microservicios versionados:

- Independencia por servicio  
- Versionamiento controlado  
- Reproducibilidad del sistema  
- Orquestación central sin acoplamiento directo  

---

## 📷 Fotos y evidencia (Cloudinary)

El sistema adjunta imágenes a **reportes ciudadanos** y **alertas policiales** (evidencia al cerrar). Las URLs se guardan en PostgreSQL (`ms-core`); la subida se hace vía **Cloudinary** desde `c-gateway`.

### Flujo

```text
Cliente (app web / móvil)
  → POST /api/media/upload?tipo=reporte|evidencia  (c-gateway → Cloudinary)
  → recibe { url, publicId, width, height }
  → POST /api/reportes  con fotosUrls: [url, ...]
     o PATCH /api/alertas/:id/cerrar  con evidenciaUrls: [url, ...]
  → ms-core persiste JSON en app.reportes.fotos_urls / app.alertas.evidencia_urls
  → Admin / operador ven galerías en webcentinela (/reportes, /alertas)
```

### Variables (`.env` raíz → `c-gateway`)

```env
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
CLOUDINARY_FOLDER=centinela
```

Estructura en Cloudinary:

```text
centinela/ciudadano/YYYY-MM-DD/   ← fotos de reportes
centinela/policial/YYYY-MM-DD/    ← evidencia al cerrar alerta
```

### Permisos JWT

| Acción | Permiso |
|---|---|
| Subir foto de reporte | `reportes:create` |
| Subir evidencia policial | `alertas:update_status` |
| Ver reportes y fotos | `reportes:read_all` (admin/operador) |
| Ver alertas y evidencia | `alertas:read` / `alertas:read_all` |

Documentación detallada: `c-gateway/README.md` (HTTP), `ms-core/README.md` (persistencia), [CentinelaFrontend](https://github.com/Kaisitop/CentinelaFrontend) (UI).
```