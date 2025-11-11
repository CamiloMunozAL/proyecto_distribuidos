#!/bin/bash
# ========================================
# Script 07 - Activación de Incus UI nativa
# ========================================

set -e

echo "==> Habilitando UI web nativa de Incus..."
incus config set core.https_address :8443

HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ Incus UI nativa habilitada"
echo "==> Accede desde tu navegador:"
echo "    https://${HOST_IP}:8443"
echo ""
echo "Nota: Acepta el certificado autofirmado en tu navegador."
echo "      Usa las credenciales de tu servidor Incus para login."
