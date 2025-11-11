#!/bin/bash
# ========================================
# Script 00 - Configuración inicial de Incus
# ========================================

set -e

echo "==> Creando red incusbr0 si no existe..."
if ! incus network list | grep -q incusbr0; then
  incus network create incusbr0 ipv4.address=10.66.66.1/24 ipv4.nat=true ipv6.address=none
fi

echo "==> Creando perfil dist-net..."
incus profile create dist-net || true
incus profile device add dist-net eth0 nic network=incusbr0 name=eth0 || true
incus profile set dist-net limits.cpu=2
incus profile set dist-net limits.memory=2GiB

echo "==> Perfil y red listos."
