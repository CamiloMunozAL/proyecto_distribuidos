#!/bin/bash
# ========================================
# Script Maestro - Instalación Completa del Sistema Distribuido
# ========================================
# Ejecuta todos los scripts de instalación en el orden correcto.
# Este script automatiza el despliegue completo del sistema.
# ========================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar mensajes
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Función para ejecutar script con manejo de errores
run_script() {
    local script=$1
    local description=$2
    
    echo ""
    echo "========================================="
    log_info "Ejecutando: $description"
    echo "========================================="
    
    if [ ! -f "$script" ]; then
        log_error "Script no encontrado: $script"
        exit 1
    fi
    
    chmod +x "$script"
    
    if bash "$script"; then
        log_success "$description completado"
    else
        log_error "$description falló"
        exit 1
    fi
}

# Banner inicial
clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║   INSTALACIÓN COMPLETA DEL SISTEMA DISTRIBUIDO             ║"
echo "║   Sistema de Gestión de Productos con MongoDB             ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log_info "Iniciando instalación automatizada..."
log_warning "Este proceso tomará aproximadamente 10-15 minutos"
echo ""
read -p "¿Desea continuar? (s/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    log_info "Instalación cancelada por el usuario"
    exit 0
fi

# Obtener directorio de scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paso 1: Configurar Incus
run_script "$SCRIPT_DIR/00_setup_incus.sh" "Configuración de red Incus"

# Paso 2: Crear contenedores
run_script "$SCRIPT_DIR/01_create_containers.sh" "Creación de contenedores"

# Paso 3: Instalar MongoDB
run_script "$SCRIPT_DIR/02_install_mongodb.sh" "Instalación de MongoDB 8.0"

# Paso 4: Configurar servicios MongoDB
run_script "$SCRIPT_DIR/03_configure_replicas.sh" "Configuración de servicios MongoDB"

# Paso 5: Corregir permisos (si es necesario)
log_info "Verificando permisos..."
run_script "$SCRIPT_DIR/03.1_config.sh" "Corrección de permisos"

# Paso 6: Inicializar replica sets
run_script "$SCRIPT_DIR/04_init_replicasets.sh" "Inicialización de Replica Sets"

# Paso 7: Agregar árbitros
run_script "$SCRIPT_DIR/03.2_add_arbiters_and_secondary.sh" "Configuración de alta disponibilidad"

# Paso 8: Crear usuarios de base de datos
run_script "$SCRIPT_DIR/05_create_db_users.sh" "Creación de usuarios MongoDB"

# Paso 9: Insertar datos de prueba
run_script "$SCRIPT_DIR/06_seed_data.sh" "Inserción de datos de prueba"

# Paso 10: Instalar servicio de autenticación
if [ -f "$SCRIPT_DIR/09_setup_auth_service.sh" ]; then
    run_script "$SCRIPT_DIR/09_setup_auth_service.sh" "Instalación del servicio de autenticación"
else
    log_warning "Script 09_setup_auth_service.sh no encontrado, omitiendo..."
fi

# Paso 11: Instalar dashboard web
if [ -f "$SCRIPT_DIR/10_setup_web_dashboard.sh" ]; then
    run_script "$SCRIPT_DIR/10_setup_web_dashboard.sh" "Instalación del dashboard web"
else
    log_warning "Script 10_setup_web_dashboard.sh no encontrado, omitiendo..."
fi

if [ -f "$SCRIPT_DIR/10.1_views_and_server.sh" ]; then
    run_script "$SCRIPT_DIR/10.1_views_and_server.sh" "Configuración de vistas y servidor"
else
    log_warning "Script 10.1_views_and_server.sh no encontrado, omitiendo..."
fi

# Paso 12: Instalar Incus UI (opcional)
if [ -f "$SCRIPT_DIR/07_install_incus_ui.sh" ]; then
    echo ""
    log_info "¿Desea instalar Incus UI? (s/n)"
    read -p "Respuesta: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        run_script "$SCRIPT_DIR/07_install_incus_ui.sh" "Instalación de Incus UI"
    else
        log_info "Incus UI omitido"
    fi
fi

# Resumen final
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║   ✅ INSTALACIÓN COMPLETADA EXITOSAMENTE                   ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log_success "Sistema distribuido instalado correctamente"
echo ""
echo "📊 INFORMACIÓN DEL SISTEMA:"
echo "───────────────────────────────────────────────────────────"
incus list

echo ""
echo "🔗 ACCESO AL SISTEMA:"
echo "───────────────────────────────────────────────────────────"

# Obtener IPs de los contenedores
WEB_IP=$(incus list web -c 4 -f csv | cut -d' ' -f1)
AUTH_IP=$(incus list auth -c 4 -f csv | cut -d' ' -f1)

if [ -n "$WEB_IP" ]; then
    echo "   🌐 Dashboard Web: http://$WEB_IP:3000"
else
    echo "   🌐 Dashboard Web: http://10.122.112.159:3000"
fi

if [ -n "$AUTH_IP" ]; then
    echo "   🔐 Servicio Auth:  http://$AUTH_IP:3001"
else
    echo "   🔐 Servicio Auth:  http://10.122.112.106:3001"
fi

echo ""
echo "👤 CREDENCIALES:"
echo "───────────────────────────────────────────────────────────"
echo "   Email:    admin@test.com"
echo "   Password: admin123"
echo ""
echo "📚 PRÓXIMOS PASOS:"
echo "───────────────────────────────────────────────────────────"
echo "   1. Acceder al dashboard web en tu navegador"
echo "   2. Iniciar sesión con las credenciales proporcionadas"
echo "   3. Crear productos y verificar el sharding"
echo "   4. Consultar la documentación en:"
echo "      • README.md - Guía general"
echo "      • uso.md - Guía de uso detallada"
echo "      • pruebas.md - Guía de validación"
echo ""
log_info "Sistema listo para usar"
echo ""
