# 🗂️ Proyecto Principal — Arquitectura con Git Submodules

Este repositorio orquesta múltiples servicios usando **Git Submodules**.

Cada submódulo es un repositorio independiente versionado, y el repositorio principal solo almacena referencias (commits específicos) de cada uno.

> ⚠️ Importante: el repo principal NO contiene código de los servicios, solo punteros a commits exactos (snapshots controlados). Los submódulos están fijados a versiones concretas por diseño.

---

## 📁 Estructura

```
./
├── client-gateway/      → Microservicio independiente
├── microservicio-1/     → Microservicio independiente
└── microservicio-2/     → Microservicio independiente
```

---

## 🚀 Clonar el proyecto por primera vez

```bash
git clone --recurse-submodules https://github.com/tu-usuario/mi-proyecto.git
```

Si ya clonaste sin submódulos:

```bash
git submodule update --init --recursive
git submodule sync --recursive
```

---

## 🔄 Actualizar submódulos

### 🔹 Todos los submódulos

```bash
git submodule update --remote --merge
```

---

### 🔹 Uno específico

```bash
cd microservicio-1
git checkout main
git pull origin main
cd ..
git add microservicio-1
git commit -m "update: microservicio-1 version bump"
git push
```

---

## ✏️ Flujo dentro de un submódulo

```bash
cd client-gateway
git checkout main
git pull origin main

git add .
git commit -m "feat: cambio"
git push origin main
```

Luego en el repo principal:

```bash
cd ..
git add client-gateway
git commit -m "chore: update submodule pointer"
git push
```

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
git clone --recurse-submodules https://github.com/tu-usuario/mi-proyecto.git
git submodule update --init --recursive
```

---

## 🧭 Filosofía

Arquitectura basada en microservicios versionados:

- Independencia por servicio  
- Versionamiento controlado  
- Reproducibilidad del sistema  
- Orquestación central sin acoplamiento directo  
```