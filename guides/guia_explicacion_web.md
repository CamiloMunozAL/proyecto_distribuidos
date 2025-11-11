# 🌐 Guía de Explicación del Aplicativo Web (Contenedor `web`)

> 🎯 Objetivo: Explicar al profesor cómo está construida y organizada la aplicación web, cómo se conecta con los demás contenedores y cómo mostrar su funcionamiento en vivo.

---

## 🧭 1️⃣ Ubicación de la Aplicación

Dentro del contenedor `web`:
```bash
incus exec web -- bash
cd /opt/web-app
ls
```
Deberías ver:
```
config/  middleware/  node_modules/  public/  routes/  views/
server.js  package.json  .env
```

Cada carpeta cumple una función específica dentro del servidor web distribuido.

---

## 🧩 2️⃣ Estructura del Proyecto

| Carpeta / Archivo | Función | Qué mostrar |
|-------------------|----------|--------------|
| **server.js** | Punto de entrada del servidor Express. | `cat server.js` |
| **routes/** | Define las rutas (URLs y controladores). | `ls routes/` |
| **middleware/** | Middleware de autenticación JWT. | `cat middleware/auth.js` |
| **config/** | Lógica de conexión a MongoDB y shards. | `cat config/mongodb.js` |
| **views/** | Plantillas EJS (HTML dinámico). | `ls views/` |
| **public/** | Archivos estáticos (CSS, JS del navegador). | `ls public/` |
| **.env** | Variables de entorno (conexión y URLs). | `cat .env` (sin mostrar secretos en público) |

---

## ⚙️ 3️⃣ Funcionamiento Interno

### 🧩 a. `server.js` – Punto de entrada
```bash
cat server.js | head -n 20
```
> “Aquí inicia Express, se cargan las rutas y el middleware. Usa dotenv para leer las IPs y URIs de conexión a las bases de datos y al servidor `auth`.”

---

### 🧩 b. `routes/auth.js`
```bash
cat routes/auth.js | head -n 20
```
> “Contiene las rutas de autenticación. El contenedor `web` envía las peticiones a `auth` (10.122.112.106:3001), que valida usuarios y genera tokens JWT.”

---

### 🧩 c. `routes/productos.js`
```bash
cat routes/productos.js | head -n 20
```
> “Define las rutas CRUD de productos. Usa la función `getShardForProduct()` para decidir si el producto se guarda en el shard A (db1) o shard B (db2).”

---

### 🧩 d. `config/mongodb.js`
```bash
cat config/mongodb.js | head -n 20
```
> “Maneja la conexión a los replica sets rs_products_a y rs_products_b según las URIs definidas en el .env. Implementa el sharding manual por nombre.”

---

### 🧩 e. `middleware/auth.js`
Instala nano si no está disponible:
```bash
apt update && apt install nano -y
nano middleware/auth.js
```
> “Verifica si el usuario tiene un token JWT válido antes de acceder al dashboard. Si no, redirige al login.”

---

### 🧩 f. `views/` y `public/`
```bash
ls views/
```
Ejemplo de salida:
```
dashboard.ejs  login.ejs  register.ejs  ventas.ejs  admin.ejs
```
> “Son plantillas EJS que Express renderiza para mostrar la interfaz web. En `public/js/productos.js` hay funciones que manejan el CRUD desde el navegador.”

---

## 🔗 4️⃣ Conexiones entre Contenedores

| Contenedor | Protocolo | Propósito |
|-------------|------------|------------|
| **auth (10.122.112.106:3001)** | HTTP | Login / registro / verificación JWT |
| **db1 (10.122.112.153)** | MongoDB | Shard A (productos A–M) |
| **db2 (10.122.112.233)** | MongoDB | Shard B (productos N–Z) |
| **db3 (10.122.112.16)** | MongoDB | Árbitros + base de usuarios |

> “El contenedor `web` actúa como cerebro de la aplicación: recibe las peticiones del usuario, las valida con `auth` y las distribuye al shard correcto según el producto.”

---

## 🚀 5️⃣ Demostración en Vivo

1. Abre el navegador y entra a:
   ```
   http://10.122.112.159:3000
   ```
2. Inicia sesión con:
   ```
   admin@example.com / admin123
   ```
3. Crea un producto **Manzana** → se guarda en **Shard A (db1)**.  
4. Crea un producto **Zanahoria** → se guarda en **Shard B (db2)**.  
5. Verifica en consola que ambos productos existen en sus respectivos shards.

---

## 🧹 6️⃣ Limpieza (opcional)

Para reiniciar el CRUD y dejarlo limpio:
```bash
incus exec db1 -- mongosh --port 27017 --eval 'use products_db; db.products.deleteMany({})'
incus exec db2 -- mongosh --port 27017 --eval 'use products_db; db.products.deleteMany({})'
```

---

## ✅ 7️⃣ Conclusión para explicar al profesor

> “La aplicación `web` está hecha con Node.js + Express + EJS.  
> Se comunica con el contenedor `auth` por HTTP y con `db1` y `db2` por MongoDB.  
> Implementa un sistema de sharding manual por nombre de producto, usa JWT para autenticación, y todas las vistas se generan desde el servidor.”

---

📘 **Fin de la Guía de Explicación del Aplicativo Web**
