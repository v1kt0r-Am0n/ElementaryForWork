#!/bin/bash

# Script universal para instalar Docker y Kubernetes en Ubuntu (18.04, 20.04, 22.04, 23.04, 24.04)

# Verificar root
[ "$(id -u)" -ne 0 ] && echo "Ejecutar con sudo" && exit 1

# Obtener detalles del sistema
UBUNTU_CODENAME=$(lsb_release -cs)
UBUNTU_VERSION=$(lsb_release -rs)
ARCH=$(dpkg --print-architecture)

# Mapeo de versiones de Ubuntu a nombres de repositorio Docker
declare -A DOCKER_REPO_MAP=(
    ["18.04"]="bionic"
    ["20.04"]="focal"
    ["22.04"]="jammy"
    ["23.04"]="lunar"
    ["23.10"]="mantic"
    ["24.04"]="noble"
)

# Configuraciones
KUBE_VERSION="1.29"
DASHBOARD_VERSION="v2.7.0"

# Función para manejar errores
handle_error() {
    echo -e "\033[1;31mERROR: $1\033[0m"
    [ "$2" == "noexit" ] || exit 1
}

# Mostrar información del sistema
echo -e "\n\033[1;34m=== Sistema detectado ===\033[0m"
echo "Ubuntu Version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
echo "Arquitectura: $ARCH"

# Verificar compatibilidad
[ -z "${DOCKER_REPO_MAP[$UBUNTU_VERSION]}" ] && 
    handle_error "Versión de Ubuntu no soportada. Versiones compatibles: 18.04, 20.04, 22.04, 23.04, 24.04"

# Paso 1: Limpiar instalaciones previas
echo -e "\n\033[1;34m=== Limpiando instalaciones previas ===\033[0m"
apt-get remove -y docker docker-engine docker.io containerd runc kubelet kubeadm kubectl 2>/dev/null
rm -f /etc/apt/sources.list.d/{docker,kubernetes}.list
rm -rf /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Paso 2: Actualizar sistema
echo -e "\n\033[1;34m=== Actualizando sistema ===\033[0m"
apt-get update && apt-get upgrade -y

# Paso 3: Instalar dependencias
echo -e "\n\033[1;34m=== Instalando dependencias ===\033[0m"
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

# Paso 4: Instalar Docker
echo -e "\n\033[1;34m=== Instalando Docker ===\033[0m"
DOCKER_CODENAME="${DOCKER_REPO_MAP[$UBUNTU_VERSION]}"

# Configurar clave GPG
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || 
    handle_error "Falló al descargar clave GPG de Docker"

# Configurar repositorio
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $DOCKER_CODENAME stable" | 
    tee /etc/apt/sources.list.d/docker.list || handle_error "Falló al configurar repositorio Docker"

# Instalar Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || 
    handle_error "Falló al instalar Docker"

# Configurar Docker
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Habilitar e iniciar Docker
systemctl enable --now docker
getent group docker >/dev/null && usermod -aG docker $SUDO_USER || 
    echo "Advertencia: No se pudo agregar usuario al grupo docker"

# Paso 5: Instalar Kubernetes
echo -e "\n\033[1;34m=== Instalando Kubernetes ===\033[0m"

# Configurar clave GPG
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || 
    handle_error "Falló al descargar clave GPG de Kubernetes"

# Configurar repositorio
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" | 
    tee /etc/apt/sources.list.d/kubernetes.list || handle_error "Falló al configurar repositorio Kubernetes"

# Instalar componentes
apt-get update
apt-get install -y kubelet kubeadm kubectl || 
    handle_error "Falló al instalar Kubernetes"
apt-mark hold kubelet kubeadm kubectl

# Paso 6: Inicializar cluster
echo -e "\n\033[1;34m=== Inicializando cluster Kubernetes ===\033[0m"
kubeadm init --pod-network-cidr=10.244.0.0/16 || 
    handle_error "Falló al inicializar el cluster Kubernetes"

# Configurar kubectl para usuario normal
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config || 
    handle_error "Falló al copiar configuración de kubectl"
chown $(id -u):$(id -g) $HOME/.kube/config

# Instalar red Flannel
echo -e "\n\033[1;34m=== Instalando Flannel ===\033[0m"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml || 
    handle_error "Falló al instalar Flannel"

# Instalar Dashboard
echo -e "\n\033[1;34m=== Instalando Kubernetes Dashboard ===\033[0m"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml || 
    handle_error "Falló al instalar Kubernetes Dashboard"

# Crear usuario admin
echo -e "\n\033[1;34m=== Configurando acceso al Dashboard ===\033[0m"
cat <<EOF | kubectl apply -f - || handle_error "Falló al crear usuario admin"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

cat <<EOF | kubectl apply -f - || handle_error "Falló al configurar permisos"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Mostrar información de acceso
echo -e "\n\033[1;32m=== Instalación completada con éxito! ===\033[0m"
echo -e "\nPara acceder al Kubernetes Dashboard:"
echo "1. Ejecute en una terminal: \033[1mkubectl proxy\033[0m"
echo "2. Abra en su navegador:"
echo -e "\033[4mhttp://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/\033[0m"
echo -e "\n3. Use el siguiente token para autenticarse:\n"

# Generar token de acceso
kubectl -n kubernetes-dashboard create token admin-user --duration=8760h || 
    echo "Advertencia: No se pudo generar token. Ejecute manualmente:"
    echo "kubectl -n kubernetes-dashboard create token admin-user --duration=8760h"

echo -e "\n\033[1;33mReinicie su sesión para aplicar los cambios de grupo docker.\033[0m"
