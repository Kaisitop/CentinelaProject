# Arquitectura CENTINELA — índice

Sistema de detección inteligente de violencia urbana para Milagro (Ecuador).

| Documento | Contenido |
|-----------|-----------|
| [**ARQUITECTURA_BACKEND.md**](./ARQUITECTURA_BACKEND.md) | Microservicios, NATS, MQTT, PostgreSQL/PostGIS, IoT, IA |
| [**ARQUITECTURA_FRONTEND.md**](./ARQUITECTURA_FRONTEND.md) | Panel Next.js (`webcentinela`), app Flutter, mapas, push |
| [**contexto.md**](./contexto.md) | Convenciones, flujos actuales, roles, despliegue |

### Vista rápida

```text
[Nodos IoT / App] ──MQTT──► [ms-IoT-Bridge] ──NATS──► [ms-ia / ms-core]
[App Flutter]     ──HTTP──► [c-gateway :3000] ──NATS──► [ms-auth / ms-core]
[Panel Next.js]   ──HTTP+WS► [c-gateway :3000]
                              └──► PostgreSQL + PostGIS
```

### Otros documentos

- [README.md](../README.md) — clonado, submódulos, Docker
- [CENTINELA_Inseguridad_Violencia_Urbana.md](./CENTINELA_Inseguridad_Violencia_Urbana.md) — requisitos de negocio
- [CENTINELA_MER_Seguridad.md](./CENTINELA_MER_Seguridad.md) — modelo entidad-relación
