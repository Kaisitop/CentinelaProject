# D5 — Diagrama Entidad-Relación — CENTINELA Seguridad

> **Versión:** 2.1.0
> **Fecha:** 2026-06-13
> **Estado:** Actualizado — Módulo Inseguridad y Violencia Urbana únicamente
> **Cambios respecto a v2.0.0:** Añadida entidad `app.usuario_zonas` para resolver la relación N:M entre usuarios y zonas (zona principal de registro + hasta 3 zonas adicionales suscritas, RF-0301 / RF-0307 / RF-0309). Sigue el mismo patrón de referencia lógica sin FK cross-schema usado en `reportes` y `notificaciones`.

---

## 1. Principio de separación (LOPDP)

```
┌─────────────────────────────┐     ┌──────────────────────────────────────────┐
│  Schema: identity           │     │  Schema: app                             │
│  (datos personales/auth)    │     │  (datos de operación del sistema)        │
│                             │     │                                          │
│  • usuarios                 │     │  • zonas             • nodos            │
│  • roles                    │     │  • eventos           • reportes         │
│  • permisos                 │     │  • alertas           • notificaciones   │
│  • roles_permisos           │     │  • rutas_patrullaje                     │
│  • sesiones                 │     │  • usuario_zonas                        │
│  • audit_log                │     │                                          │
│                             │     │                                          │
│  Solo accesible: svc-auth   │     │  Accesible: core-api, svc-ia, svc-iot  │
└─────────────────────────────┘     └──────────────────────────────────────────┘
         │                                         │
         │  usuario_id (referencia lógica,         │
         │  sin FK cross-schema, LOPDP Art.13)  ───┘
```

> Las tablas `app.reportes`, `app.notificaciones` y `app.usuario_zonas` referencian `usuario_id` como UUID sin FK declarada hacia `identity.usuarios`. La integridad referencial se gestiona a nivel de aplicación en svc-auth + core-api.

---

## 2. Diagrama ER

```mermaid
erDiagram

    %% ════════════════════════════════════════
    %% SCHEMA: identity
    %% ════════════════════════════════════════

    ROLES {
        uuid id PK
        varchar nombre UK
        text descripcion
        boolean activo
        timestamptz created_at
        timestamptz updated_at
    }

    PERMISOS {
        uuid id PK
        varchar modulo
        varchar accion
        text descripcion
        boolean activo
    }

    ROLES_PERMISOS {
        uuid rol_id FK
        uuid permiso_id FK
    }

    USUARIOS {
        uuid id PK
        varchar email UK
        boolean email_verificado
        char hash_password
        varchar totp_secret
        boolean totp_habilitado
        varchar nombre
        varchar telefono
        uuid rol_id FK
        boolean activo
        smallint intentos_fallidos
        timestamptz bloqueado_hasta
        timestamptz ultimo_login
        char token_reset_pwd
        char token_verif_email
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    SESIONES {
        uuid id PK
        uuid usuario_id FK
        char refresh_token UK
        text user_agent
        inet ip_address
        boolean activa
        timestamptz expira_en
        timestamptz created_at
        timestamptz revocada_en
    }

    AUDIT_LOG {
        bigint id PK
        uuid usuario_id FK
        varchar accion
        inet ip_address
        text user_agent
        jsonb metadata
        timestamptz created_at
    }

    %% ════════════════════════════════════════
    %% SCHEMA: app
    %% ════════════════════════════════════════

    ZONAS {
        uuid id PK
        varchar nombre
        text descripcion
        geometry geom
        smallint riesgo_nivel
        boolean activa
        timestamptz created_at
        timestamptz updated_at
    }

    NODOS {
        uuid id PK
        varchar codigo UK
        text descripcion
        geometry ubicacion
        uuid zona_id FK
        varchar version_fw
        char cert_fingerprint
        timestamptz ultimo_heartbeat
        varchar estado
        boolean activo
        timestamptz created_at
        timestamptz updated_at
    }

    EVENTOS {
        uuid id PK
        varchar tipo
        varchar subtipo
        uuid nodo_id FK
        uuid zona_id FK
        geometry ubicacion
        numeric confianza
        smallint severidad
        varchar fuente
        text audio_url
        jsonb metadatos
        boolean procesado
        timestamptz created_at
    }

    REPORTES {
        uuid id PK
        uuid usuario_id
        varchar tipo
        text descripcion
        geometry ubicacion
        uuid zona_id FK
        varchar estado
        smallint prioridad
        text fotos_urls
        uuid evento_id FK
        uuid operador_id
        text notas_operador
        timestamptz created_at
        timestamptz updated_at
        timestamptz cerrado_en
        timestamptz deleted_at
    }

    ALERTAS {
        uuid id PK
        varchar codigo UK
        varchar tipo
        text descripcion
        uuid zona_id FK
        geometry ubicacion
        smallint severidad
        varchar estado
        uuid evento_id FK
        uuid reporte_id FK
        varchar generada_por
        uuid reconocida_por
        timestamptz reconocida_en
        uuid cerrada_por
        timestamptz cerrada_en
        text notas
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    NOTIFICACIONES {
        uuid id PK
        uuid alerta_id FK
        varchar canal
        uuid destinatario_id
        varchar titulo
        text cuerpo
        varchar estado
        smallint intentos
        text proveedor_msg_id
        text error_detalle
        timestamptz enviada_en
        timestamptz created_at
    }

    RUTAS_PATRULLAJE {
        uuid id PK
        varchar nombre
        uuid zona_id FK
        geometry geom
        smallint prioridad
        varchar turno
        boolean activa
        boolean generada_por_ia
        timestamptz created_at
        timestamptz updated_at
    }

    USUARIO_ZONAS {
        uuid usuario_id PK
        uuid zona_id "PK, FK"
        varchar_20 tipo
        timestamptz created_at
    }

    %% ════════════════════════════════════════
    %% RELACIONES — Schema identity
    %% ════════════════════════════════════════

    ROLES ||--o{ USUARIOS : "asignado a"
    ROLES ||--o{ ROLES_PERMISOS : "tiene"
    PERMISOS ||--o{ ROLES_PERMISOS : "incluido en"
    USUARIOS ||--o{ SESIONES : "genera"
    USUARIOS ||--o{ AUDIT_LOG : "registra"

    %% ════════════════════════════════════════
    %% RELACIONES — Schema app
    %% ════════════════════════════════════════

    ZONAS ||--o{ NODOS : "contiene"
    ZONAS ||--o{ EVENTOS : "ubica"
    ZONAS ||--o{ REPORTES : "ubica"
    ZONAS ||--o{ ALERTAS : "ubica"
    ZONAS ||--o{ RUTAS_PATRULLAJE : "define"
    ZONAS ||--o{ USUARIO_ZONAS : "tiene suscriptores"

    NODOS ||--o{ EVENTOS : "detecta"
    EVENTOS ||--o{ REPORTES : "correlaciona"
    EVENTOS ||--o{ ALERTAS : "origina"
    REPORTES ||--o{ ALERTAS : "origina"
    ALERTAS ||--o{ NOTIFICACIONES : "genera"

    %% Nota: USUARIOS ||--o{ USUARIO_ZONAS no se modela como FK real
    %% (referencia lógica cross-schema, mismo patrón que REPORTES.usuario_id)
```

---

## 3. Descripción de entidades

### Schema `identity`

#### `identity.roles`
Catálogo de roles del sistema: `ciudadano`, `operador`, `admin`. Controla el acceso a módulos y acciones vía `roles_permisos`.

#### `identity.permisos`
Acciones granulares por módulo (ej. `alertas:read`, `reportes:write`). Se asignan a roles mediante la tabla intermedia `roles_permisos`.

#### `identity.roles_permisos`
Tabla intermedia M:N entre `roles` y `permisos`. Sin datos adicionales — la relación es el dato.

#### `identity.usuarios`
Datos personales y credenciales de todos los usuarios del sistema (ciudadanos, operadores, admins). Soft delete (`deleted_at`) para cumplir LOPDP — los datos no se eliminan físicamente hasta cumplir el período de retención de 5 años. Incluye soporte para 2FA vía TOTP y bloqueo por intentos fallidos.

#### `identity.sesiones`
Tokens de refresh activos por usuario. Permite invalidar sesiones específicas sin afectar otras (logout selectivo). Se registra `ip_address` y `user_agent` para auditoría.

#### `identity.audit_log`
Registro inmutable de todas las acciones relevantes del sistema. Requerido por LOPDP Art. 13 — quién accedió a qué dato y cuándo.

---

### Schema `app`

#### `app.zonas`
Polígonos geoespaciales (MULTIPOLYGON WGS84) de los sectores de Milagro. Eje central del sistema: todas las entidades operativas referencian una zona. `riesgo_nivel` es dinámico — se actualiza por el SVC IA según densidad de eventos recientes.

#### `app.nodos`
Nodos IoT físicos desplegados en campo. Cada nodo contiene micrófonos INMP441 y ejecuta los agentes Python (`audio_agent.py`, `dispatcher.py`). `cert_fingerprint` garantiza que solo nodos autenticados pueden publicar en el broker MQTT.

#### `app.eventos`
Unidad mínima de detección del sistema. Generado por el nodo IoT vía audio (YAMNet TFLite) o manualmente por un operador. Valores válidos:

| Campo | Valores permitidos |
|---|---|
| `tipo` | `audio` · `manual` · `ciudadano` |
| `subtipo` | `disparo` · `fuego_artificial` · `petardo` · `moto_sin_silenciador` · `otro` |
| `fuente` | `yamnet` · `operador` · `app_ciudadana` |

`metadatos` (jsonb) almacena la distribución de confianza por clase del modelo YAMNet. `audio_url` apunta al clip de audio cifrado almacenado en el servidor UNEMI (máximo 72h sin incidente validado, LOPDP).

#### `app.reportes`
Incidencias reportadas por ciudadanos desde la app móvil. **Sin FK hacia `identity.usuarios`** por diseño (LOPDP Art. 13 — minimización y separación). `usuario_id` es una referencia UUID que la aplicación resuelve consultando svc-auth únicamente cuando es estrictamente necesario (ej. SOS activo).

#### `app.alertas`
Centro del flujo de respuesta. Puede originarse desde un evento de audio, un reporte ciudadano, o ser creada manualmente por un operador. Ciclo de vida: `activa → reconocida → cerrada` / `falsa_alarma`. Toda notificación sale de aquí.

#### `app.notificaciones`
Registro de cada envío de notificación por canal (FCM, Telegram, WhatsApp). Permite reintentos controlados (`intentos`) y trazabilidad de fallos (`error_detalle`).

#### `app.rutas_patrullaje`
Rutas geoespaciales para optimización del patrullaje policial. `generada_por_ia` distingue rutas manuales de las sugeridas por el módulo de predicción de riesgo. `turno` define si aplica a patrulla diurna o nocturna.

#### `app.usuario_zonas` *(nueva)*
Tabla pivote que resuelve la relación N:M entre `identity.usuarios` y `app.zonas`. Cada fila representa la relación de un usuario con una zona, distinguida por `tipo`:

- `principal`: la zona/barrio con la que el usuario se registró (RF-0301). Un usuario solo puede tener **una** fila `principal` — se recomienda un índice único parcial: `UNIQUE (usuario_id) WHERE tipo = 'principal'`.
- `suscrita`: zonas adicionales a las que el usuario se suscribió para recibir alertas (RF-0309, máximo 3). El límite se valida vía trigger `BEFORE INSERT` o a nivel de aplicación en core-api.

`usuario_id` sigue el mismo patrón de referencia lógica sin FK cross-schema que `app.reportes.usuario_id` (LOPDP Art. 13). Es consultada por `svc-notificaciones` para resolver destinatarios de alertas push segmentadas por zona (RF-0307): `SELECT usuario_id FROM app.usuario_zonas WHERE zona_id = :zona_alerta`.

PK compuesta: `(usuario_id, zona_id)` — un usuario no puede tener dos filas para la misma zona.

---

## 4. Tablas eliminadas respecto al MER general

| Tabla | Motivo de eliminación |
|---|---|
| `app.camaras` | Sin detección por video — módulo de seguridad usa solo audio (YAMNet) |
| `app.predicciones_hidrologicas` | Exclusiva del módulo hídrico — proyecto separado |

---

## 5. Cardinalidades

| Relación | Cardinalidad | Notas |
|---|---|---|
| usuario ↔ rol | N:1 | Un usuario tiene un rol; un rol puede tener muchos usuarios |
| rol ↔ permiso | M:N | Via `roles_permisos` |
| usuario ↔ zona | N:M | Via `usuario_zonas`. Un usuario tiene 1 zona `principal` + hasta 3 `suscrita`; una zona puede tener muchos usuarios asociados |
| zona ↔ nodos | 1:N | Una zona agrupa múltiples nodos IoT |
| zona ↔ eventos | 1:N | Una zona tiene muchos eventos; evento puede no tener zona (null) |
| nodo ↔ eventos | 1:N | Un nodo genera muchos eventos de audio |
| evento ↔ alerta | 1:0..1 | Un evento puede generar 0 o 1 alerta directa |
| reporte ↔ alerta | 1:0..1 | Un reporte puede correlacionar con 1 alerta |
| alerta ↔ notificaciones | 1:N | Una alerta genera N notificaciones (por canal, por destinatario) |
| zona ↔ rutas_patrullaje | 1:N | Una zona puede tener múltiples rutas definidas por turno |

---

## 6. Flujo de datos principal

```
Nodo IoT (INMP441 x2)
    │ audio raw
    ▼
[audio_agent.py] — YAMNet TFLite — confianza por clase
    │
    ▼
[dispatcher.py] — valida: confianza > 0.85 + confirmación 2+ nodos
    │
    │ publica MQTT
    ▼
Mosquitto Broker
    │
    ▼
[svc-iot-bridge] — guarda app.eventos (procesado = false)
    │
    │ llama svc-ia /classify/audio
    ▼
[svc-ia] — YAMNet server-side — actualiza app.eventos.procesado = true
    │
    ▼
[core-api] — crea app.alertas
    │
    ▼
[svc-notificaciones]
    ├── resuelve destinatarios: app.usuario_zonas WHERE zona_id = alerta.zona_id
    ├── FCM → app ciudadana
    ├── Telegram → operadores
    └── guarda app.notificaciones
```

---

*Artefacto D5 v2.1.0 — CENTINELA Seguridad — UNEMI, Milagro, Ecuador*
*Actualizado: 13 de junio de 2026*
