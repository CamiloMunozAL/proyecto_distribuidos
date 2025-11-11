#!/bin/bash
# ========================================
# Script 10 - Instalación del Servidor Web con Dashboard
# ========================================
# Crea una aplicación web completa con:
# - Dashboard con secciones (Ventas, Admin, Marketing, Estadísticas)
# - CRUD de productos
# - Integración con servidor de autenticación (JWT)
# - Conexión directa a MongoDB shards (rs_products_a y rs_products_b)
# ========================================

set -e

echo "==> Instalando Node.js 20 LTS en contenedor web ..."
incus exec web -- bash -lc '
# Instalar dependencias
apt-get update
apt-get install -y curl ca-certificates gnupg

# Instalar Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Verificar versiones
node --version
npm --version
'

echo ""
echo "==> Creando estructura de la aplicación web ..."
incus exec web -- bash -lc '
# Crear directorios
mkdir -p /opt/web-app/{routes,middleware,config,public/{css,js},views}
cd /opt/web-app

# Crear package.json
cat >package.json <<EOF
{
  "name": "web-dashboard",
  "version": "1.0.0",
  "description": "Dashboard de gestión con CRUD de productos",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongodb": "^6.3.0",
    "ejs": "^3.1.9",
    "axios": "^1.6.2",
    "jsonwebtoken": "^9.0.2",
    "dotenv": "^16.3.1",
    "body-parser": "^1.20.2",
    "cookie-parser": "^1.4.6"
  }
}
EOF

# Instalar dependencias
npm install --quiet --no-progress
echo "✅ Dependencias instaladas"
'

echo ""
echo "==> Creando archivo de configuración (.env) ..."
incus exec web -- bash -lc '
cd /opt/web-app

cat >.env <<EOF
# Configuración del servidor
PORT=3000
NODE_ENV=production

# MongoDB Shards (conexión directa)
MONGO_SHARD_A=mongodb://db1:27017,db2:27018/products_db?replicaSet=rs_products_a
MONGO_SHARD_B=mongodb://db2:27017,db1:27018/products_db?replicaSet=rs_products_b

# Servidor de autenticación
AUTH_SERVICE_URL=http://10.122.112.106:3001

# JWT Secret (debe coincidir con auth service)
JWT_SECRET=mi-secreto-super-seguro-cambiar-en-produccion-2025
EOF

echo "✅ .env creado"
'

echo ""
echo "==> Creando configuración de MongoDB (config/mongodb.js) ..."
incus exec web -- bash <<'SCRIPT_END'
cd /opt/web-app

cat > config/mongodb.js << 'EOF'
const { MongoClient } = require('mongodb');

// Clientes para cada shard
const clientShardA = new MongoClient(process.env.MONGO_SHARD_A);
const clientShardB = new MongoClient(process.env.MONGO_SHARD_B);

let dbShardA, dbShardB;
let productsCollectionA, productsCollectionB;

async function connectDB() {
  try {
    // Conectar a shard A (productos A-M)
    await clientShardA.connect();
    dbShardA = clientShardA.db('products_db');
    productsCollectionA = dbShardA.collection('products');
    await productsCollectionA.createIndex({ name: 1 });
    console.log('✅ Conectado a Shard A (rs_products_a) - Productos A-M');

    // Conectar a shard B (productos N-Z)
    await clientShardB.connect();
    dbShardB = clientShardB.db('products_db');
    productsCollectionB = dbShardB.collection('products');
    await productsCollectionB.createIndex({ name: 1 });
    console.log('✅ Conectado a Shard B (rs_products_b) - Productos N-Z');

  } catch (error) {
    console.error('❌ Error conectando a MongoDB:', error);
    process.exit(1);
  }
}

// Determinar a qué shard pertenece un producto según su nombre
function getShardForProduct(productName) {
  const firstLetter = productName.charAt(0).toUpperCase();
  return (firstLetter >= 'A' && firstLetter <= 'M') ? 'A' : 'B';
}

// Obtener la colección correcta según el shard
function getCollection(shard) {
  return shard === 'A' ? productsCollectionA : productsCollectionB;
}

// Buscar todos los productos (consulta ambos shards)
async function findAllProducts(filter = {}) {
  const [productsA, productsB] = await Promise.all([
    productsCollectionA.find(filter).toArray(),
    productsCollectionB.find(filter).toArray()
  ]);
  return [...productsA, ...productsB];
}

// Buscar un producto por ID (intenta en ambos shards)
async function findProductById(id) {
  const { ObjectId } = require('mongodb');
  const objectId = new ObjectId(id);
  
  let product = await productsCollectionA.findOne({ _id: objectId });
  if (!product) {
    product = await productsCollectionB.findOne({ _id: objectId });
  }
  return product;
}

// Insertar producto en el shard correcto
async function insertProduct(productData) {
  const shard = getShardForProduct(productData.name);
  const collection = getCollection(shard);
  const result = await collection.insertOne(productData);
  console.log(`✅ Producto "${productData.name}" insertado en Shard ${shard}`);
  return result;
}

// Actualizar producto (busca en ambos shards)
async function updateProduct(id, updateData) {
  const { ObjectId } = require('mongodb');
  const objectId = new ObjectId(id);
  
  // Si cambia el nombre, verificar si debe moverse de shard
  if (updateData.name) {
    const product = await findProductById(id);
    if (product) {
      const currentShard = getShardForProduct(product.name);
      const newShard = getShardForProduct(updateData.name);
      
      if (currentShard !== newShard) {
        // Mover entre shards: eliminar del antiguo e insertar en el nuevo
        const currentCollection = getCollection(currentShard);
        await currentCollection.deleteOne({ _id: objectId });
        
        const newCollection = getCollection(newShard);
        const newProduct = { ...product, ...updateData };
        delete newProduct._id;
        const result = await newCollection.insertOne(newProduct);
        console.log(`🔄 Producto movido de Shard ${currentShard} a Shard ${newShard}`);
        return result;
      }
    }
  }
  
  // Actualización normal
  let result = await productsCollectionA.updateOne(
    { _id: objectId },
    { $set: updateData }
  );
  
  if (result.matchedCount === 0) {
    result = await productsCollectionB.updateOne(
      { _id: objectId },
      { $set: updateData }
    );
  }
  
  return result;
}

// Eliminar producto (busca en ambos shards)
async function deleteProduct(id) {
  const { ObjectId } = require('mongodb');
  const objectId = new ObjectId(id);
  
  let result = await productsCollectionA.deleteOne({ _id: objectId });
  if (result.deletedCount === 0) {
    result = await productsCollectionB.deleteOne({ _id: objectId });
  }
  
  return result;
}

module.exports = {
  connectDB,
  findAllProducts,
  findProductById,
  insertProduct,
  updateProduct,
  deleteProduct,
  getShardForProduct
};
EOF

echo "✅ config/mongodb.js creado"
SCRIPT_END

echo ""
echo "==> Creando middleware de autenticación (middleware/auth.js) ..."
incus exec web -- bash <<'SCRIPT_END'
cd /opt/web-app

cat > middleware/auth.js << 'EOF'
const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET;

// Middleware para verificar JWT en cookies o headers
function requireAuth(req, res, next) {
  try {
    // Buscar token en cookie o header Authorization
    const token = req.cookies.token || 
                  (req.headers.authorization && req.headers.authorization.split(' ')[1]);
    
    if (!token) {
      return res.status(401).render('login', { 
        error: 'Debes iniciar sesión para acceder' 
      });
    }

    // Verificar token
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();

  } catch (error) {
    console.error('Error de autenticación:', error.message);
    res.clearCookie('token');
    return res.status(401).render('login', { 
      error: 'Sesión inválida o expirada. Inicia sesión nuevamente.' 
    });
  }
}

// Middleware para verificar roles
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'No autenticado' });
    }
    
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Acceso denegado' });
    }
    
    next();
  };
}

module.exports = { requireAuth, requireRole };
EOF

echo "✅ middleware/auth.js creado"
SCRIPT_END

echo ""
echo "==> Creando rutas de autenticación (routes/auth.js) ..."
incus exec web -- bash <<'SCRIPT_END'
cd /opt/web-app

cat > routes/auth.js << 'EOF'
const express = require('express');
const axios = require('axios');
const router = express.Router();

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL;

// GET /login - Mostrar formulario de login
router.get('/login', (req, res) => {
  res.render('login', { error: null });
});

// POST /login - Procesar login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // Llamar al servicio de autenticación
    const response = await axios.post(`${AUTH_SERVICE_URL}/auth/login`, {
      email,
      password
    });

    const { token, user } = response.data;

    // Guardar token en cookie (httpOnly para seguridad)
    res.cookie('token', token, {
      httpOnly: true,
      maxAge: 8 * 60 * 60 * 1000 // 8 horas
    });

    console.log(`✅ Login exitoso: ${user.email}`);
    res.redirect('/dashboard');

  } catch (error) {
    console.error('Error en login:', error.response?.data || error.message);
    res.render('login', { 
      error: 'Credenciales inválidas. Intenta nuevamente.' 
    });
  }
});

// GET /register - Mostrar formulario de registro
router.get('/register', (req, res) => {
  res.render('register', { error: null, success: null });
});

// POST /register - Procesar registro
router.post('/register', async (req, res) => {
  try {
    const { username, email, password, role } = req.body;

    // Llamar al servicio de autenticación
    await axios.post(`${AUTH_SERVICE_URL}/auth/register`, {
      username,
      email,
      password,
      role: role || 'vendedor'
    });

    console.log(`✅ Usuario registrado: ${email}`);
    res.render('register', { 
      error: null, 
      success: 'Usuario registrado exitosamente. Ya puedes iniciar sesión.' 
    });

  } catch (error) {
    console.error('Error en registro:', error.response?.data || error.message);
    res.render('register', { 
      error: error.response?.data?.error || 'Error al registrar usuario',
      success: null 
    });
  }
});

// GET /logout - Cerrar sesión
router.get('/logout', (req, res) => {
  res.clearCookie('token');
  res.redirect('/login');
});

module.exports = router;
EOF

echo "✅ routes/auth.js creado"
SCRIPT_END

echo ""
echo "==> Creando rutas de productos (routes/productos.js) ..."
incus exec web -- bash <<'SCRIPT_END'
cd /opt/web-app

cat > routes/productos.js << 'EOFPRODUCTS'
const express = require('express');
const router = express.Router();
const db = require('../config/mongodb');

// GET /productos - Listar todos los productos (JSON API)
router.get('/api', async (req, res) => {
  try {
    const products = await db.findAllProducts();
    res.json(products);
  } catch (error) {
    console.error('Error al obtener productos:', error);
    res.status(500).json({ error: 'Error al obtener productos' });
  }
});

// GET /productos/:id - Obtener producto por ID (JSON API)
router.get('/api/:id', async (req, res) => {
  try {
    const product = await db.findProductById(req.params.id);
    if (!product) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    res.json(product);
  } catch (error) {
    console.error('Error al obtener producto:', error);
    res.status(500).json({ error: 'Error al obtener producto' });
  }
});

// POST /productos - Crear nuevo producto
router.post('/api', async (req, res) => {
  try {
    const { name, description, price, category, stock, sku } = req.body;

    if (!name || !price) {
      return res.status(400).json({ error: 'Nombre y precio son requeridos' });
    }

    const newProduct = {
      name,
      description: description || '',
      price: parseFloat(price),
      category: category || 'General',
      stock: parseInt(stock) || 0,
      sku: sku || `SKU-${Date.now()}`,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.insertProduct(newProduct);
    const shard = db.getShardForProduct(name);

    res.status(201).json({
      message: 'Producto creado exitosamente',
      productId: result.insertedId,
      shard,
      product: { ...newProduct, _id: result.insertedId }
    });

  } catch (error) {
    console.error('Error al crear producto:', error);
    res.status(500).json({ error: 'Error al crear producto' });
  }
});

// PUT /productos/:id - Actualizar producto
router.put('/api/:id', async (req, res) => {
  try {
    const { name, description, price, category, stock, sku } = req.body;

    const updateData = {
      updatedAt: new Date()
    };

    if (name) updateData.name = name;
    if (description !== undefined) updateData.description = description;
    if (price) updateData.price = parseFloat(price);
    if (category) updateData.category = category;
    if (stock !== undefined) updateData.stock = parseInt(stock);
    if (sku) updateData.sku = sku;

    const result = await db.updateProduct(req.params.id, updateData);

    if (result.modifiedCount === 0 && result.matchedCount === 0) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }

    res.json({ message: 'Producto actualizado exitosamente' });

  } catch (error) {
    console.error('Error al actualizar producto:', error);
    res.status(500).json({ error: 'Error al actualizar producto' });
  }
});

// DELETE /productos/:id - Eliminar producto
router.delete('/api/:id', async (req, res) => {
  try {
    const result = await db.deleteProduct(req.params.id);

    if (result.deletedCount === 0) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }

    res.json({ message: 'Producto eliminado exitosamente' });

  } catch (error) {
    console.error('Error al eliminar producto:', error);
    res.status(500).json({ error: 'Error al eliminar producto' });
  }
});

module.exports = router;
EOFPRODUCTS

echo "✅ routes/productos.js creado"
SCRIPT_END

echo ""
echo "==> Creando rutas del dashboard (routes/dashboard.js) ..."
incus exec web -- bash <<'SCRIPT_END'
cd /opt/web-app

cat > routes/dashboard.js << 'EOFDASH'
const express = require('express');
const router = express.Router();
const db = require('../config/mongodb');

// GET /dashboard - Página principal
router.get('/', async (req, res) => {
  try {
    const products = await db.findAllProducts();
    res.render('dashboard', {
      user: req.user,
      totalProducts: products.length,
      products: products.slice(0, 5) // Últimos 5 productos
    });
  } catch (error) {
    console.error('Error:', error);
    res.render('dashboard', { user: req.user, totalProducts: 0, products: [] });
  }
});

// GET /ventas - Sección de ventas (CRUD productos)
router.get('/ventas', async (req, res) => {
  try {
    const products = await db.findAllProducts();
    res.render('ventas', { user: req.user, products });
  } catch (error) {
    console.error('Error:', error);
    res.render('ventas', { user: req.user, products: [] });
  }
});

// GET /admin - Sección administración
router.get('/admin', (req, res) => {
  res.render('admin', { user: req.user });
});

// GET /marketing - Sección marketing
router.get('/marketing', (req, res) => {
  res.render('marketing', { user: req.user });
});

// GET /estadisticas - Sección estadísticas
router.get('/estadisticas', async (req, res) => {
  try {
    const products = await db.findAllProducts();
    const stats = {
      total: products.length,
      categories: [...new Set(products.map(p => p.category))].length,
      totalValue: products.reduce((sum, p) => sum + (p.price * p.stock), 0),
      lowStock: products.filter(p => p.stock < 10).length
    };
    res.render('estadisticas', { user: req.user, stats, products });
  } catch (error) {
    console.error('Error:', error);
    res.render('estadisticas', { user: req.user, stats: {}, products: [] });
  }
});

module.exports = router;
EOFDASH

echo "✅ routes/dashboard.js creado"
SCRIPT_END

echo ""
echo "==> Creando CSS principal (public/css/styles.css) ..."
incus exec web -- bash <<'SCRIPT_END'
cd /opt/web-app

cat > public/css/styles.css << 'EOFCSS'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

/* Login/Register */
.auth-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
}

.auth-card {
  background: white;
  padding: 40px;
  border-radius: 10px;
  box-shadow: 0 10px 40px rgba(0,0,0,0.2);
  width: 100%;
  max-width: 400px;
}

.auth-card h1 {
  text-align: center;
  color: #333;
  margin-bottom: 30px;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  color: #555;
  font-weight: 500;
}

.form-group input,
.form-group select,
.form-group textarea {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 5px;
  font-size: 14px;
}

.btn {
  width: 100%;
  padding: 12px;
  border: none;
  border-radius: 5px;
  font-size: 16px;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-primary {
  background: #667eea;
  color: white;
}

.btn-primary:hover {
  background: #5568d3;
}

.btn-success {
  background: #48bb78;
  color: white;
}

.btn-danger {
  background: #f56565;
  color: white;
}

.alert {
  padding: 15px;
  border-radius: 5px;
  margin-bottom: 20px;
}

.alert-error {
  background: #fed7d7;
  color: #c53030;
  border: 1px solid #fc8181;
}

.alert-success {
  background: #c6f6d5;
  color: #22543d;
  border: 1px solid #68d391;
}

/* Dashboard */
.dashboard {
  background: white;
  border-radius: 10px;
  padding: 30px;
  margin-top: 20px;
}

.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  padding-bottom: 20px;
  border-bottom: 2px solid #e2e8f0;
}

.dashboard-header h1 {
  color: #2d3748;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 15px;
}

.user-info span {
  color: #4a5568;
  font-weight: 500;
}

.btn-logout {
  background: #e53e3e;
  color: white;
  padding: 8px 20px;
  text-decoration: none;
  border-radius: 5px;
}

.nav-menu {
  display: flex;
  gap: 10px;
  margin-bottom: 30px;
}

.nav-menu a {
  padding: 10px 20px;
  background: #edf2f7;
  color: #2d3748;
  text-decoration: none;
  border-radius: 5px;
  transition: all 0.3s;
}

.nav-menu a:hover,
.nav-menu a.active {
  background: #667eea;
  color: white;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.stat-card {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 20px;
  border-radius: 10px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}

.stat-card h3 {
  font-size: 14px;
  opacity: 0.9;
  margin-bottom: 10px;
}

.stat-card .value {
  font-size: 32px;
  font-weight: bold;
}

/* Tabla de productos */
.products-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 20px;
}

.products-table th,
.products-table td {
  padding: 12px;
  text-align: left;
  border-bottom: 1px solid #e2e8f0;
}

.products-table th {
  background: #f7fafc;
  color: #2d3748;
  font-weight: 600;
}

.products-table tr:hover {
  background: #f7fafc;
}

.badge {
  display: inline-block;
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;
}

.badge-shard-a {
  background: #bee3f8;
  color: #2c5282;
}

.badge-shard-b {
  background: #fbd38d;
  color: #744210;
}

.actions {
  display: flex;
  gap: 10px;
}

.btn-sm {
  padding: 5px 15px;
  font-size: 14px;
  border-radius: 4px;
  border: none;
  cursor: pointer;
}

.modal {
  display: none;
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0,0,0,0.5);
  z-index: 1000;
}

.modal.active {
  display: flex;
  justify-content: center;
  align-items: center;
}

.modal-content {
  background: white;
  padding: 30px;
  border-radius: 10px;
  max-width: 500px;
  width: 90%;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.close-modal {
  font-size: 24px;
  cursor: pointer;
  color: #718096;
}
EOFCSS

echo "✅ public/css/styles.css creado"
SCRIPT_END

echo ""
echo "==> Creando vistas EJS..."
echo "    Creando layout base..."
