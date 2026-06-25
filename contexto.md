# Contexto del Proyecto "Centinela"

Este archivo está diseñado para que cualquier IA (o desarrollador) que se una al proyecto comprenda la arquitectura, las decisiones técnicas, los problemas resueltos y las convenciones actuales del sistema.

## 1. Visión General
**Centinela** es un sistema de seguridad ciudadana diseñado para la ciudad de Milagro, Ecuador. Su objetivo es recibir reportes ciudadanos, procesar audio de nodos IoT en tiempo real (detección de disparos, etc.) mediante IA, generar alertas y notificar a los operadores.

El sistema completo se divide en dos grandes partes:
1. **Backend (centinela-project)**: Arquitectura de microservicios usando Docker y Docker Compose.
2. **Frontend (webcentinela)**: Panel administrativo web construido con Next.js y Tailwind CSS.

---

## 2. Arquitectura de Microservicios (Backend)

Todos los servicios están dockerizados y se orquestan mediante `docker-compose.yml`. La comunicación interna se realiza **exclusivamente a través de NATS** (patrón de paso de mensajes), a excepción de la API Gateway que expone endpoints REST al exterior.

### Servicios
*   **c-gateway** (NestJS): API Gateway. Recibe peticiones HTTP del frontend/móvil y las traduce a mensajes NATS para los demás microservicios.
*   **ms-auth** (NestJS): Manejo de usuarios, roles y autenticación JWT. Su base de datos PostgreSQL usa el esquema `identity`. No permite acceso de usuarios con rol "Ciudadano" al dashboard web.
*   **ms-core** (NestJS): Lógica de negocio principal. Maneja *Zonas, Nodos IoT, Reportes, Eventos y Alertas*. Su base de datos PostgreSQL usa el esquema `app`.
*   **ms-notificaciones** (NestJS): Encargado de enviar notificaciones Push (OneSignal, Firebase) y alertas de Telegram.
*   **ms-ia** (Python): Procesa audios usando el modelo YAMNet para identificar sonidos peligrosos (disparos, explosiones). 
    *   **⚠️ IMPORTANTE**: Requiere que el archivo de pesos `my_yamnet_classifier.h5` sea insertado manualmente en la carpeta `ms-ia/models/` antes de compilar/ejecutar el contenedor.
*   **ms-IoT-Bridge** (Python): Puente que escucha telemetría y heartbeats de dispositivos IoT vía MQTT y los retransmite a NATS.
*   **Infraestructura**:
    *   **PostgreSQL 15+ con PostGIS**: Base de datos única compartida (`centinela_db`) separada por esquemas (`app`, `identity`).
    *   **NATS**: Broker de mensajería (puerto 4222). Habilitado el puerto de monitoreo (8222).

---

## 3. Convenciones y Lecciones Aprendidas (¡LEER ANTES DE CODIFICAR!)

A lo largo del desarrollo, se resolvieron varios problemas arquitectónicos. Sigue estrictamente estas reglas:

### 3.1. Configuración de NATS
*   **Variable de entorno global**: Para conectar a NATS se debe usar **SIEMPRE** la variable `NATS_SERVICE` (ej. `NATS_SERVICE=nats://nats:4222`) para mantener la consistencia.
*   **Healthchecks**: El contenedor NATS arranca muy rápido, pero tarda un instante en estar listo para aceptar conexiones. En `docker-compose.yml`, los microservicios dependen de NATS utilizando `condition: service_healthy`, y NATS tiene un healthcheck que hace ping a `http://localhost:8222/healthz`. No uses `depends_on` simple para NATS, o los servicios en Python entrarán en bucles de error.

### 3.2. Prisma (Versión 7+) y NestJS
*   **Generación de Clientes**: El `schema.prisma` genera los clientes en `./generated/prisma/client` (fuera de `node_modules`).
*   **Adaptador PostgreSQL (Driver Adapter)**: Si un servicio usa `@prisma/adapter-pg`, debes instanciar el pool de conexiones explícitamente y pasarlo al constructor de Prisma. *Ejemplo en `ms-core/prisma/seed.ts`*.
*   **Errores de Compilación TypeScript en Nest**: Al generar tipos pesados fuera de `node_modules`, NestJS intenta compilarlos y falla (falta de memoria/timeout). **Siempre** excluye la carpeta `prisma` en el archivo `tsconfig.build.json` de los microservicios NestJS.
*   **Inicialización y Migraciones**: El arranque de la base de datos está automatizado a través de un `docker-entrypoint.sh` en los servicios Nest. Este script usa `nc -z postgres 5432` para esperar a que PostgreSQL levante, luego corre `npx prisma db push --accept-data-loss` y finalmente `npx prisma db seed`.

### 3.3. Base de Datos en Docker
*   El puerto interno del contenedor Postgres es siempre `5432`. El `DATABASE_URL` interno de los microservicios debe apuntar a `postgres:5432` (no a puertos expuestos mapeados hacia el host como el `5433`).

---

## 4. Estado Actual del Frontend (webcentinela)

El frontend es un proyecto Next.js en una carpeta externa (`../webcentinela`). 
*   **API Client (`lib/api.ts`)**: Configurado con Axios, maneja automáticamente la inyección del Access Token (JWT) almacenado en `localStorage`, e intercepta respuestas HTTP 401 para intentar renovar (refresh token) transparentemente.
*   **Servicios**: `lib/core-service.ts` y `lib/auth-service.ts` contienen tipados estrictos en TypeScript y exponen todos los endpoints necesarios del Gateway.
*   **Módulos Conectados Totalmente al Backend Real**:
    *   Dashboard (`app/page.tsx`): Gráficos y resumen de estado de zonas/alertas.
    *   Gestión de Alertas (`app/alertas/page.tsx`): Reconocer, cerrar, o marcar falsas alarmas.
    *   Reportes Ciudadanos (`app/reportes/page.tsx`): Permite al operador tomar un caso (`EN_PROCESO`), resolverlo, o declararlo falso.
    *   Patrullaje / Monitoreo IoT (`app/patrullaje/page.tsx`): Muestra el mapa/listado de Zonas y estado online/offline de los Nodos.

---

## 5. Instrucciones de Despliegue Local

1. Clonar el repositorio y descargar/copiar el modelo YAMNet (`my_yamnet_classifier.h5`) dentro de `ms-ia/models/`.
2. Para levantar toda la arquitectura backend:
   ```bash
   docker-compose up --build -d
   ```
3. En el directorio del frontend (`webcentinela`), crear un archivo `.env.local`:
   ```env
   NEXT_PUBLIC_API_URL=http://localhost:3000/api
   ```
4. Correr el frontend:
   ```bash
   npm run dev
   ```

Cualquier IA que interactúe a partir de ahora con el código, **debe respetar las convenciones de Prisma 7, el nombrado de NATS, y los healthchecks de Docker Compose.**
