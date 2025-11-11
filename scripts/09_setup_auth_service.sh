#!/bin/bash
# ========================================
# Script 09 - Instalación del Servidor de Autenticación
# ========================================
# Crea un API REST en el contenedor 'auth' con:
# - POST /auth/register (registro de usuarios)
# - POST /auth/login (login con JWT)
# - Conexión a MongoDB rs_users (db3)
# ========================================

set -e

echo "==> Instalando Node.js 20 LTS en contenedor auth ..."
incus exec auth -- bash -lc '
# Instalar Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git
node --version
npm --version
'

echo ""
echo "==> Creando aplicación de autenticación ..."
incus exec auth -- bash -lc '
# Crear directorio de la aplicación
mkdir -p /opt/auth-service
cd /opt/auth-service

# Crear package.json
cat >package.json <<EOF
{
  "name": "auth-service",
  "version": "1.0.0",
  "description": "Servicio de autenticación JWT con MongoDB",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "keywords": ["auth", "jwt", "mongodb"],
  "author": "",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2",
    "mongodb": "^6.3.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  }
}
EOF

# Instalar dependencias
npm install

echo "✅ Dependencias instaladas"
'

echo ""
echo "==> Creando archivo de configuración (.env) ..."
incus exec auth -- bash -lc '
cd /opt/auth-service

cat >.env <<EOF
# Configuración del servidor
PORT=3001
NODE_ENV=production

# MongoDB
MONGO_URI=mongodb://db3:27017,db1:27019/users_db?replicaSet=rs_users&readPreference=primaryPreferred

# JWT Secret (CAMBIAR EN PRODUCCIÓN)
JWT_SECRET=mi-secreto-super-seguro-cambiar-en-produccion-2025
JWT_EXPIRATION=8h
EOF

echo "✅ Archivo .env creado"
'

echo ""
echo "==> Creando servidor de autenticación (server.js) ..."
incus exec auth -- bash -lc '
cd /opt/auth-service

cat >server.js <<'\''EOF'\''
require('\''dotenv'\'').config();
const express = require('\''express'\'');
const { MongoClient, ServerApiVersion } = require('\''mongodb'\'');
const bcrypt = require('\''bcryptjs'\'');
const jwt = require('\''jsonwebtoken'\'');
const cors = require('\''cors'\'');

const app = express();
const PORT = process.env.PORT || 3001;
const MONGO_URI = process.env.MONGO_URI;
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRATION = process.env.JWT_EXPIRATION || '\''8h'\'';

// Middlewares
app.use(express.json());
app.use(cors());

// Cliente MongoDB
const client = new MongoClient(MONGO_URI, {
  serverApi: {
    version: ServerApiVersion.v1,
    strict: true,
    deprecationErrors: true,
  }
});

let usersCollection;

// Conectar a MongoDB
async function connectDB() {
  try {
    await client.connect();
    const db = client.db('\''users_db'\'');
    usersCollection = db.collection('\''users'\'');
    
    // Crear índice único en email
    await usersCollection.createIndex({ email: 1 }, { unique: true });
    
    console.log('\''✅ Conectado a MongoDB rs_users'\'');
  } catch (error) {
    console.error('\''❌ Error conectando a MongoDB:'\'', error);
    process.exit(1);
  }
}

// ============================================
// Rutas de Autenticación
// ============================================

// Ruta raíz (health check)
app.get('\''/'\'', (req, res) => {
  res.json({
    service: '\''Auth Service'\'',
    version: '\''1.0.0'\'',
    status: '\''running'\'',
    endpoints: {
      register: '\''POST /auth/register'\'',
      login: '\''POST /auth/login'\'',
      verify: '\''POST /auth/verify'\''
    }
  });
});

// POST /auth/register - Registro de usuarios
app.post('\''/auth/register'\'', async (req, res) => {
  try {
    const { username, email, password, role } = req.body;

    // Validaciones
    if (!username || !email || !password) {
      return res.status(400).json({
        error: '\''Faltan campos requeridos'\'',
        required: ['\''username'\'', '\''email'\'', '\''password'\'']
      });
    }

    if (password.length < 4) {
      return res.status(400).json({
        error: '\''La contraseña debe tener al menos 4 caracteres'\''
      });
    }

    // Verificar si el email ya existe
    const existingUser = await usersCollection.findOne({ email });
    if (existingUser) {
      return res.status(409).json({
        error: '\''El email ya está registrado'\''
      });
    }

    // Hash de la contraseña
    const passwordHash = await bcrypt.hash(password, 10);

    // Crear usuario
    const newUser = {
      username,
      email: email.toLowerCase(),
      passwordHash,
      role: role || '\''vendedor'\'',
      createdAt: new Date(),
      lastLogin: null
    };

    const result = await usersCollection.insertOne(newUser);

    res.status(201).json({
      message: '\''Usuario registrado exitosamente'\'',
      userId: result.insertedId,
      username: newUser.username,
      email: newUser.email,
      role: newUser.role
    });

    console.log(`✅ Usuario registrado: ${email}`);

  } catch (error) {
    console.error('\''Error en registro:'\'', error);
    res.status(500).json({
      error: '\''Error interno del servidor'\'',
      details: error.message
    });
  }
});

// POST /auth/login - Inicio de sesión
app.post('\''/auth/login'\'', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validaciones
    if (!email || !password) {
      return res.status(400).json({
        error: '\''Email y contraseña son requeridos'\''
      });
    }

    // Buscar usuario
    const user = await usersCollection.findOne({ email: email.toLowerCase() });
    if (!user) {
      return res.status(401).json({
        error: '\''Credenciales inválidas'\''
      });
    }

    // Verificar contraseña
    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      return res.status(401).json({
        error: '\''Credenciales inválidas'\''
      });
    }

    // Actualizar último login
    await usersCollection.updateOne(
      { _id: user._id },
      { $set: { lastLogin: new Date() } }
    );

    // Generar token JWT
    const token = jwt.sign(
      {
        id: user._id.toString(),
        username: user.username,
        email: user.email,
        role: user.role
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRATION }
    );

    res.json({
      message: '\''Login exitoso'\'',
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });

    console.log(`✅ Login exitoso: ${email}`);

  } catch (error) {
    console.error('\''Error en login:'\'', error);
    res.status(500).json({
      error: '\''Error interno del servidor'\'',
      details: error.message
    });
  }
});

// POST /auth/verify - Verificar token JWT
app.post('\''/auth/verify'\'', (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('\''Bearer '\'')) {
      return res.status(401).json({
        error: '\''Token no proporcionado'\'',
        valid: false
      });
    }

    const token = authHeader.substring(7);

    const decoded = jwt.verify(token, JWT_SECRET);
    
    res.json({
      message: '\''Token válido'\'',
      valid: true,
      user: {
        id: decoded.id,
        username: decoded.username,
        email: decoded.email,
        role: decoded.role
      }
    });

  } catch (error) {
    if (error.name === '\''TokenExpiredError'\'') {
      return res.status(401).json({
        error: '\''Token expirado'\'',
        valid: false
      });
    }
    
    res.status(401).json({
      error: '\''Token inválido'\'',
      valid: false
    });
  }
});

// Middleware de manejo de errores
app.use((err, req, res, next) => {
  console.error('\''Error no manejado:'\'', err);
  res.status(500).json({
    error: '\''Error interno del servidor'\''
  });
});

// Iniciar servidor
async function start() {
  await connectDB();
  
  app.listen(PORT, '\''0.0.0.0'\'', () => {
    console.log(`
╔═══════════════════════════════════════════════╗
║   🔐 Auth Service Running                     ║
╚═══════════════════════════════════════════════╝

📡 Puerto: ${PORT}
🔗 MongoDB: rs_users (db3:27017, db1:27019)
🔑 JWT Expiration: ${JWT_EXPIRATION}

Endpoints disponibles:
  GET  / ..................... Health check
  POST /auth/register ........ Registro de usuarios
  POST /auth/login ........... Inicio de sesión
  POST /auth/verify .......... Verificar token JWT

✅ Servicio listo para recibir peticiones
    `);
  });
}

start();
EOF

echo "✅ server.js creado"
'

echo ""
echo "==> Creando servicio systemd ..."
incus exec auth -- bash -lc '
cat >/etc/systemd/system/auth-service.service <<EOF
[Unit]
Description=Auth Service (JWT + MongoDB)
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/auth-service
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=auth-service

Environment="NODE_ENV=production"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable auth-service
'

echo ""
echo "==> Iniciando servicio de autenticación ..."
incus exec auth -- systemctl start auth-service

echo ""
echo "==> Esperando 3 segundos a que arranque ..."
sleep 3

echo ""
echo "==> Verificando estado del servicio ..."
incus exec auth -- systemctl status auth-service --no-pager | head -20

echo ""
echo "==> Verificando logs ..."
incus exec auth -- journalctl -u auth-service -n 20 --no-pager

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║           ✅ SERVIDOR DE AUTENTICACIÓN INSTALADO                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📡 Servicio: auth-service"
echo "🔗 URL: http://10.122.112.106:3001"
echo "📦 Ubicación: /opt/auth-service (contenedor auth)"
echo ""
echo "🔧 Endpoints disponibles:"
echo "   • GET  /                    → Health check"
echo "   • POST /auth/register       → Registro de usuarios"
echo "   • POST /auth/login          → Login (devuelve JWT)"
echo "   • POST /auth/verify         → Verificar token JWT"
echo ""
echo "🧪 Prueba rápida:"
echo "   # Health check"
echo "   curl http://10.122.112.106:3001/"
echo ""
echo "   # Registrar usuario"
echo "   curl -X POST http://10.122.112.106:3001/auth/register \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"username\":\"admin\",\"email\":\"admin@example.com\",\"password\":\"admin123\",\"role\":\"admin\"}'"
echo ""
echo "   # Login"
echo "   curl -X POST http://10.122.112.106:3001/auth/login \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"email\":\"admin@example.com\",\"password\":\"admin123\"}'"
echo ""
echo "📋 Gestión del servicio:"
echo "   incus exec auth -- systemctl status auth-service"
echo "   incus exec auth -- systemctl restart auth-service"
echo "   incus exec auth -- journalctl -u auth-service -f"
echo ""
