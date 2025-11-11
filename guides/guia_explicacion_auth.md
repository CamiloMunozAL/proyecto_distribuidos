# 🔐 Guía de Explicación del Contenedor `auth`

> 🎯 Objetivo: Explicar el funcionamiento interno del servicio de autenticación JWT, su estructura, cómo se comunica con las bases de datos y con el contenedor `web`.

---

## 🧭 1️⃣ Ubicación de la Aplicación

Dentro del contenedor `auth`:
```bash
incus exec auth -- bash
cd /opt/auth-service
ls
```
Salida esperada:
```
node_modules/  package.json  package-lock.json  server.js
```

---

## 🧩 2️⃣ Estructura del Proyecto

| Archivo | Función | Qué mostrar |
|----------|----------|--------------|
| **server.js** | Contiene todo el código de la API REST. | `cat server.js | head -n 30` |
| **package.json** | Define dependencias y metadatos del proyecto. | `cat package.json` |
| **.env** | Variables de entorno (Mongo URI, JWT secret, puerto). | `cat .env` *(sin mostrar secretos)* |

---

## ⚙️ 3️⃣ Tecnologías Principales

| Tecnología | Uso |
|-------------|-----|
| **Node.js + Express** | Servidor API REST |
| **MongoDB (rs_users)** | Base de datos de usuarios con replicación |
| **bcryptjs** | Hasheo seguro de contraseñas |
| **jsonwebtoken (JWT)** | Generación y verificación de tokens |
| **dotenv** | Configuración de variables de entorno |
| **cors** | Permite peticiones entre contenedores |

---

## 🔗 4️⃣ Conexiones y Flujo de Comunicación

| Desde | Hacia | Protocolo | Propósito |
|--------|--------|-----------|-----------|
| **web** | **auth** | HTTP (puerto 3001) | Login, registro, verificación |
| **auth** | **db3 (rs_users)** | MongoDB (PRIMARY) | Guardar y leer usuarios |
| **auth** | **db1:27019 (rs_users)** | MongoDB (SECONDARY) | Failover automático |

📘 **Explicación:**  
> “El contenedor `auth` se comunica directamente con el replica set `rs_users`, el cual tiene dos nodos (`db3` y `db1`).  
> Si el PRIMARY cae, MongoDB elige automáticamente otro y el servicio sigue funcionando sin perder conexión.”

---

## 🧠 5️⃣ Lógica Interna (archivo `server.js`)

### 🧩 a. Conexión a MongoDB
```javascript
const client = new MongoClient(MONGO_URI);
await client.connect();
const db = client.db('users_db');
usersCollection = db.collection('users');
```
> “Aquí se conecta al replica set `rs_users` y crea un índice único en el campo `email`.”

---

### 🧩 b. Registro de usuarios
Ruta: `POST /auth/register`
```javascript
const passwordHash = await bcrypt.hash(password, 10);
await usersCollection.insertOne({ username, email, passwordHash });
```
> “No se guarda la contraseña, sino su hash, para mantener seguridad incluso si la base de datos se filtra.”

---

### 🧩 c. Inicio de sesión
Ruta: `POST /auth/login`
```javascript
const token = jwt.sign(
  { id: user._id, username: user.username, email: user.email, role: user.role },
  JWT_SECRET,
  { expiresIn: '8h' }
);
```
> “JWT (JSON Web Token) permite autenticación sin mantener sesiones.  
> El token incluye la identidad y rol del usuario, y expira automáticamente.”

---

### 🧩 d. Verificación del token
Ruta: `POST /auth/verify`
```javascript
const authHeader = req.headers.authorization;
const token = authHeader.substring(7);
const decoded = jwt.verify(token, JWT_SECRET);
```
> “Aquí se comprueba si el token sigue siendo válido.  
> Si está expirado o manipulado, se devuelve error 401 (no autorizado).”

---

### 🧩 e. Health Check
Ruta: `GET /`
```bash
curl http://10.122.112.106:3001/
```
Salida esperada:
```json
{
  "service": "Auth Service",
  "version": "1.0.0",
  "status": "running",
  "endpoints": {
    "register": "POST /auth/register",
    "login": "POST /auth/login",
    "verify": "POST /auth/verify"
  }
}
```

---

## 🔒 6️⃣ Variables de entorno (.env)

Ejemplo:
```
PORT=3001
MONGO_URI=mongodb://10.122.112.16:27017,10.122.112.153:27019/?replicaSet=rs_users
JWT_SECRET=supersecreto123
JWT_EXPIRATION=8h
```

> “Aquí se definen el puerto, la conexión a MongoDB y la clave secreta para los tokens JWT.”

---

## 🚀 7️⃣ Demostración en Vivo

### 🧩 Registrar un usuario
```bash
curl -X POST http://10.122.112.106:3001/auth/register   -H "Content-Type: application/json"   -d '{"username":"prueba","email":"test@example.com","password":"1234"}'
```

### 🧩 Iniciar sesión
```bash
curl -X POST http://10.122.112.106:3001/auth/login   -H "Content-Type: application/json"   -d '{"email":"test@example.com","password":"1234"}'
```

### 🧩 Verificar token
```bash
curl -X POST http://10.122.112.106:3001/auth/verify   -H "Authorization: Bearer <TOKEN>"
```

✅ Respuesta esperada:
```json
{
  "message": "Token válido",
  "valid": true,
  "user": { "email": "test@example.com" }
}
```

---

## 🧹 8️⃣ Limpieza (opcional)
Para eliminar usuarios de prueba:
```bash
incus exec db3 -- mongosh --port 27017 --eval 'use users_db; db.users.deleteMany({email:/@example.com$/})'
```

---

## ✅ 9️⃣ Conclusión para la exposición

> “El contenedor `auth` es una API REST hecha con Node.js y Express.  
> Se comunica con `rs_users` (replica set entre db3 y db1).  
> Implementa registro, login y verificación mediante JWT, usando bcrypt para seguridad de contraseñas.  
> Si el PRIMARY de MongoDB cae, el servicio sigue activo gracias a la replicación.”

---

📘 **Fin de la Guía del Contenedor `auth`**
