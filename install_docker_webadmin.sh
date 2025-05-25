#!/bin/bash

# Script para instalar Docker y Portainer con limpieza previa completa
# Compatible con Linux Mint 21.3 (Virginia) y Ubuntu 22.04+

# Verificar root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse con sudo o como root"
    exit 1
fi

# Configuración
PORTAINER_PORT=9443  # Puerto HTTPS recomendado
PORTAINER_DATA="/opt/portainer_data"
DOCKER_USER=$SUDO_USER

## 1. Limpieza completa de instalaciones previas ##
echo "=== Realizando limpieza completa de Docker previo ==="

# Detener y eliminar todos los contenedores Docker
if [ -x "$(command -v docker)" ]; then
    echo "Eliminando contenedores Docker..."
    docker stop $(docker ps -aq) 2>/dev/null || echo "No hay contenedores para detener"
    docker rm $(docker ps -aq) 2>/dev/null || echo "No hay contenedores para eliminar"
    
    # Eliminar todas las imágenes, redes y volúmenes
    echo "Eliminando imágenes, redes y volúmenes..."
    docker rmi $(docker images -q) 2>/dev/null || echo "No hay imágenes para eliminar"
    docker network prune -f
    docker volume prune -f
fi

# Desinstalar paquetes Docker antiguos
echo "Desinstalando paquetes Docker..."
apt-get remove -y --purge docker docker-engine docker.io containerd runc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

# Eliminar configuraciones y datos residuales
echo "Eliminando archivos residuales..."
rm -rf /var/lib/docker
rm -rf /var/lib/containerd
rm -rf /etc/docker
rm -rf /var/run/docker.sock
rm -rf /etc/apt/keyrings/docker.gpg
rm -rf /etc/apt/sources.list.d/docker.list
rm -rf /opt/portainer_data

# Eliminar Portainer si existe
if docker inspect portainer &>/dev/null; then
    echo "Eliminando Portainer existente..."
    docker stop portainer 2>/dev/null
    docker rm portainer 2>/dev/null
    docker rmi portainer/portainer-ce 2>/dev/null
fi

## 2. Instalación limpia de Docker ##
echo -e "\n=== Instalando Docker ==="

# Actualizar sistema
apt-get update
apt-get upgrade -y

# Instalar dependencias
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    uidmap

# Agregar clave GPG oficial de Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Configurar repositorio (usamos jammy para Linux Mint 21.3)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configurar Docker para rootless (opcional)
# dockerd-rootless-setuptool.sh install

# Agregar usuario al grupo docker
if ! grep -q docker /etc/group; then
    groupadd docker
fi
usermod -aG docker $DOCKER_USER

# Configurar Docker para iniciar con el sistema
systemctl enable docker
systemctl start docker

## 3. Instalar Portainer (Interfaz Web) con HTTPS ##
echo -e "\n=== Instalando Portainer con HTTPS ==="

# Crear directorio para datos persistentes
mkdir -p $PORTAINER_DATA

# Descargar e instalar Portainer CE con HTTPS
docker run -d \
    -p $PORTAINER_PORT:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $PORTAINER_DATA:/data \
    portainer/portainer-ce:latest \
    --sslcert /data/certs/portainer.crt \
    --sslkey /data/certs/portainer.key

# Esperar a que Portainer inicie
echo "Esperando a que Portainer inicie (30 segundos)..."
sleep 30

## 4. Configuración final ##
echo -e "\n=== Configuración final ==="

# Obtener IP del servidor
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Configurar firewall
if command -v ufw &>/dev/null; then
    ufw allow $PORTAINER_PORT/tcp
    ufw reload
fi

# Mostrar información de acceso
echo -e "\n\033[1;32m=== Instalación completada con éxito! ===\033[0m"
echo -e "\nDocker Version: $(docker --version)"
echo -e "Docker Compose Version: $(docker compose version)"
echo -e "\nAccede a Portainer (HTTPS):"
echo -e "\033[1;34mhttps://$IP_ADDRESS:$PORTAINER_PORT\033[0m"
echo -e "\nLa primera vez necesitarás:"
echo "1. Crear un usuario admin"
echo "2. Seleccionar 'Local' para administrar este servidor Docker"

echo -e "\n\033[1;33mRecomendaciones:\033[0m"
echo "- Reinicia tu sesión para que los cambios de grupo docker surtan efecto"
echo "- Para producción, configura certificados SSL válidos en $PORTAINER_DATA/certs/"
echo "- Considera usar: sudo usermod -aG docker tu_usuario"

exit 0
