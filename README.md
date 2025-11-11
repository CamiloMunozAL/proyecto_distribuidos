# 🌐 Sistema Distribuido de Gestión de Productos

Sistema distribuido con arquitectura de microservicios implementado sobre contenedores Incus, utilizando MongoDB con sharding y replica sets para alta disponibilidad.

![Status](https://img.shields.io/badge/status-active-success.svg)
![MongoDB](https://img.shields.io/badge/MongoDB-8.0-green.svg)
![Node.js](https://img.shields.io/badge/Node.js-20-green.svg)
![Incus](https://img.shields.io/badge/Incus-LXD-blue.svg)

---

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Arquitectura](#-arquitectura)
- [Requisitos](#-requisitos)
- [Instalación](#-instalación)
- [Uso](#-uso)
- [Pruebas](#-pruebas)
- [Documentación](#-documentación)

---

## ✨ Características

- ✅ **Alta Disponibilidad**: 3 replica sets con failover automático (<15 segundos)
- ✅ **Sharding Manual**: Fragmentación horizontal por rangos alfabéticos (A-M / N-Z)
- ✅ **Autenticación JWT**: Sistema seguro con tokens stateless
- ✅ **Dashboard Web**: Interfaz gráfica moderna con Bootstrap y EJS
- ✅ **Tolerancia a Fallos**: Sin pérdida de datos ante caídas de nodos (probado)
- ✅ **Arquitectura Multi-instancia**: 9 instancias de MongoDB en 3 contenedores
- ✅ **Replicación Sincrónica**: Lag < 1 segundo entre PRIMARY y SECONDARY
- ✅ **APIs RESTful**: Endpoints para productos y autenticación

---

## 🏗️ Arquitectura

### Visión General

El sistema utiliza **6 contenedores Incus** con **9 instancias de MongoDB** distribuidas estratégicamente para lograr alta disponibilidad y sharding manual:

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

### Contenedores

| Contenedor | IP (ejemplo) | Rol | Servicios MongoDB |
|------------|--------------|-----|-------------------|
| **web** | 10.122.112.159 | Dashboard + API productos | - |
| **auth** | 10.122.112.106 | Autenticación JWT | - |
| **db1** | 10.122.112.153 | Nodo BD Multi-instancia | 27017 (rs_products_a PRIMARY)<br>27018 (rs_products_b SECONDARY)<br>27019 (rs_users SECONDARY) |
| **db2** | 10.122.112.233 | Nodo BD Multi-instancia | 27017 (rs_products_b PRIMARY)<br>27018 (rs_products_a SECONDARY)<br>27019 (rs_users SECONDARY) |
| **db3** | 10.122.112.16 | Nodo BD Multi-instancia | 27017 (rs_users PRIMARY)<br>27018 (rs_products_a ARBITER)<br>27019 (rs_products_b ARBITER) |
| **incus-ui** | 10.122.112.195 | Gestión de contenedores | Incus UI:8443 |

### Replica Sets

```
rs_products_a (Shard A-M - Productos con nombres A-M)
├── PRIMARY:   db1:27017  (datos + escrituras)
├── SECONDARY: db2:27018  (datos + lecturas + failover)
└── ARBITER:   db3:27018  (solo votación, sin datos)

rs_products_b (Shard N-Z - Productos con nombres N-Z)
├── PRIMARY:   db2:27017  (datos + escrituras)
├── SECONDARY: db1:27018  (datos + lecturas + failover)
└── ARBITER:   db3:27019  (solo votación, sin datos)

rs_users (Autenticación - Usuarios del sistema)
├── PRIMARY:   db3:27017  (datos + escrituras)
└── SECONDARY: db1:27019  (datos + lecturas + failover)
```

**Ventajas de esta arquitectura:**
- ✅ **3 nodos por contenedor**: Aprovecha recursos eficientemente
- ✅ **Alta disponibilidad**: Cada replica set con failover automático
- ✅ **Sin SPOF**: Fallo de cualquier contenedor no detiene el sistema
- ✅ **Árbitros para mayoría**: Garantiza elecciones sin empates

### Sharding

**Estrategia de fragmentación por rangos alfabéticos:**

```
Productos A-M → rs_products_a (Shard A)
├── PRIMARY:   db1:27017
├── SECONDARY: db2:27018
└── ARBITER:   db3:27018

Productos N-Z → rs_products_b (Shard B)
├── PRIMARY:   db2:27017
├── SECONDARY: db1:27018
└── ARBITER:   db3:27019
```

**Cómo funciona:**
- La aplicación determina el shard según la primera letra del nombre del producto
- Nombres A-M van al Shard A (rs_products_a)
- Nombres N-Z van al Shard B (rs_products_b)
- Cada shard tiene su propio replica set para alta disponibilidad

---

## 📦 Requisitos

- **Sistema Operativo**: Linux (Ubuntu 22.04+ recomendado)
- **Incus**: 6.0+
- **Recursos mínimos**:
  - CPU: 4+ cores (recomendado 6-8 cores)
  - RAM: 8GB mínimo (recomendado 12-16GB)
  - Disco: 20GB+ espacio libre

**Nota importante:** El sistema usa 6 contenedores con 9 instancias de MongoDB distribuidas. Cada contenedor de base de datos ejecuta 3 instancias de MongoDB simultáneamente en diferentes puertos (27017, 27018, 27019).

---

## 🚀 Instalación

### Instalación Automatizada Completa (Recomendada)

```bash
# 1. Clonar el repositorio
git clone <repository-url>
cd proyecto_distribuidos

# 2. Ejecutar script maestro de instalación
chmod +x scripts/00_install_all.sh
./scripts/00_install_all.sh
```

El script maestro ejecutará automáticamente todos los pasos de instalación en orden.

### Instalación Manual Paso a Paso

Si prefieres ejecutar cada paso manualmente:

```bash
# Dar permisos de ejecución a todos los scripts
chmod +x scripts/*.sh

# 1. Configurar red Incus
./scripts/00_setup_incus.sh

# 2. Crear contenedores (db1, db2, db3, auth, web, incus-ui)
./scripts/01_create_containers.sh

# 3. Instalar MongoDB 8.0 en nodos de base de datos
./scripts/02_install_mongodb.sh

# 4. Configurar servicios MongoDB (múltiples instancias por contenedor)
./scripts/03_configure_replicas.sh

# 5. Corregir permisos (si es necesario)
./scripts/03.1_config.sh

# 6. Inicializar replica sets (PRIMARY + SECONDARY)
./scripts/04_init_replicasets.sh

# 7. Agregar árbitros para alta disponibilidad
./scripts/03.2_add_arbiters_and_secondary.sh

# 8. Crear usuarios de base de datos
./scripts/05_create_db_users.sh

# 9. Crear estructura de base de datos
./scripts/06_seed_data.sh

# 10. Instalar servicio de autenticación JWT
./scripts/09_setup_auth_service.sh

# 11. Instalar dashboard web
./scripts/10_setup_web_dashboard.sh
./scripts/10.1_views_and_server.sh

# 12. (Opcional) Habilitar Incus UI
./scripts/07_install_incus_ui.sh
```

### Verificar Instalación

```bash
# Verificar contenedores activos
incus list

# Verificar replica sets
incus exec db1 -- mongosh --quiet mongodb://db1:27017/?replicaSet=rs_products_a --eval "rs.status()" 2>/dev/null | grep -E "name|stateStr"
```

---

## 💻 Uso

### Acceso al Dashboard Web

```
URL: http://10.122.112.159:3000
```

**Credenciales por defecto:**
- Email: `admin@test.com`
- Password: `admin123`

### API REST - Productos

#### Crear Producto (Shard A-M)
```bash
curl -X POST http://10.122.112.159:3000/productos/api \
  -H "Content-Type: application/json" \
  -H "Cookie: token=<JWT_TOKEN>" \
  -d '{
    "name": "Laptop Dell",
    "description": "Laptop de alto rendimiento",
    "price": 1299.99,
    "category": "Electrónica",
    "stock": 15
  }'
```

#### Listar Productos
```bash
curl http://10.122.112.159:3000/productos/api \
  -H "Cookie: token=<JWT_TOKEN>"
```

### API REST - Autenticación

#### Registro
```bash
curl -X POST http://10.122.112.106:3001/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Usuario Nuevo",
    "email": "usuario@example.com",
    "password": "password123",
    "rol": "vendedor"
  }'
```

#### Login
```bash
curl -X POST http://10.122.112.106:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123"
  }'
```

---

## 🧪 Pruebas

### Suite de Pruebas Completa

Ver la guía completa en: **[pruebas.md](./pruebas.md)**

```bash
# Prueba rápida de conectividad
# Dashboard web
curl -s http://10.122.112.159:3000 | grep -q "html" && echo "✅ Dashboard OK" || echo "❌ Dashboard ERROR"

# Servicio de autenticación
curl -s -X POST http://10.122.112.106:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test","password":"test"}' | grep -q "error\|token" && echo "✅ Auth OK" || echo "❌ Auth ERROR"

# Replica sets
incus exec db1 -- mongosh --quiet mongodb://db1:27017/?replicaSet=rs_products_a \
  --eval "rs.status().ok" 2>/dev/null && echo "✅ rs_products_a OK" || echo "❌ rs_products_a ERROR"
```

### Prueba de Failover

```bash
# 1. Verificar estado inicial
incus exec db1 -- mongosh --quiet mongodb://db1:27017/?replicaSet=rs_products_a \
  --eval "rs.status().members.forEach(m => print(m.name + ' - ' + m.stateStr))"

# 2. Simular fallo del PRIMARY
incus stop db1
sleep 15

# 3. Verificar promoción automática
incus exec db2 -- mongosh --quiet mongodb://db2:27018/?replicaSet=rs_products_a \
  --eval "rs.status().members.forEach(m => print(m.name + ' - ' + m.stateStr))"

# 4. Recuperar nodo
incus start db1
```

**Resultado esperado:** db2:27018 se convierte en PRIMARY automáticamente (~15 segundos).

### Resultados de Pruebas

✅ **11/11 pruebas exitosas (100%)**
- Autenticación JWT funcional
- CRUD completo con routing automático
- Sharding operacional (1 producto por shard)
- Replicación < 1 segundo de lag
- Failover automático sin pérdida de datos

Ver resultados detallados en `RESULTADOS_PRUEBAS.md`.

---

## 📚 Documentación

### Documentos Disponibles

- **[ARQUITECTURA.md](./ARQUITECTURA.md)**: Diseño técnico completo del sistema
- **[uso.md](./uso.md)**: Guía detallada de uso y operación
- **[pruebas.md](./pruebas.md)**: Guía de validación con resultados
- **[RESULTADOS_PRUEBAS.md](./RESULTADOS_PRUEBAS.md)**: Evidencia de pruebas ejecutadas
- **[Incus.md](./Incus.md)**: Configuración de contenedores Incus
- **[DocumentoGuia.md](./DocumentoGuia.md)**: Guía de desarrollo

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

## 👨‍💻 Autor

Proyecto de Sistemas Distribuidos  
Universidad: [Tu Universidad]  
Año: 2025

---

## 🎯 Estado del Proyecto

✅ **Sistema completamente funcional y validado**

**Componentes verificados:**
- ✅ Alta disponibilidad con failover automático (<15s)
- ✅ Tolerancia a fallos sin pérdida de datos
- ✅ Sharding manual operacional (A-M / N-Z)
- ✅ Replicación sincrónica (<1s lag)
- ✅ 3 replica sets funcionando correctamente
- ✅ Autenticación JWT funcional
- ✅ Dashboard web completo
- ✅ APIs RESTful operacionales
- ✅ Suite de pruebas: 11/11 exitosas (100%)

**Métricas de rendimiento:**
- Tiempo de failover: ~15 segundos
- Lag de replicación: <1 segundo
- Contenedores activos: 6/6
- Instancias MongoDB: 9/9 operacionales

**Última actualización:** 11 de noviembre de 2025  
**Versión:** 1.0.0

---

## 📝 Changelog

### v1.0.0 - 11 de noviembre de 2025
- ✅ Sistema distribuido completo implementado
- ✅ 6 contenedores con 9 instancias de MongoDB
- ✅ 3 replica sets con failover automático
- ✅ Sharding manual por rangos alfabéticos
- ✅ Dashboard web con autenticación JWT
- ✅ Suite de pruebas completa (11/11 exitosas)
- ✅ Documentación técnica completa
- ✅ Scripts de instalación automatizados
