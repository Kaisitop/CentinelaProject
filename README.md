# 🗂️ Proyecto Principal — Monorepo con Submódulos

Este repositorio agrupa los servicios del proyecto usando **Git Submodules**. Cada submódulo es un repositorio independiente que vive dentro de este repo contenedor.

## 📁 Estructura

```
./
├── client-gateway/      → Repo independiente (client-gateway)
├── microservicio-1/     → Repo independiente (microservicio 1)
└── microservicio-2/     → Repo independiente (microservicio 2)
```

---

## 🚀 Clonar el proyecto por primera vez

Usa `--recurse-submodules` para clonar el repo y todos los submódulos en un solo comando:

```bash
git clone --recurse-submodules https://github.com/tu-usuario/mi-proyecto.git
```

> Si ya clonaste el repo **sin** ese flag y las carpetas están vacías, ejecuta:
> ```bash
> git submodule update --init --recursive
> ```

---

## 🔄 Actualizar cambios

### Actualizar todos los submódulos de una vez

Trae los últimos cambios de todos los submódulos desde sus repos remotos:

```bash
git submodule update --remote --merge
```

### Actualizar un submódulo específico

```bash
cd microservicio-1
git pull origin main
cd ..
```

Después de actualizar un submódulo, el repo contenedor detectará el cambio. Regístralo con un commit:

```bash
git add microservicio-1
git commit -m "update: microservicio-1 to latest commit"
git push
```

---

## ✏️ Trabajar dentro de un submódulo

Cada submódulo se maneja como un repo Git normal:

```bash
cd client-gateway

# Ver el estado
git status

# Hacer cambios y commitear
git add .
git commit -m "feat: descripción del cambio"
git push origin main
```

Luego vuelve al repo raíz y registra el nuevo puntero:

```bash
cd ..
git add client-gateway
git commit -m "update: client-gateway to latest commit"
git push
```

---

## ⚠️ Puntos importantes

- Los submódulos apuntan a un **commit específico**, no a una rama. Por eso es necesario hacer commit en el repo contenedor cada vez que hay cambios en un submódulo.
- Cada submódulo sigue siendo un repo **100% independiente** — puedes seguir trabajando en ellos por separado.
- El repo contenedor **no almacena el código** de los submódulos, solo guarda una referencia (puntero) al commit exacto de cada uno.

---

## 👥 Para nuevos colaboradores

1. Clonar con submódulos:
   ```bash
   git clone --recurse-submodules https://github.com/tu-usuario/mi-proyecto.git
   ```

2. Entrar a cualquier servicio y trabajar normal:
   ```bash
   cd microservicio-1
   # instalar dependencias, correr el proyecto, etc.
   ```

3. Al terminar, hacer push en el submódulo y luego actualizar el repo contenedor.
