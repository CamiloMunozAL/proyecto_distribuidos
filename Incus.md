# Ver todos los contenedores
incus list

# Ver información detallada de un contenedor
incus info web

# Ver recursos (CPU, RAM) en tiempo real
incus top

# Acceder a un contenedor
incus exec web -- bash

# Iniciar/Detener/Reiniciar contenedores
incus stop web
incus start web
incus restart web

# Ver logs de un contenedor
incus console web --show-log

# Ver estadísticas de uso
incus info web --resources