#!/bin/bash
# ========================================
# Script 10.1 - Continuación: Vistas y servidor principal
# ========================================
# Este script complementa el 10_setup_web_dashboard.sh
# Crea las vistas EJS y el servidor principal
# ========================================

set -e

echo "==> Creando vistas EJS (templates HTML)..."

# Vista: login.ejs
incus exec web -- bash <<'SCRIPT_END'
cd /opt/web-app/views

cat > login.ejs << 'EOFLOGIN'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Login - Dashboard</title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
  <div class="auth-container">
    <div class="auth-card">
      <h1>🔐 Iniciar Sesión</h1>
      
      <% if (error) { %>
        <div class="alert alert-error"><%= error %></div>
      <% } %>

      <form method="POST" action="/login">
        <div class="form-group">
          <label for="email">Email:</label>
          <input type="email" id="email" name="email" required>
        </div>

        <div class="form-group">
          <label for="password">Contraseña:</label>
          <input type="password" id="password" name="password" required>
        </div>

        <button type="submit" class="btn btn-primary">Ingresar</button>
      </form>

      <p style="text-align: center; margin-top: 20px;">
        ¿No tienes cuenta? <a href="/register">Regístrate aquí</a>
      </p>
    </div>
  </div>
</body>
</html>
EOFLOGIN

cat > register.ejs << 'EOFREG'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Registro - Dashboard</title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
  <div class="auth-container">
    <div class="auth-card">
      <h1>📝 Registro</h1>
      
      <% if (error) { %>
        <div class="alert alert-error"><%= error %></div>
      <% } %>

      <% if (success) { %>
        <div class="alert alert-success"><%= success %></div>
      <% } %>

      <form method="POST" action="/register">
        <div class="form-group">
          <label for="username">Nombre de usuario:</label>
          <input type="text" id="username" name="username" required>
        </div>

        <div class="form-group">
          <label for="email">Email:</label>
          <input type="email" id="email" name="email" required>
        </div>

        <div class="form-group">
          <label for="password">Contraseña:</label>
          <input type="password" id="password" name="password" required minlength="4">
        </div>

        <div class="form-group">
          <label for="role">Rol:</label>
          <select id="role" name="role">
            <option value="vendedor">Vendedor</option>
            <option value="admin">Administrador</option>
            <option value="marketing">Marketing</option>
          </select>
        </div>

        <button type="submit" class="btn btn-primary">Registrarse</button>
      </form>

      <p style="text-align: center; margin-top: 20px;">
        ¿Ya tienes cuenta? <a href="/login">Inicia sesión aquí</a>
      </p>
    </div>
  </div>
</body>
</html>
EOFREG

cat > dashboard.ejs << 'EOFDASH'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Dashboard</title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
  <div class="container">
    <div class="dashboard">
      <div class="dashboard-header">
        <h1>📊 Dashboard Principal</h1>
        <div class="user-info">
          <span>👤 <%= user.username %> (<%= user.role %>)</span>
          <a href="/logout" class="btn-logout">Cerrar Sesión</a>
        </div>
      </div>

      <div class="nav-menu">
        <a href="/dashboard" class="active">Dashboard</a>
        <a href="/dashboard/ventas">Ventas</a>
        <a href="/dashboard/admin">Administración</a>
        <a href="/dashboard/marketing">Marketing</a>
        <a href="/dashboard/estadisticas">Estadísticas</a>
      </div>

      <div class="stats-grid">
        <div class="stat-card">
          <h3>Total Productos</h3>
          <div class="value"><%= totalProducts %></div>
        </div>
        <div class="stat-card">
          <h3>Usuario Activo</h3>
          <div class="value" style="font-size: 20px;"><%= user.username %></div>
        </div>
      </div>

      <h2>Productos Recientes</h2>
      <table class="products-table">
        <thead>
          <tr>
            <th>Nombre</th>
            <th>Precio</th>
            <th>Stock</th>
            <th>Categoría</th>
          </tr>
        </thead>
        <tbody>
          <% if (products.length > 0) { %>
            <% products.forEach(product => { %>
              <tr>
                <td><%= product.name %></td>
                <td>$<%= product.price.toFixed(2) %></td>
                <td><%= product.stock %></td>
                <td><%= product.category %></td>
              </tr>
            <% }) %>
          <% } else { %>
            <tr>
              <td colspan="4" style="text-align: center;">No hay productos</td>
            </tr>
          <% } %>
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>
EOFDASH

cat > ventas.ejs << 'EOFVENTAS'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Ventas - CRUD Productos</title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
  <div class="container">
    <div class="dashboard">
      <div class="dashboard-header">
        <h1>🛒 Gestión de Productos (Ventas)</h1>
        <div class="user-info">
          <span>👤 <%= user.username %></span>
          <a href="/logout" class="btn-logout">Cerrar Sesión</a>
        </div>
      </div>

      <div class="nav-menu">
        <a href="/dashboard">Dashboard</a>
        <a href="/dashboard/ventas" class="active">Ventas</a>
        <a href="/dashboard/admin">Administración</a>
        <a href="/dashboard/marketing">Marketing</a>
        <a href="/dashboard/estadisticas">Estadísticas</a>
      </div>

      <button class="btn btn-success" onclick="openModal('create')" style="margin-bottom: 20px;">
        ➕ Nuevo Producto
      </button>

      <table class="products-table" id="productsTable">
        <thead>
          <tr>
            <th>Nombre</th>
            <th>Descripción</th>
            <th>Precio</th>
            <th>Categoría</th>
            <th>Stock</th>
            <th>SKU</th>
            <th>Shard</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <% products.forEach(product => { 
            const firstLetter = product.name.charAt(0).toUpperCase();
            const shard = (firstLetter >= 'A' && firstLetter <= 'M') ? 'A' : 'B';
          %>
            <tr>
              <td><%= product.name %></td>
              <td><%= product.description %></td>
              <td>$<%= product.price.toFixed(2) %></td>
              <td><%= product.category %></td>
              <td><%= product.stock %></td>
              <td><%= product.sku %></td>
              <td><span class="badge badge-shard-<%= shard.toLowerCase() %>">Shard <%= shard %></span></td>
              <td class="actions">
                <button class="btn-sm btn-primary" onclick="editProduct('<%= product._id %>')">Editar</button>
                <button class="btn-sm btn-danger" onclick="deleteProduct('<%= product._id %>')">Eliminar</button>
              </td>
            </tr>
          <% }) %>
        </tbody>
      </table>
    </div>
  </div>

  <!-- Modal para crear/editar producto -->
  <div id="productModal" class="modal">
    <div class="modal-content">
      <div class="modal-header">
        <h2 id="modalTitle">Nuevo Producto</h2>
        <span class="close-modal" onclick="closeModal()">&times;</span>
      </div>
      <form id="productForm">
        <input type="hidden" id="productId">
        <div class="form-group">
          <label>Nombre:</label>
          <input type="text" id="name" required>
        </div>
        <div class="form-group">
          <label>Descripción:</label>
          <textarea id="description" rows="3"></textarea>
        </div>
        <div class="form-group">
          <label>Precio:</label>
          <input type="number" id="price" step="0.01" required>
        </div>
        <div class="form-group">
          <label>Categoría:</label>
          <input type="text" id="category">
        </div>
        <div class="form-group">
          <label>Stock:</label>
          <input type="number" id="stock" value="0">
        </div>
        <div class="form-group">
          <label>SKU:</label>
          <input type="text" id="sku">
        </div>
        <button type="submit" class="btn btn-success">Guardar</button>
      </form>
    </div>
  </div>

  <script src="/js/productos.js"></script>
</body>
</html>
EOFVENTAS

echo "✅ Vistas principales creadas"
SCRIPT_END

# Continúa creando las vistas restantes...