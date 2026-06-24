# CENTINELA
## Módulo de Inseguridad y Violencia Urbana
**Sistema Inteligente de Seguridad y Alertas Urbanas — Ciudad de Milagro, Ecuador**

| Campo | Detalle |
|---|---|
| Institución | UNEMI — Universidad Estatal de Milagro |
| Facultad | Software — Programación |
| Fecha de inicio | 25 de marzo de 2026 |
| Alcance | Línea de Seguridad Ciudadana únicamente |
| Zona piloto | Av. Chirijos · Cdla. Las Piñas · Canal Chimbo (~6 km²) |
| Población beneficiaria | ~18,000 hab. zona piloto → 229,000 cantón Milagro |

---

## 1. Contexto y Problemática de Seguridad

### Diagnóstico de la situación en Milagro

Milagro es el segundo cantón más poblado de la provincia del Guayas (Ecuador), con aproximadamente 229,000 habitantes (INEC, Censo 2022) y una superficie urbana de ~60 km². El cantón registra una de las tasas de incidencia delictiva más altas del Ecuador, con indicadores que superan tanto el promedio nacional como el latinoamericano.

| Indicador | Valor |
|---|---|
| Homicidios / 100k hab. (Milagro 2023) | **38** vs. 32.6 promedio nacional |
| Sicariatos | **64%** del total de homicidios |
| Subregistro ciudadano | **71%** no reporta por miedo |
| Tipo de patrullaje actual | **REACTIVO** — sin análisis preventivo |

*Fuentes: DINASED 2023, Ministerio del Interior, encuesta ECU-911 Zona 5*

### Análisis de causas raíz

- **Tasa de homicidios:** 38 por cada 100,000 habitantes en 2023, superior al promedio nacional de 32.6 y al promedio regional latinoamericano de 17.2 (Ministerio del Interior / DINASED).
- **Sicariatos:** el 64% de homicidios en el cantón corresponde a sicariatos (DINASED, 2023), indicador de crimen organizado estructurado.
- **Subregistro ciudadano:** el 71% de ciudadanos que presencian un delito no lo reporta por miedo a represalias (encuesta ECU-911 Zona 5).
- **Patrullaje reactivo:** la Policía Nacional opera sin sistema de análisis preventivo ni optimización de rutas basada en datos.
- **Conectividad desigual:** zonas periféricas con cobertura 4G limitada o nula, lo que condiciona una arquitectura edge-first para garantizar funcionamiento autónomo.

> CENTINELA convierte la detección reactiva en alerta temprana: detección automática de eventos de violencia mediante audio e IA, canal ciudadano anónimo para reportes, y optimización del patrullaje policial con datos reales.

---

## 2. Objetivos e Impacto Social Medible

### KPIs del módulo de seguridad

| Indicador | Línea base | Objetivo Semestre 2 | Objetivo Semestre 4 |
|---|---|---|---|
| Tasa falsos positivos audio (disparos) | N/A — sin sistema previo | < 20% con modelo YAMNet base | < 5% con fine-tuning en campo |
| Usuarios activos en app ciudadana | 0 | 500 (prueba campus UNEMI) | 5,000 (zona piloto activa) |
| Reportes ciudadanos procesados/mes | 0 | 100 (piloto controlado) | 1,000+ (zona piloto operativa) |
| Tiempo de respuesta policial | Sin datos base (medir en S1) | Medición documentada | Reducción ≥ 10% respecto a basal |

---

## 3. Módulos Funcionales — Línea de Seguridad

### Módulo 1 — Detección de Eventos Críticos (IoT + IA)

Este módulo es el núcleo de la detección automática. Opera en tiempo real sobre el hardware edge (Raspberry Pi 5) y cubre **detección de disparos y gritos por audio**.

| Tecnología | Función | Justificación técnica |
|---|---|---|
| Micrófonos MEMS INMP441 (x2/nodo) | Detectar disparos y gritos en tiempo real — omnidireccional, digital I2S | SNR 61dB, IP67, triangulación de dirección con 2 unidades. Costo total: ~$10 |
| Raspberry Pi 5 (8GB) | Procesamiento edge en cada nodo (pruebas) | YAMNet TFLite ~25 inf/seg en RPi 5 |
| Jetson Orin NX (producción S3+) | Nodo de campo con mayor capacidad | 40 TOPS vs. 3 del RPi — x10 más velocidad. Solicitar via NVIDIA Academic Grant |

#### Arquitectura multi-proceso obligatoria en el nodo (RPi 5)

```
Proceso 1: audio_agent.py   → lee INMP441 vía I2S, corre YAMNet TFLite, publica a cola interna
Proceso 2: sensors_agent.py → lee GPIO (pluviómetro), UART (JSN-SR04T), publica a cola interna
Proceso 3: dispatcher.py    → consume colas internas, aplica reglas de validación, publica MQTT
```

Coordinación: colas POSIX (`multiprocessing.Queue`) — no Kafka en S1

#### Regla anti-falsos positivos

> Un solo nodo **NO** activa alerta. Se requiere confirmación de **2+ nodos vecinos** O reporte ciudadano simultáneo. Umbral de confianza del modelo: **> 0.85**. Esta regla reduce falsos positivos ~70%.

#### Fine-tuning de YAMNet para contexto Milagro

El modelo YAMNet base fue entrenado en clips de YouTube, no en exteriores tropicales. Para el entorno de Milagro se requiere fine-tuning con las siguientes clases:

| Clase de audio | Nivel de alerta | Observación |
|---|---|---|
| Disparo real | 🔴 MÁXIMA | Acción inmediata — notificación a Centro de Comando y Policía |
| Gritos de auxilio | 🔴 MÁXIMA | Acción inmediata — indicador directo de violencia en curso |
| Ruido urbano típico | ⚫ NEGATIVO | Clase baseline — ruido de fondo estándar del entorno |

Dataset requerido: mínimo 500 clips por clase, grabados en campo en Milagro. Runtime: TFLite + cuantización INT8 → ~25 inferencias/seg en RPi 5.

---

### Módulo 2 — Predicción de Riesgo (IA/ML Ético)

Genera mapas de calor dinámicos para optimizar el patrullaje policial con base en datos reales. Las variables de entrenamiento están definidas éticamente desde el diseño.

| Categoría | Variables |
|---|---|
| ✅ Variables VÁLIDAS | Hora del día · día de semana · condición climática · eventos masivos · nivel de iluminación · densidad de reportes ciudadanos |
| 🚫 Variables PROHIBIDAS | Estrato socioeconómico · datos étnicos · historial de arrestos · cualquier variable que criminalice zonas por características de sus habitantes |

#### Estrategia de predicción por fases

| Fase | Semestre | Modelo | Justificación |
|---|---|---|---|
| Determinística | 1 | Reglas de umbral | Funciona desde el día 1 sin datos históricos |
| Estadística | 2–3 | Datos propios acumulados (S1) | Maneja estacionalidad e interpretación sin ML complejo |
| Predictiva | 3–4 | LSTM con datos propios + validados | Requiere mínimo 18 meses de datos de calidad |

---

### Módulo 3 — App Ciudadana (Flutter)

Canal seguro y anónimo para que los ciudadanos reporten incidentes sin miedo a represalias. Implementa pseudonimización conforme a **LOPDP Ecuador 2021, Art. 4**.

| Función | Descripción |
|---|---|
| Botón SOS | Geolocalización instantánea. Solo en SOS el operador ve nombre y ubicación exacta. Datos borrados en < 30 min tras cierre del caso. |
| Reporte anónimo | Pseudonimización por separación de esquemas de BD. La cédula nunca aparece en el historial de reportes. |
| Ruta segura | Navegación evitando zonas de riesgo activas según el mapa en tiempo real. |
| Alertas push | Alertas segmentadas por barrio vía Firebase Cloud Messaging. |
| Check-in Seguro | Alerta automática a contactos si el usuario no confirma llegada al destino. |
| Testigo Digital | Video cifrado con hash inmutable, almacenado en servidor UNEMI (no en la nube comercial). |
| Mapa colaborativo | Calles oscuras, zonas de riesgo activas, reportes ciudadanos recientes. |
| Accountability | El ciudadano califica si el GAD/Policía resolvió el reporte — cierra el ciclo de retroalimentación. |

#### Sistema de pseudonimización (LOPDP 2021)

1. Usuario se registra con cédula → tabla `IDENTIDADES` (cifrada, acceso restringido a Comité Ética UNEMI)
2. Sistema genera UUID aleatorio e irreversible por diseño de proceso
3. Todos los reportes se almacenan con UUID únicamente → tabla `REPORTES` (sin cédula)
4. Las dos tablas viven en esquemas de BD separados con roles de BD distintos
5. **EXCEPCIÓN:** usuario activa SOS físico → operador ve nombre + ubicación → log de auditoría obligatorio

---

### Módulo 4 — Centro de Comando (Dashboard Web)

- Mapa en tiempo real con eventos activos (Leaflet.js + PostGIS) — solo metadatos de IA
- Feed de clasificaciones de IA: tipo de evento, nodo origen, nivel de confianza del modelo
- Gestión GPS de unidades policiales con actualización cada 30 segundos
- Estadísticas automáticas exportables para autoridades (GAD Milagro, Policía Nacional)
- Panel de accountability: estado de resolución de reportes ciudadanos por barrio

---

### Módulo 5 — Canal Ciudadano Digital (Telegram Bot)

Telegram y WhatsApp son los canales de comunicación comunitaria predominantes en el litoral ecuatoriano. Este módulo implementa un canal activo y voluntario — el ciudadano elige participar.

- Bot oficial CENTINELA en Telegram: reporte voluntario de incidentes, recepción de alertas segmentadas por barrio
- Alertas automáticas de eventos críticos de seguridad vía canal Telegram verificado
- Integración con grupos de WhatsApp de Juntas Vecinales verificadas (WhatsApp Business API o enlace manual)
- Sin scraping, sin almacenamiento de perfiles — solo procesamiento de mensajes entrantes al bot
- NLP básico (spaCy en español) para clasificar tipo de reporte recibido automáticamente

---

## 4. Stack Tecnológico — Línea de Seguridad

| Área | Tecnología elegida | Por qué esta y no otra |
|---|---|---|
| App Móvil | Flutter (Dart) | Un codebase iOS+Android; performance nativa; comunidad activa en Ecuador; open source |
| Frontend Web | React + TypeScript | Maduro, documentado. TypeScript obligatorio para proyectos de seguridad (type safety) |
| Backend API | Node.js | Manejo nativo de I/O concurrente y WebSockets para alertas en tiempo real |
| Backend IA | FastAPI (Python) | Integración nativa con ecosistema ML de Python (TFLite, scikit-learn) |
| ORM Node.js | Sequelize v6 + sequelize-typescript | SELECT FOR UPDATE nativo; control de ISOLATION_LEVELS.SERIALIZABLE para LOPDP |
| ORM Python | SQLAlchemy 2.0 + Alembic | ORM estándar Python/FastAPI; Alembic para migraciones con soporte raw SQL (PostGIS) |
| IA/ML | TFLite + scikit-learn | TFLite para inferencia edge (INT8); scikit-learn para modelos estadísticos simples |
| Protocolo IoT | MQTT (Mosquitto) | Estándar industrial IoT, ultra-liviano, QoS configurable, funciona sobre 4G y LoRaWAN |
| BD geoespacial | PostgreSQL + PostGIS | Estándar open source para datos geoespaciales; integración probada con Python y Node |
| Caché / tiempo real | Redis | Pub/Sub para broadcasting de alertas a WebSockets; caché de sesiones |
| Mapas | Leaflet.js + OpenStreetMap | Gratuito, open source, integra con PostGIS; sin dependencia de Google Maps API |
| DevOps | Docker + Docker Compose + GitHub Actions | Reproducibilidad de entornos para equipos de estudiantes; CI desde Semestre 1 |

---

## 5. Arquitectura de Microservicios

| Servicio | Tecnología | Puerto | Responsabilidad |
|---|---|---|---|
| Core API | Node.js | :3000 | Alertas, reportes ciudadanos, mapa en tiempo real, WebSocket |
| SVC IA/ML | FastAPI (Python) | :8000 | YAMNet audio (disparos + gritos), clasificación de eventos |
| SVC IoT Bridge | Python | :8100 | Consumer MQTT permanente → valida → persiste en InfluxDB + PostgreSQL |
| SVC Auth/Usuarios | Node.js | :8200 | JWT + pseudonimización. Aislado: identidades nunca en el mismo proceso que reportes |
| SVC Notificaciones | Node.js | :8300 | Firebase FCM, Telegram Bot, WhatsApp Business. Fallo no afecta alertas core |
| Nginx | Reverse proxy | :443/:80 | Rate limiting, TLS 1.3, enrutamiento a microservicios |
| MQTT Broker | Mosquitto | :1883/:8883 | Broker central: nodos IoT → SVC IoT Bridge. Puerto TLS para nodos en campo |

---

## 6. Hardware — Nodo CENTINELA Seguridad

### Kit de pruebas (laboratorio UNEMI)

| # | Componente | Dispositivo | Precio USD |
|---|---|---|---|
| 1 | Procesamiento | Raspberry Pi 5 (8GB) | $80 |
| 2 | Audio | INMP441 MEMS I2S x2 + encapsulado IP67 | $15 |
| 3 | Comunicación 4G | Huawei E3372h USB dongle 4G (CNT/Claro) | $25 |
| 4 | Red | PoE Injector pasivo TP-Link TL-PoE150S | $15 |
| 5 | Almacenamiento | SSD Samsung 500GB | $55 |
| 6 | Carcasa | Gabinete IP65 300x200x130mm | $28 |
| 7 | Energía indoor | UPS APC BE600M1 (laboratorio) | $65 |
| 8 | Energía outdoor | Panel solar 50W + batería AGM 12V/100Ah + MPPT 10A | $155 |
| 9 | Misceláneos | Cables, protoboard, jumpers, tornillería | $40 |

| Configuración | Costo total |
|---|---|
| Indoor (laboratorio UNEMI) | ~$323 |
| Outdoor (campo real S3+) | ~$413 |
| Kit de desarrollo local (por estudiante) | ~$161 |

---

## 7. Riesgos Críticos y Soluciones de Diseño

| Riesgo | Impacto | Solución técnica desde la arquitectura |
|---|---|---|
| Reconocimiento facial sin marco legal | 🔴 ILEGAL (LOPDP 2021) | Prohibido en el diseño. Solo detección de comportamiento por audio, nunca de identidad |
| Falsos positivos en audio (disparos/gritos) | Alta — erosión de confianza | Regla: 2+ nodos deben confirmar. Umbral confianza > 0.85. Fine-tuning local en S2 |
| Dependencia de internet en zonas marginales | El sistema falla donde más se necesita | Arquitectura edge-first: el nodo procesa localmente. LoRaWAN como fallback en S3 |
| Datos delictivos históricos sesgados | Modelo ML criminaliza zonas pobres | Variables de entrenamiento seleccionadas éticamente (ver §3 Módulo 2) |
| Sin retroalimentación ciudadana real | Sistema obsoleto sin uso real | App con calificación de resolución de reportes. Lanzamiento en campus UNEMI primero |
| Centralización de datos sensibles | Un punto de fallo = riesgo catastrófico | Cifrado E2E + servidor on-premise UNEMI + backup cloud educativo gratuito |
| Falta de datos para entrenamiento ML en S1 | Modelos sin entrenar = sistema inútil | S1 usa reglas determinísticas. ML se introduce cuando hay datos propios acumulados (S2) |

---

## 8. Plan de Pruebas — Módulo Seguridad

### Etapa 1 — Laboratorio UNEMI (Semanas 1–3)

**Objetivo:** Validar integración completa del nodo en condiciones controladas.

**Actividades:**
- RPi 5 captura audio INMP441 vía I2S → YAMNet TFLite clasifica → resultado por MQTT
- Los 3 procesos del nodo corren de forma independiente (arquitectura multi-proceso)
- Dashboard muestra clasificaciones de IA en tiempo real

**Criterios de aprobación:**
- ✅ Los 3 procesos corren simultáneamente sin que ninguno bloquee a otro
- ✅ Latencia sensor → MQTT: < 1 segundo en condiciones normales
- ✅ Carga CPU del RPi 5 durante operación completa: < 85% sostenido
- ✅ 0 pérdidas de mensajes MQTT en 30 minutos de operación continua

**Entregable:** Informe de integración con métricas de latencia y carga de CPU por proceso

---

### Etapa 2 — Campo Controlado (campus) — Semanas 4–6

**Objetivo:** Validar precisión de modelos de audio en condiciones reales.

**Actividades:**
- Clasificación de audio: grabar 100+ clips de disparos simulados, gritos, voces, palmadas → dataset baseline
- Pruebas de conectividad Huawei E3372h: latencia MQTT, packet loss, uptime en 72h continuas
- Validación de regla anti-falsos positivos con 2+ nodos en campus

**Criterios de aprobación:**
- ✅ YAMNet clasifica disparos y gritos con precisión ≥ 85%
- ✅ MQTT uptime ≥ 95% en 72h de operación continua con dongle 4G
- ✅ Dataset de audio con ≥ 100 clips etiquetados por categoría

**Entregable:** Dataset base de audio + informe de precisión de modelos + memoria de pruebas

---

### Etapa 3 — Piloto en Zona Real (Milagro) — Semanas 7–12

**Objetivo:** Nodo operativo en ubicación real con datos auténticos de seguridad urbana.

**Actividades:**
- Opción A: Entrada barrio Cdla. Las Piñas — historial de incidentes registrados en GAD
- Opción B: Instalaciones GAD Milagro o Policía Nacional — acceso y soporte garantizado
- Dashboard muestra eventos de IA a operadores UNEMI en tiempo real
- Primer ciclo de retroalimentación de reportes ciudadanos desde la app

**Criterios de aprobación:**
- ✅ Nodo opera de forma autónoma ≥ 7 días consecutivos sin intervención manual
- ✅ Al menos 5 eventos clasificados por IA correctamente validados por operador
- ✅ Al menos 10 reportes ciudadanos procesados a través de la app

**Entregable:** Informe de viabilidad de campo con datos reales + lista de ajustes para Semestre 2

---

## 9. Plan de Semestres — Línea de Seguridad

| | Semestre 1 — Fundamentos | Semestre 2 — IA y Datos | Semestre 3 — Escala | Semestre 4 — Consolidación |
|---|---|---|---|---|
| Equipo mínimo | 6–8 est. | 4–6 est. | 4–6 est. | 3–4 est. |
| Nodos activos | 1 (lab.) | 1–2 (campus) | 3–5 (piloto) | 5–10 (completo) |
| Detección audio | YAMNet base | Fine-tuning campo | Modelo mejorado | Producción |
| App ciudadana | MVP: SOS + reporte | Telegram Bot | App completa | 5,000 usuarios |
| Predicción riesgo | Reglas umbral | Estadística | ML supervisado | LSTM |
| Integraciones | GAD Milagro carta | DINASED datos | ECU-911 API | Transferencia GAD |

---

## 10. Marco Legal y Ética de Datos

### Legislación aplicable

- Ley Orgánica de Protección de Datos Personales (Ecuador, 2021)
- Reglamento de Videovigilancia — Acuerdo Ministerial del Ministerio del Interior
- Principios de IA Ética (UNESCO, 2021)

### Medidas técnicas obligatorias

| Medida | Implementación |
|---|---|
| Cifrado en tránsito | TLS 1.3 para todos los endpoints del sistema |
| Cifrado en reposo | Datos personales cifrados con AES-256 en base de datos |
| Pseudonimización | Separación de tablas IDENTIDADES y REPORTES con roles de BD distintos |
| Consentimiento explícito | Registrado para cada tipo de dato al registrarse en la app |
| Derecho al olvido | Borrado total en 48h bajo solicitud — endpoint específico implementado |
| Log de auditoría | Registro inmutable de quién accedió a qué dato y cuándo |
| Comité de Ética UNEMI | Revisión trimestral de accesos y modelos de IA |

### Prohibiciones absolutas de implementación

- 🚫 Reconocimiento facial en espacio público — ilegal sin autorización judicial expresa
- 🚫 Almacenar grabaciones de audio > 72h sin incidente asociado validado
- 🚫 Compartir datos individuales (incluso pseudonimizados) con terceros sin consentimiento
- 🚫 Entrenar modelos ML con variables de estrato socioeconómico, datos étnicos o historial penal

---

## 11. Integraciones con Sistemas Externos

| Sistema | Propósito | Método | Semestre |
|---|---|---|---|
| GAD Milagro | Mapa base, catastro, zonas históricas de incidentes | Datos abiertos + reunión de vinculación | 1 |
| DINASED | Datos históricos delictivos anonimizados para entrenamiento ML ético | Convenio académico UNEMI | 2 |
| Policía Nacional | Alertas de eventos críticos, gestión de patrullaje GPS | Protocolo directo — acuerdo institucional desde S1 | 2 |
| ECU-911 | Envío automático de alertas críticas al centro de emergencias | API REST — requiere convenio (gestionar desde S1, disponible S3) | 3 |

---

## 12. División por Equipos de Estudiantes

Todos los módulos son para estudiantes de **4to semestre en adelante**. Cada módulo es asignable a un equipo de 2–3 estudiantes de forma independiente, con contrato de interfaz OpenAPI hacia los demás equipos.

| Módulo / Microservicio | Área | Semestre | Equipo sugerido |
|---|---|---|---|
| SVC Core API: alertas, reportes, mapa (Node.js) | Backend | 1 | 2–3 est. |
| SVC Auth/Usuarios: JWT + pseudonimización (Node.js) | Backend/Seguridad | 1 | 1–2 est. |
| SVC IoT Bridge: MQTT consumer → PostgreSQL (Python) | Backend/IoT | 1 | 2 est. |
| SVC Notificaciones: FCM + Telegram Bot (Node.js) | Backend | 1 | 1–2 est. |
| App ciudadana (Flutter) | Móvil | 1 | 2–3 est. |
| Dashboard Command (React + TypeScript) | Frontend | 1 | 2–3 est. |
| Nodo IoT: hardware + agentes Python + MQTT publisher | IoT/Hardware | 1 | 2 est. |
| SVC IA/ML: YAMNet fine-tuning (FastAPI) | IA/Datos | 1–2 | 2–3 est. |
| Base de datos: esquemas PostGIS + InfluxDB + Redis | BD | 1 | 1–2 est. |

### Subproyectos con proyección académica

| Subproyecto | Nombre | Tipo académico |
|---|---|---|
| Detección de disparos y gritos con audio IA | CENTINELA Audio | Tesis + paper IEEE |
| App ciudadana con anonimato por diseño | CENTINELA App | Proyecto integrador |
| Dashboard de gestión municipal | CENTINELA Command | Proyecto integrador |
| Predicción de riesgo delictivo ético | CENTINELA Predict | Tesis con componente ético |

---

*Documento extraído del proyecto integral CENTINELA — UNEMI, Milagro, Ecuador. Este documento corresponde exclusivamente al módulo de Inseguridad y Violencia Urbana. El módulo de Riesgo Hídrico se desarrolla de forma independiente con arquitectura compartida.*
