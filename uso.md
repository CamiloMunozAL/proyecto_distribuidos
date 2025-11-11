# 📘 Guía de Uso - Sistema Distribuido

## 🎯 Acceso Rápido al Sistema

### 🌐 Dashboard Web Principal
**URL:** http://10.122.112.159:3000

### 🔐 Servidor de Autenticación
**URL:** http://10.122.112.106:3001

### 🖥️ Incus UI (Gestión de Contenedores)
**URL:** https://10.0.2.15:8443
- **Usuario:** admin
- **Contraseña:** (configurar en primer acceso)

---

## 👥 Credenciales de Usuarios

### Usuario Administrador (Pre-creado)
- **Email:** admin@example.com
- **Contraseña:** admin123
- **Rol:** admin

### Crear Nuevos Usuarios
Puedes registrar nuevos usuarios desde: http://10.122.112.159:3000/register

**Roles disponibles:**
- `admin` - Acceso completo al sistema
- `vendedor` - Gestión de productos y ventas
- `marketing` - Acceso a campañas y estadísticas

---

## 🚀 Instrucciones de Inicio

### 1️⃣ Verificar que los Servicios Están Activos

```bash
# Ver estado de todos los contenedores
incus list

# Verificar servicio web
incus exec web -- systemctl status web-dashboard

# Verificar servicio de autenticación
incus exec auth -- systemctl status auth-service

# Verificar MongoDB en db1
incus exec db1 -- systemctl status mongod-27017
```

### 2️⃣ Acceder al Dashboard Web

1. **Abre tu navegador** en: http://10.122.112.159:3000
2. **Inicia sesión** con las credenciales del administrador:
   - Email: `admin@example.com`
   - Contraseña: `admin123`
3. Serás redirigido al **Dashboard Principal**

### 3️⃣ Registrar un Nuevo Usuario

1. En la página de login, haz clic en **"Regístrate"**
2. Completa el formulario:
   - **Nombre:** Tu nombre completo
   - **Email:** tu@email.com
   - **Contraseña:** (mínimo 6 caracteres)
   - **Rol:** Selecciona admin, vendedor o marketing
3. Haz clic en **"Registrarse"**
4. Serás redirigido al login automáticamente
5. Inicia sesión con tus credenciales

---

## 📦 Gestión de Productos (CRUD)

### Acceder a la Sección de Ventas

1. Desde el dashboard, haz clic en **"Ventas"** en el menú lateral
2. Verás la tabla de productos actual

### ➕ Crear un Producto

1. Haz clic en el botón **"Nuevo Producto"**
2. Completa el formulario:
   - **Nombre:** Nombre del producto (ej: "Laptop Dell")
   - **Descripción:** Descripción detallada
   - **Precio:** Precio en números (ej: 1299.99)
   - **Categoría:** Electrónica, Ropa, Alimentos, Libros, Otros
   - **Stock:** Cantidad disponible (número entero)
3. Haz clic en **"Guardar"**
4. El producto se guardará automáticamente en el **Shard correcto**:
   - **Shard A** (db1:27017): Productos con nombres A-M
   - **Shard B** (db2:27017): Productos con nombres N-Z

### ✏️ Editar un Producto

1. En la tabla de productos, haz clic en el botón **"Editar"** (icono de lápiz)
2. Modifica los campos que necesites
3. Haz clic en **"Guardar Cambios"**
4. **Nota:** Si cambias el nombre del producto y la primera letra cruza el límite A-M/N-Z, el producto se moverá automáticamente al shard correspondiente

### 🗑️ Eliminar un Producto

1. En la tabla de productos, haz clic en el botón **"Eliminar"** (icono de basura)
2. Confirma la eliminación
3. El producto se eliminará del shard correspondiente

### 🔍 Visualizar Productos

La tabla muestra:
- **Nombre del producto**
- **Descripción**
- **Precio** (formato moneda)
- **Categoría**
- **Stock disponible**
- **Badge del Shard** (Shard A o Shard B)
- **Acciones** (Ver, Editar, Eliminar)

---

## 🔧 Gestión de Servicios

### Ver Logs en Tiempo Real

```bash
# Logs del servidor web (dashboard)
incus exec web -- journalctl -u web-dashboard -f

# Logs del servidor de autenticación
incus exec auth -- journalctl -u auth-service -f

# Logs de MongoDB en db1 (puerto 27017)
incus exec db1 -- journalctl -u mongod-27017 -f
```

### Reiniciar Servicios

```bash
# Reiniciar servidor web
incus exec web -- systemctl restart web-dashboard

# Reiniciar servidor de autenticación
incus exec auth -- systemctl restart auth-service

# Reiniciar MongoDB en db1
incus exec db1 -- systemctl restart mongod-27017
```

### Detener/Iniciar Servicios

```bash
# Detener servidor web
incus exec web -- systemctl stop web-dashboard

# Iniciar servidor web
incus exec web -- systemctl start web-dashboard

# Estado del servicio
incus exec web -- systemctl status web-dashboard
```

---

## 🧪 Pruebas del Sistema

### Prueba 1: Verificar Fragmentación (Sharding)

**Crear productos en ambos shards:**

1. Crea un producto con nombre que empiece con **A-M** (ej: "Laptop")
2. Crea un producto con nombre que empiece con **N-Z** (ej: "Notebook")
3. Observa los badges:
   - "Laptop" debe mostrar **"Shard A"**
   - "Notebook" debe mostrar **"Shard B"**

**Verificar en MongoDB:**

```bash
# Ver productos en Shard A (db1:27017)
incus exec db1 -- mongosh --port 27017 --eval "use products_db; db.products.find().pretty()"

# Ver productos en Shard B (db2:27017)
incus exec db2 -- mongosh --port 27017 --eval "use products_db; db.products.find().pretty()"
```

### Prueba 2: Verificar Replicación

**Paso 1: Insertar un producto**
1. Crea un producto llamado "Apple iPhone" (irá al Shard A)

**Paso 2: Verificar en el SECUNDARIO**
```bash
# Conectar al secundario de rs_products_a (db2:27018)
incus exec db2 -- mongosh --port 27018 --eval "rs.secondaryOk(); use products_db; db.products.find({nombre: 'Apple iPhone'}).pretty()"
```

Deberías ver el mismo producto replicado.

### Prueba 3: Failover Automático

**Simular caída del nodo PRIMARY:**

```bash
# 1. Detener el contenedor db1 (PRIMARY de Shard A)
incus stop db1

# 2. Esperar 10-15 segundos para que ocurra la elección

# 3. Verificar que db2:27018 se promocionó a PRIMARY
incus exec db2 -- mongosh --port 27018 --eval "rs.status()" | grep -A 5 "stateStr"
```

**Intentar crear productos durante la caída:**
1. Ve al dashboard web
2. Intenta crear un producto en Shard A (nombre A-M)
3. El producto debería crearse exitosamente en el nuevo PRIMARY

**Restaurar el sistema:**
```bash
# Reiniciar db1
incus start db1

# Esperar unos segundos y verificar que se reincorpora como SECONDARY
incus exec db1 -- mongosh --port 27017 --eval "rs.status()" | grep -A 5 "stateStr"
```

### Prueba 4: Autenticación JWT

**Probar registro:**
```bash
curl -X POST http://10.122.112.106:3001/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Test User",
    "email": "test@example.com",
    "password": "test123",
    "rol": "vendedor"
  }'
```

**Probar login:**
```bash
curl -X POST http://10.122.112.106:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123"
  }'
```

Deberías recibir un **token JWT** en la respuesta.

**Verificar token:**
```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." # Usar el token recibido

curl -X POST http://10.122.112.106:3001/auth/verify \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}"
```

---

## 🗄️ Acceso Directo a MongoDB

### Conectar a Replica Sets

```bash
# Shard A - rs_products_a (PRIMARY en db1:27017)
incus exec db1 -- mongosh --port 27017

# Shard B - rs_products_b (PRIMARY en db2:27017)
incus exec db2 -- mongosh --port 27017

# Usuarios - rs_users (PRIMARY en db3:27017)
incus exec db3 -- mongosh --port 27017
```

### Comandos Útiles de MongoDB

```javascript
// Ver estado del replica set
rs.status()

// Ver configuración del replica set
rs.conf()

// Ver bases de datos
show dbs

// Usar base de datos
use products_db

// Ver colecciones
show collections

// Listar todos los productos
db.products.find().pretty()

// Contar productos
db.products.count()

// Buscar productos por nombre
db.products.find({nombre: /laptop/i}).pretty()

// Ver usuarios
use auth_db
db.users.find().pretty()
```

---

## 🏗️ Arquitectura del Sistema

### Contenedores e IPs

| Contenedor | IP               | Puertos      | Función                          |
|------------|------------------|--------------|----------------------------------|
| web        | 10.122.112.159   | 3000         | Dashboard web + CRUD             |
| auth       | 10.122.112.106   | 3001         | Autenticación JWT                |
| db1        | 10.122.112.153   | 27017-27019  | MongoDB (3 instancias)           |
| db2        | 10.122.112.233   | 27017-27018  | MongoDB (2 instancias)           |
| db3        | 10.122.112.16    | 27017-27019  | MongoDB (3 instancias)           |
| incus-ui   | 10.122.112.195   | 8443         | Interfaz de gestión Incus        |

### Replica Sets

#### Shard A (rs_products_a) - Productos A-M
- **PRIMARY:** db1:27017
- **SECONDARY:** db2:27018
- **ARBITER:** db3:27018

#### Shard B (rs_products_b) - Productos N-Z
- **PRIMARY:** db2:27017
- **SECONDARY:** db1:27018
- **ARBITER:** db3:27019

#### Usuarios (rs_users)
- **PRIMARY:** db3:27017
- **SECONDARY:** db1:27019

---

## 📊 Secciones del Dashboard

### 🏠 Dashboard Principal
- Vista general del sistema
- Estadísticas generales
- Acceso rápido a todas las secciones

### 💰 Ventas
- **Función:** Gestión completa de productos (CRUD)
- **Características:**
  - Tabla de productos con filtrado
  - Crear, editar, eliminar productos
  - Visualización del shard donde está cada producto
  - Indicadores de stock y precio

### 👔 Administración
- **Función:** Panel administrativo
- **Características:**
  - Gestión de usuarios (futuro)
  - Configuración del sistema
  - Reportes administrativos

### 📢 Marketing
- **Función:** Campañas y promociones
- **Características:**
  - Crear campañas de marketing
  - Análisis de productos más vendidos
  - Estrategias de promoción

### 📈 Estadísticas
- **Función:** Métricas e indicadores
- **Características:**
  - Total de productos por categoría
  - Valor total del inventario
  - Productos con bajo stock
  - Gráficos y visualizaciones

---

## 🔒 Seguridad

### JWT Tokens
- **Duración:** 8 horas
- **Almacenamiento:** Cookie httpOnly (segura contra XSS)
- **Verificación:** Middleware en todas las rutas protegidas

### Contraseñas
- **Hashing:** bcrypt con 10 rondas de salt
- **Almacenamiento:** Solo hash en base de datos, nunca texto plano

### MongoDB
- **Autenticación:** Habilitada en todos los replica sets
- **Write Concern:** w=majority (garantiza replicación)
- **Network:** Solo accesible dentro de la red Incus

---

## 🛠️ Solución de Problemas

### El dashboard no carga (Error 502/503)

```bash
# Verificar que el servicio web está activo
incus exec web -- systemctl status web-dashboard

# Si está inactivo, iniciarlo
incus exec web -- systemctl start web-dashboard

# Ver logs para identificar el error
incus exec web -- journalctl -u web-dashboard -n 50
```

### Error al crear productos

```bash
# Verificar que MongoDB está corriendo
incus exec db1 -- systemctl status mongod-27017
incus exec db2 -- systemctl status mongod-27017

# Verificar conectividad desde el contenedor web
incus exec web -- nc -zv 10.122.112.153 27017
incus exec web -- nc -zv 10.122.112.233 27017
```

### El login no funciona

```bash
# Verificar servicio de autenticación
incus exec auth -- systemctl status auth-service

# Ver logs del servicio
incus exec auth -- journalctl -u auth-service -n 50

# Verificar que MongoDB de usuarios está activo
incus exec db3 -- systemctl status mongod-27017
```

### Replica set no sincroniza

```bash
# Verificar estado del replica set
incus exec db1 -- mongosh --port 27017 --eval "rs.status()"

# Ver lag de replicación
incus exec db1 -- mongosh --port 27017 --eval "rs.printSecondaryReplicationInfo()"

# Forzar resincronización (CUIDADO: solo si es necesario)
incus exec db2 -- mongosh --port 27018 --eval "rs.syncFrom('10.122.112.153:27017')"
```

---

## 📞 Información de Contacto y Soporte

### Archivos de Configuración

```bash
# Servidor web
incus exec web -- cat /opt/web-app/.env

# Servidor de autenticación
incus exec auth -- cat /opt/auth-service/.env

# MongoDB config
incus exec db1 -- cat /etc/mongod-27017.conf
```

### Logs del Sistema

```bash
# Ver todos los logs del contenedor web
incus exec web -- journalctl -xe

# Ver logs del sistema Incus
sudo journalctl -u incus
```

### Documentación Adicional

- **Arquitectura detallada:** Ver archivo `ARQUITECTURA.md`
- **Scripts de instalación:** Directorio `scripts/`

---

## 🎓 Requisitos del Proyecto Cumplidos

✅ **6 contenedores Incus** interconectados  
✅ **Dashboard web** con múltiples secciones (Ventas, Admin, Marketing, Estadísticas)  
✅ **CRUD de productos** en sección "Ventas"  
✅ **Fragmentación de base de datos** (horizontal por nombre A-M / N-Z)  
✅ **Replicación** implementada en ambos fragmentos  
✅ **Servidor de autenticación** separado (login/registro JWT)  
✅ **Base de datos de usuarios** independiente (rs_users)  
✅ **Interfaz gráfica** para gestión de contenedores (Incus UI)  
✅ **Arquitectura documentada** y justificada  

---

## 🎉 ¡Sistema Listo para Usar!

Tu sistema distribuido está **100% funcional**. Accede a http://10.122.112.159:3000 y comienza a trabajar.

**¡Éxito con tu proyecto académico! 🚀**