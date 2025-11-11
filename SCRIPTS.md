# 📜 Documentación de Scripts de Instalación

Este documento describe todos los scripts de instalación del sistema distribuido y el orden correcto de ejecución.

---

## 🎯 Orden de Ejecución

### Opción 1: Instalación Automática (Recomendada)

```bash
./scripts/00_install_all.sh
```

Este script maestro ejecuta todos los demás scripts en el orden correcto.

### Opción 2: Instalación Manual

Ejecutar los scripts en este orden específico:

```
00_setup_incus.sh          → Configuración de red Incus
01_create_containers.sh     → Creación de contenedores
02_install_mongodb.sh       → Instalación de MongoDB 8.0
03_configure_replicas.sh    → Configuración de servicios systemd
03.1_config.sh             → Corrección de permisos (si necesario)
04_init_replicasets.sh     → Inicialización de replica sets
03.2_add_arbiters...sh     → Agregar árbitros para HA
05_create_db_users.sh      → Crear usuarios de BD
06_seed_data.sh            → Crear estructura de BD
09_setup_auth_service.sh   → Instalar servicio de autenticación
10_setup_web_dashboard.sh  → Instalar dashboard web
10.1_views_and_server.sh   → Configurar vistas y servidor
07_install_incus_ui.sh     → (Opcional) Incus UI
```

---

## 📋 Descripción Detallada de Scripts

### 00_install_all.sh
**Script maestro de instalación automatizada**

- **Propósito**: Ejecuta todos los scripts de instalación en orden
- **Duración**: ~10-15 minutos
- **Requisitos**: Ninguno (ejecuta todo desde cero)
- **Características**:
  - Manejo de errores
  - Output coloreado
  - Confirmación de usuario
  - Resumen final con URLs e IPs

**Uso:**
```bash
chmod +x scripts/00_install_all.sh
./scripts/00_install_all.sh
```

---

### 00_setup_incus.sh
**Configuración inicial de red Incus**

- **Propósito**: Crear red `incusbr0` y perfil `dist-net`
- **Componentes**:
  - Red: `10.66.66.1/24` con NAT
  - Perfil con límites: 2 CPU, 2GB RAM
- **Output**: Red y perfil listos

**Uso:**
```bash
./scripts/00_setup_incus.sh
```

---

### 01_create_containers.sh
**Creación de contenedores base**

- **Propósito**: Crear 6 contenedores del sistema
- **Contenedores creados**:
  - `db1`, `db2`, `db3`: Nodos de base de datos
  - `auth`: Servidor de autenticación
  - `web`: Dashboard y API
  - `incus-ui`: Gestión de contenedores
- **Imagen**: Ubuntu 22.04 LTS
- **Tiempo**: ~2-3 minutos

**Uso:**
```bash
./scripts/01_create_containers.sh
```

**Verificación:**
```bash
incus list
```

---

### 02_install_mongodb.sh
**Instalación de MongoDB 8.0 Community Edition**

- **Propósito**: Instalar MongoDB en db1, db2, db3
- **Versión**: MongoDB 8.0 (última versión)
- **Acciones**:
  - Agregar repositorio oficial de MongoDB
  - Instalar paquetes mongodb-org
  - Deshabilitar servicio por defecto
- **Tiempo**: ~5 minutos

**Uso:**
```bash
./scripts/02_install_mongodb.sh
```

**Verificación:**
```bash
incus exec db1 -- mongod --version
```

---

### 03_configure_replicas.sh
**Configuración de servicios systemd para MongoDB**

- **Propósito**: Crear múltiples instancias de MongoDB por contenedor
- **Servicios creados**:

#### db1 (3 servicios):
- `mongod-27017.service`: rs_products_a PRIMARY
- `mongod-27018.service`: rs_products_b SECONDARY
- `mongod-27019.service`: rs_users SECONDARY

#### db2 (3 servicios):
- `mongod-27017.service`: rs_products_b PRIMARY
- `mongod-27018.service`: rs_products_a SECONDARY
- `mongod-27019.service`: rs_users SECONDARY

#### db3 (3 servicios):
- `mongod-27017.service`: rs_users PRIMARY
- `mongod-27018.service`: rs_products_a ARBITER
- `mongod-27019.service`: rs_products_b ARBITER

**Uso:**
```bash
./scripts/03_configure_replicas.sh
```

**Verificación:**
```bash
incus exec db1 -- systemctl status mongod-27017
```

---

### 03.1_config.sh
**Corrección de permisos y reinicio de servicios**

- **Propósito**: Corregir permisos si los servicios no iniciaron
- **Acciones**:
  - Crear directorios `/data/db-*` si no existen
  - Asignar propietario `mongodb:mongodb`
  - Reiniciar servicios systemd
- **Cuándo usar**: Si hay errores en 03_configure_replicas.sh

**Uso:**
```bash
./scripts/03.1_config.sh
```

---

### 04_init_replicasets.sh
**Inicialización de replica sets**

- **Propósito**: Iniciar los 3 replica sets con miembros iniciales
- **Replica sets inicializados**:
  - `rs_products_a`: db1:27017 (P) + db2:27018 (S)
  - `rs_products_b`: db2:27017 (P) + db1:27018 (S)
  - `rs_users`: db3:27017 (P) + db1:27019 (S)
- **Tiempo**: ~30 segundos
- **Nota**: Aún falta agregar árbitros (siguiente script)

**Uso:**
```bash
./scripts/04_init_replicasets.sh
```

**Verificación:**
```bash
incus exec db1 -- mongosh --port 27017 --quiet --eval "rs.status()"
```

---

### 03.2_add_arbiters_and_secondary.sh
**Agregar árbitros para alta disponibilidad**

- **Propósito**: Completar configuración de HA agregando árbitros
- **Acciones**:
  - Agregar db3:27018 como ARBITER de rs_products_a
  - Agregar db3:27019 como ARBITER de rs_products_b
  - Configurar write concern (w=majority)
- **Resultado**: Failover automático habilitado

**Uso:**
```bash
./scripts/03.2_add_arbiters_and_secondary.sh
```

**Verificación:**
```bash
incus exec db1 -- mongosh --port 27017 --quiet --eval "rs.status().members.forEach(m => print(m.name + ' - ' + m.stateStr))"
```

---

### 05_create_db_users.sh
**Creación de usuarios de aplicación**

- **Propósito**: Crear usuarios con permisos de lectura/escritura
- **Usuarios creados**:
  - `productos_user:productos_pass` → productos_db (ambos shards)
  - `auth_user:auth_pass` → auth_db (rs_users)
- **Roles**: readWrite, dbAdmin

**Uso:**
```bash
./scripts/05_create_db_users.sh
```

---

### 06_seed_data.sh
**Creación de estructura de base de datos**

- **Propósito**: Crear colecciones e índices
- **Colecciones creadas**:
  - `productos_db.productos` (en ambos shards)
  - `auth_db.users`
- **Índices creados**:
  - Productos: name (unique), category, sku (unique)
  - Usuarios: email (unique)

**Uso:**
```bash
./scripts/06_seed_data.sh
```

---

### 09_setup_auth_service.sh
**Instalación del servicio de autenticación JWT**

- **Propósito**: Desplegar microservicio de autenticación
- **Contenedor**: auth
- **Puerto**: 3001
- **Dependencias**: Node.js 20, Express, jsonwebtoken, bcrypt
- **Funcionalidades**:
  - Registro de usuarios
  - Login con JWT
  - Validación de tokens

**Verificación:**
```bash
curl http://$(incus list auth -c 4 -f csv | cut -d' ' -f1):3001/health
```

---

### 10_setup_web_dashboard.sh
**Instalación del dashboard web**

- **Propósito**: Desplegar interfaz web y API de productos
- **Contenedor**: web
- **Puerto**: 3000
- **Dependencias**: Node.js 20, Express, EJS, cookie-parser
- **Funcionalidades**:
  - Dashboard con login
  - CRUD de productos con sharding
  - Indicadores visuales de shards

**Verificación:**
```bash
curl http://$(incus list web -c 4 -f csv | cut -d' ' -f1):3000
```

---

### 10.1_views_and_server.sh
**Configuración de vistas y servidor web**

- **Propósito**: Configurar templates EJS y rutas
- **Componentes**:
  - Views: login, dashboard, productos
  - Routes: autenticación, CRUD productos
  - Middleware: JWT validation

---

### 07_install_incus_ui.sh
**Activación de Incus UI (Opcional)**

- **Propósito**: Habilitar interfaz web de gestión de Incus
- **Puerto**: 8443 (HTTPS)
- **Acceso**: `https://<host-ip>:8443`
- **Características**:
  - Gestión visual de contenedores
  - Monitoreo de recursos
  - Consola web

**Uso:**
```bash
./scripts/07_install_incus_ui.sh
```

---

## 🔧 Troubleshooting

### Script falla en paso X

```bash
# Ver logs del script
cat /tmp/install_log.txt

# Reintentar desde ese paso específico
./scripts/0X_nombre_script.sh
```

### Servicios MongoDB no inician

```bash
# Ejecutar script de corrección
./scripts/03.1_config.sh

# Ver logs de systemd
incus exec db1 -- journalctl -u mongod-27017 -n 50
```

### Replica set no se inicializa

```bash
# Verificar conectividad
incus exec db1 -- mongosh --port 27017 --eval "rs.status()"

# Reiniciar servicios
incus exec db1 -- systemctl restart mongod-27017
```

---

## 📊 Tiempos Estimados

| Script | Duración |
|--------|----------|
| 00_install_all.sh | 10-15 min |
| 00_setup_incus.sh | <1 min |
| 01_create_containers.sh | 2-3 min |
| 02_install_mongodb.sh | 4-5 min |
| 03_configure_replicas.sh | 1 min |
| 03.1_config.sh | <1 min |
| 04_init_replicasets.sh | 30 seg |
| 03.2_add_arbiters...sh | 30 seg |
| 05_create_db_users.sh | 10 seg |
| 06_seed_data.sh | 10 seg |
| 09_setup_auth_service.sh | 1-2 min |
| 10_setup_web_dashboard.sh | 1-2 min |
| 10.1_views_and_server.sh | <1 min |
| 07_install_incus_ui.sh | <1 min |

---

## ✅ Verificación Post-Instalación

```bash
# 1. Verificar contenedores
incus list

# 2. Verificar replica sets
incus exec db1 -- mongosh --port 27017 --quiet --eval "rs.status().members.forEach(m => print(m.name + ' - ' + m.stateStr))"

# 3. Verificar servicios web
curl http://$(incus list web -c 4 -f csv | cut -d' ' -f1):3000/health
curl http://$(incus list auth -c 4 -f csv | cut -d' ' -f1):3001/health

# 4. Ejecutar suite de pruebas
# Ver: pruebas.md
```

---

**Última actualización**: 11 de noviembre de 2025
