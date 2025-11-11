# 🌐 Sistema Distribuido de Gestión de Productos con Incus

> **Proyecto Académico**: Arquitectura de sistema distribuido implementada sobre contenedores Incus con MongoDB, replica sets y sharding manual para alta disponibilidad.

![Status](https://img.shields.io/badge/status-completado-success.svg)
![MongoDB](https://img.shields.io/badge/MongoDB-6.0-green.svg)
![Node.js](https://img.shields.io/badge/Node.js-20-green.svg)
![Incus](https://img.shields.io/badge/Incus-6.0-blue.svg)

---

## 📋 Tabla de Contenidos

- [Descripción del Proyecto](#-descripción-del-proyecto)
- [Arquitectura del Sistema](#-arquitectura-del-sistema)
- [Cumplimiento de Requisitos](#-cumplimiento-de-requisitos)
- [Instalación](#-instalación)
- [Uso](#-uso)
- [Pruebas y Validación](#-pruebas-y-validación)
- [Documentación Técnica](#-documentación-técnica)

---

## 📖 Descripción del Proyecto

Este proyecto implementa una **plataforma web distribuida** con dashboard centralizado que utiliza **6 contenedores Incus** interconectados para ofrecer:

### Componentes Principales

1. **Servidor Web (Dashboard)**: Aplicación Node.js/Express con dashboard multi-sección
   - Secciones: Dashboard, Ventas, Administración, Marketing, Estadísticas
   - **CRUD completo de productos** en la sección "Ventas"
   - Gestión de productos: nombre, descripción, precio, categoría, stock, SKU

2. **Base de Datos Fragmentada (MongoDB)**: 3 contenedores con 8 instancias MongoDB
   - **Fragmentación horizontal** por rangos alfabéticos (A-M / N-Z)
   - **Replica sets con failover automático** (<15 segundos)
   - **Replicación asíncrona** con lag <1 segundo

3. **Servidor de Autenticación**: Login y registro de usuarios con JWT
   - Validación de credenciales con bcrypt
   - Gestión de sesiones con JSON Web Tokens
   - Base de datos de usuarios con replica set

4. **Gestor Web Incus**: Interfaz gráfica para gestión de contenedores
   - Incus UI nativa en puerto 8443
   - Monitoreo y control de contenedores

---

## 🏗️ Arquitectura del Sistema

### Diagrama de Contenedores

El sistema utiliza **6 contenedores Incus** con **8 instancias de MongoDB** distribuidas:

```
┌─────────────────────────────────────────────────────────┐
│                   CAPA DE APLICACIÓN                     │
├─────────────────────────────────────────────────────────┤
│  ┌──────────┐     ┌──────────┐     ┌──────────┐       │
│  │   web    │     │   auth   │     │incus-ui  │       │
│  │  :3000   │     │  :3001   │     │  :8443   │       │
│  └──────────┘     └──────────┘     └──────────┘       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                CAPA DE BASE DE DATOS                     │
├─────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │    db1     │  │    db2     │  │    db3     │        │
│  ├────────────┤  ├────────────┤  ├────────────┤        │
│  │ :27017 (P) │  │ :27017 (P) │  │ :27017 (P) │        │
│  │ :27018 (S) │  │ :27018 (S) │  │ :27018 (A) │        │
│  │ :27019 (S) │  │ :27019 (S) │  │ :27019 (A) │        │
│  └────────────┘  └────────────┘  └────────────┘        │
└─────────────────────────────────────────────────────────┘
    P=PRIMARY  S=SECONDARY  A=ARBITER
```

### Descripción de Contenedores

| # | Contenedor | Rol Principal | Tecnología | Puertos |
|---|------------|---------------|------------|---------|
| 1 | **web** | Servidor Web + Dashboard | Node.js/Express | 3000 |
| 2 | **auth** | Servidor de Autenticación | Node.js/Express + JWT | 3001 |
| 3 | **db1** | Base de Datos 1 (3 instancias) | MongoDB 6.0 | 27017, 27018, 27019 |
| 4 | **db2** | Base de Datos 2 (2 instancias) | MongoDB 6.0 | 27017, 27018 |
| 5 | **db3** | Base de Datos 3 (3 instancias) | MongoDB 6.0 | 27017, 27018, 27019 |
| 6 | **incus-ui** | Gestor Web Incus | Incus UI | 8443 |

### Distribución de Instancias MongoDB (8 total)

| Contenedor | Puerto | Replica Set | Rol | Datos |
|------------|--------|-------------|-----|-------|
| **db1** | 27017 | rs_products_a | PRIMARY | Productos A-M |
| **db1** | 27018 | rs_products_b | SECONDARY | Productos N-Z (réplica) |
| **db1** | 27019 | rs_users | SECONDARY | Usuarios (réplica) |
| **db2** | 27017 | rs_products_b | PRIMARY | Productos N-Z |
| **db2** | 27018 | rs_products_a | SECONDARY | Productos A-M (réplica) |
| **db3** | 27017 | rs_users | PRIMARY | Usuarios |
| **db3** | 27018 | rs_products_a | ARBITER | Solo votación |
| **db3** | 27019 | rs_products_b | ARBITER | Solo votación |

---

## ✅ Cumplimiento de Requisitos

### 1️⃣ Servidor Web con Dashboard (Contenedor `web`)

- ✅ **Aplicación web desarrollada**: Node.js 20 + Express 4.18
- ✅ **Dashboard con múltiples secciones**:
  - Dashboard principal
  - Ventas (con CRUD de productos)
  - Administración
  - Marketing
  - Estadísticas
- ✅ **CRUD completo de productos** en sección "Ventas":
  - **Crear**: Formulario para agregar productos (nombre, descripción, precio, categoría, stock, SKU)
  - **Leer**: Lista completa de productos de ambos shards
  - **Actualizar**: Edición de productos existentes
  - **Eliminar**: Eliminación con confirmación
- ✅ **Comunicación con BD fragmentadas**: Routing automático según primera letra del nombre
- ✅ **Autenticación integrada**: Verificación de JWT antes de acceder a funcionalidades

### 2️⃣ Base de Datos Fragmentada - Contenedor `db1` (Base de Datos 1)

- ✅ **Estrategia de fragmentación**: **Horizontal por rangos alfabéticos**
  - **Justificación**: Distribución uniforme, escalable, simple de implementar
  - Productos A-M → Shard A (rs_products_a)
  - Productos N-Z → Shard B (rs_products_b)
- ✅ **Fragmento almacenado**: Productos con nombres A-M
- ✅ **Tecnología**: MongoDB 6.0.26 con Replica Sets
- ✅ **Replicación configurada**:
  - Tipo: **Asíncrona** (MongoDB default)
  - PRIMARY: db1:27017
  - SECONDARY: db2:27018 (réplica del fragmento)
  - ARBITER: db3:27018 (para mayoría en votaciones)
- ✅ **Tolerancia a fallos**: Failover automático en ~15 segundos

### 3️⃣ Base de Datos Fragmentada - Contenedor `db2` (Base de Datos 2)

- ✅ **Fragmento almacenado**: Productos con nombres N-Z
- ✅ **Continuidad de fragmentación**: Misma estrategia horizontal (A-M / N-Z)
- ✅ **Replicación configurada**:
  - Tipo: **Asíncrona**
  - PRIMARY: db2:27017
  - SECONDARY: db1:27018 (réplica del fragmento)
  - ARBITER: db3:27019
- ✅ **Alta disponibilidad**: Datos accesibles aunque db2 caiga (desde SECONDARY)

### 4️⃣ Servidor de Autenticación - Contenedor `auth`

- ✅ **Funcionalidad de login**: POST /auth/login con validación de credenciales
- ✅ **Funcionalidad de registro**: POST /auth/register para nuevos usuarios
- ✅ **Validación de credenciales**: Consulta a Base de Datos 3 (db3:27017)
- ✅ **Gestión de sesiones**: JSON Web Tokens (JWT) con expiración 8h
- ✅ **Comunicación con servidor web**: Middleware de autenticación en cada request
- ✅ **Seguridad**: Contraseñas hasheadas con bcrypt (10 salt rounds)

### 5️⃣ Base de Datos de Usuarios - Contenedor `db3` (Base de Datos 3)

- ✅ **Información almacenada**: Usuarios, contraseñas hasheadas, emails, roles
- ✅ **Tecnología**: MongoDB 6.0.26
- ✅ **Esquema de seguridad**:
  ```javascript
  {
    nombre: String,
    email: String (unique index),
    passwordHash: String (bcrypt),
    rol: String (admin/vendedor/marketing),
    createdAt: Date
  }
  ```
- ✅ **Replicación configurada**:
  - PRIMARY: db3:27017
  - SECONDARY: db1:27019 (réplica completa)

### 6️⃣ Gestor Web Incus - Contenedor `incus-ui`

- ✅ **Interfaz gráfica instalada**: Incus UI nativa (Canonical)
- ✅ **Puerto configurado**: 8443 (HTTPS)
- ✅ **Funcionalidad**: Gestión visual de los 6 contenedores del proyecto
- ✅ **Acceso**: https://[host]:8443

---

## 🔀 Estrategia de Fragmentación Detallada

### Tipo: Fragmentación Horizontal por Rangos Alfabéticos

**Criterio**: Primera letra del nombre del producto (campo `name`)

```
┌─────────────────────────────────────────────────┐
│         Tabla Lógica: productos                 │
│  {name, description, price, category, stock}    │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐  ┌──────────────┐
│  Shard A-M   │  │  Shard N-Z   │
│ rs_products_a│  │ rs_products_b│
│              │  │              │
│ db1:27017 P  │  │ db2:27017 P  │
│ db2:27018 S  │  │ db1:27018 S  │
│ db3:27018 A  │  │ db3:27019 A  │
└──────────────┘  └──────────────┘
```

**Justificación de la elección:**

| Criterio | Ventaja |
|----------|---------|
| **Simplicidad** | Fácil de implementar y entender para fines académicos |
| **Balance** | Distribución uniforme en idioma español |
| **Escalabilidad** | Fácil agregar nuevos rangos (A-G, H-M, N-T, U-Z) |
| **Predecibilidad** | Consultas por nombre pueden ir directamente al shard correcto |
| **Transparencia** | La aplicación controla el routing sin complejidad adicional |

**Alternativas evaluadas y descartadas:**

- ❌ **Por categoría**: Desbalance si hay muchos productos de una categoría
- ❌ **Vertical**: Mayor complejidad en queries, no aporta ventajas en este caso
- ❌ **Hash**: Menos predecible para consultas por nombre

---

## 📊 Configuración de Réplicas

### Replica Set 1: rs_products_a (Productos A-M)

```
PRIMARY:    db1:27017  ←──┐
                          ├─── Replicación Asíncrona
SECONDARY:  db2:27018  ←──┤
                          │
ARBITER:    db3:27018  ←──┘ (votación sin datos)
```

- **Write Concern**: w=majority, wtimeout=5000ms
- **Read Preference**: primaryPreferred
- **Failover**: Automático con elección de nuevo PRIMARY

### Replica Set 2: rs_products_b (Productos N-Z)

```
PRIMARY:    db2:27017  ←──┐
                          ├─── Replicación Asíncrona
SECONDARY:  db1:27018  ←──┤
                          │
ARBITER:    db3:27019  ←──┘ (votación sin datos)
```

- **Write Concern**: w=majority, wtimeout=5000ms
- **Failover**: Automático con promoción de SECONDARY

### Replica Set 3: rs_users (Usuarios)

```
PRIMARY:    db3:27017  ←──┐
                          ├─── Replicación Asíncrona
SECONDARY:  db1:27019  ←──┘
```

- **Write Concern**: w=majority
- **Failover**: Automático (2 nodos con datos completos)

---

---

## � Requisitos del Sistema

- **Sistema Operativo**: Linux (Ubuntu 22.04+)
- **Incus**: 6.0+
- **Recursos mínimos**:
  - CPU: 4+ cores
  - RAM: 8GB
  - Disco: 20GB libre

---

---

## 🚀 Instalación

### Opción 1: Instalación Automática (Recomendada)

```bash
# Clonar repositorio
git clone https://github.com/CamiloMunozAL/proyecto_distribuidos
cd proyecto_distribuidos

# Ejecutar instalación completa
chmod +x scripts/00_install_all.sh
./scripts/00_install_all.sh
```

El script ejecutará los 11 pasos de instalación automáticamente.

### Opción 2: Instalación Manual

```bash
chmod +x scripts/*.sh

# 1-2. Configurar Incus y crear contenedores
./scripts/00_setup_incus.sh
./scripts/01_create_containers.sh

# 3-7. Configurar MongoDB con replica sets
./scripts/02_install_mongodb.sh
./scripts/03_configure_replicas.sh
./scripts/04_init_replicasets.sh
./scripts/03.2_add_arbiters_and_secondary.sh

# 8-9. Configurar bases de datos
./scripts/05_create_db_users.sh
./scripts/06_seed_data.sh

# 10-12. Instalar servicios de aplicación
./scripts/09_setup_auth_service.sh
./scripts/10_setup_web_dashboard.sh
./scripts/07_install_incus_ui.sh
```

### Verificación

```bash
# Ver contenedores
incus list

# Verificar replica sets
incus exec db1 -- mongosh --port 27017 --eval "rs.status()" --quiet | grep stateStr
```

---

---

## 💻 Uso del Sistema

### Acceso al Dashboard

**URL**: `http://[IP_WEB]:3000`

**Credenciales de prueba:**
- Email: `admin@test.com`
- Password: `admin123`

### CRUD de Productos (Sección Ventas)

1. **Crear producto**: Click en "Agregar Producto" → Llenar formulario
2. **Ver productos**: Lista automática de ambos shards
3. **Editar**: Click en "Editar" → Modificar campos
4. **Eliminar**: Click en "Eliminar" → Confirmar

### Gestor Web Incus

**URL**: `https://[HOST]:8443`

Permite ver y gestionar los 6 contenedores del proyecto visualmente.

---

---

## 🧪 Pruebas y Validación

### Pruebas Realizadas

| # | Prueba | Resultado | Evidencia |
|---|--------|-----------|-----------|
| 1 | Autenticación (Login/Registro) | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 2 | CRUD Productos (Crear) | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 3 | CRUD Productos (Leer) | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 4 | CRUD Productos (Actualizar) | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 5 | CRUD Productos (Eliminar) | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 6 | Fragmentación (Shard A-M) | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 7 | Fragmentación (Shard N-Z) | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 8 | Replicación Shard A | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 9 | Replicación Shard B | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 10 | Replicación Usuarios | ✅ Exitosa | RESULTADOS_PRUEBAS.md |
| 11 | Failover Automático | ✅ Exitosa | RESULTADOS_PRUEBAS.md |

**Tasa de éxito: 100% (11/11)**

### Prueba de Failover (Tolerancia a Fallos)

```bash
# Detener PRIMARY de Shard A
incus stop db1
sleep 15

# Verificar promoción automática
incus exec db2 -- mongosh --port 27018 --eval "rs.status()"
# Resultado: db2:27018 → PRIMARY (en ~15 segundos)

# Recuperar nodo
incus start db1
# Resultado: db1:27017 → SECONDARY (sincronización automática)
```

✅ **Sin pérdida de datos** en failover

### Guía Completa de Pruebas

Ver documento: **[pruebas.md](./pruebas.md)** para ejecutar todas las validaciones paso a paso.

---

## 📚 Documentación

---

## 📚 Documentación Técnica

| Documento | Descripción |
|-----------|-------------|
| [ARQUITECTURA.md](./ARQUITECTURA.md) | Diseño técnico detallado con diagramas |
| [pruebas.md](./pruebas.md) | Guía de validación paso a paso |
| [RESULTADOS_PRUEBAS.md](./RESULTADOS_PRUEBAS.md) | Evidencia de las 11 pruebas (100% exitosas) |
| [explain.md](./guides/explain.md) | Explicación de la arquitectura de BD |
| [SCRIPTS.md](./SCRIPTS.md) | Documentación de scripts de instalación |

---

## 📊 Métricas del Sistema

| Métrica | Valor |
|---------|-------|
| **Contenedores Incus** | 6 (web, auth, db1, db2, db3, incus-ui) |
| **Instancias MongoDB** | 8 distribuidas (db1:3, db2:2, db3:3) |
| **Replica Sets** | 3 con failover automático |
| **Tiempo de failover** | ~15 segundos |
| **Lag de replicación** | <1 segundo |
| **Tasa de éxito pruebas** | 100% (11/11) |
| **MongoDB** | 6.0.26 Community |
| **Node.js** | 20 LTS |

---

## 👥 Información Académica

**Proyecto**: Sistema Distribuido con Incus y MongoDB  
**Objetivo**: Implementar arquitectura distribuida con fragmentación y replicación  
**Año**: 2025  
**Estado**: ✅ Completado y validado (100% funcional)

---

## 📝 Resumen Ejecutivo

Este proyecto implementa exitosamente todos los requisitos académicos:

✅ **6 contenedores Incus** interconectados  
✅ **Dashboard web** con múltiples secciones (Ventas, Admin, Marketing, Estadísticas)  
✅ **CRUD completo** de productos en sección Ventas  
✅ **Fragmentación horizontal** de BD por rangos alfabéticos (A-M / N-Z)  
✅ **Replicación asíncrona** configurada en todos los fragmentos  
✅ **Servidor de autenticación** con login/registro y JWT  
✅ **Base de datos de usuarios** con replica set  
✅ **Gestor web Incus UI** en puerto 8443  
✅ **Tolerancia a fallos** probada con failover automático  
✅ **Sin pérdida de datos** en escenarios de fallo  

**Resultado**: Sistema distribuido completamente funcional con alta disponibilidad y escalabilidad.

### Métricas del Sistema

| Métrica | Valor |
|---------|-------|
| Contenedores | 6 (3 BD + auth + web + incus-ui) |
| Instancias MongoDB | 9 (3 por contenedor BD) |
| Replica Sets | 3 (rs_products_a, rs_products_b, rs_users) |
| Tiempo de failover | ~15 segundos |
| Lag de replicación | <1 segundo |
| Tasa de éxito de pruebas | 100% (11/11) |
| Versión MongoDB | 8.0 Community |
| Versión Node.js | 20 LTS |

---

## 🛠️ Administración

### Comandos Útiles

```bash
# Ver logs del dashboard
incus exec web -- journalctl -u web-dashboard -f

# Ver logs de autenticación
incus exec auth -- journalctl -u auth-service -f

# Acceder a MongoDB
incus exec db1 -- mongosh mongodb://db1:27017/productos_db?replicaSet=rs_products_a

# Verificar estado de replica set
incus exec db1 -- mongosh --quiet mongodb://db1:27017/?replicaSet=rs_products_a \
  --eval "rs.status()"

# Reiniciar servicios
incus exec web -- systemctl restart web-dashboard
incus exec auth -- systemctl restart auth-service
```

### Backup y Recuperación

```bash
# Backup de Shard A (rs_products_a)
incus exec db1 -- mongodump --port 27017 --db productos_db --out /backup/shard_a

# Backup de Shard B (rs_products_b)
incus exec db2 -- mongodump --port 27017 --db productos_db --out /backup/shard_b

# Backup de usuarios
incus exec db3 -- mongodump --port 27017 --db auth_db --out /backup/users

# Restaurar backup de Shard A
incus exec db1 -- mongorestore --port 27017 --db productos_db /backup/shard_a/productos_db

# Restaurar backup de usuarios
incus exec db3 -- mongorestore --port 27017 --db auth_db /backup/users/auth_db
```

---

## 🔧 Solución de Problemas

### El dashboard no carga

```bash
# Verificar estado del servicio
incus exec web -- systemctl status web-dashboard

# Ver logs
incus exec web -- journalctl -u web-dashboard -n 50

# Reiniciar servicio
incus exec web -- systemctl restart web-dashboard
```

### Error de autenticación

```bash
# Verificar servicio auth
incus exec auth -- systemctl status auth-service

# Verificar conectividad con MongoDB
incus exec auth -- mongosh mongodb://db3:27017/auth_db?replicaSet=rs_users --eval "db.users.find().limit(1)"
```

### Replica set no responde

```bash
# Verificar estado del replica set
incus exec db1 -- mongosh --quiet mongodb://db1:27017/?replicaSet=rs_products_a \
  --eval "rs.status()"

# Reiniciar MongoDB
incus exec db1 -- systemctl restart mongod-27017
```

---

## 🔗 Enlaces Rápidos

### Documentación Técnica
- 📖 [ARQUITECTURA.md](./ARQUITECTURA.md) - Diseño técnico detallado del sistema
- 📘 [uso.md](./uso.md) - Guía completa de uso y operación
- � [pruebas.md](./pruebas.md) - Guía de validación y pruebas
- 📊 [RESULTADOS_PRUEBAS.md](./RESULTADOS_PRUEBAS.md) - Evidencia de pruebas ejecutadas
- 🔧 [SCRIPTS.md](./SCRIPTS.md) - Documentación de scripts de instalación
- 📝 [CHANGELOG_SCRIPTS.md](./CHANGELOG_SCRIPTS.md) - Historial de cambios en scripts

### Guías de Instalación
- 🚀 [Instalación Rápida](#instalación-automatizada-completa-recomendada)
- 📋 [Instalación Paso a Paso](#instalación-manual-paso-a-paso)
- 🐛 [Solución de Problemas](#-solución-de-problemas)

### Acceso al Sistema
- 🌐 **Dashboard Web**: http://10.122.112.159:3000
- 🔐 **API Auth**: http://10.122.112.106:3001
- 🖥️ **Incus UI**: https://[host]:8443

---

## �🤝 Contribuciones

Este proyecto es parte de un trabajo académico sobre sistemas distribuidos.

---

## 📄 Licencia

Este proyecto es de uso académico.

---
