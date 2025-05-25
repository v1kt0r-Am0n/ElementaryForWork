#!/bin/bash

# Script definitivo para instalar Docker y Kubernetes en Ubuntu 20.04/22.04

# Verificar root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecutar con sudo"
    exit 1
fi

# Obtener versión de Ubuntu
UBUNTU_CODENAME=$(lsb_release -cs)
UBUNTU_VERSION=$(lsb_release -rs)

# Configuraciones
KUBE_VERSION="1.29"
DASHBOARD_VERSION="v2.7.0"

# Función para manejar errores
handle_error() {
    echo "ERROR: $1"
    exit 1
}

# Paso 1: Limpiar instalaciones previas
echo "Limpiando instalaciones previas..."
apt-get remove -y docker docker-engine docker.io containerd runc kubelet kubeadm kubectl
rm -rf /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/kubernetes.list

# Paso 2: Actualizar sistema
echo "Actualizando sistema..."
apt-get update && apt-get upgrade -y

# Paso 3: Instalar dependencias
echo "Instalando dependencias..."
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

# Paso 4: Instalar Docker correctamente
echo "Instalando Docker..."

# Configurar clave GPG
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Configurar repositorio correcto según versión
if [[ "$UBUNTU_VERSION" == "20.04" ]]; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu focal stable" | tee /etc/apt/sources.list.d/docker.list
elif [[ "$UBUNTU_VERSION" == "22.04" ]]; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | tee /etc/apt/sources.list.d/docker.list
else
    handle_error "Versión de Ubuntu no soportada"
fi

# Instalar Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
usermod -aG docker $SUDO_USER || echo "Advertencia: No se pudo agregar usuario al grupo docker"

# Paso 5: Instalar Kubernetes
echo "Instalando Kubernetes..."

# Configurar clave GPG
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Configurar repositorio
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Instalar componentes
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Paso 6: Inicializar cluster
echo "Inicializando cluster Kubernetes..."
kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurar kubectl para usuario normal
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Instalar red Flannel
echo "Instalando Flannel..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Instalar Dashboard
echo "Instalando Kubernetes Dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml

# Crear usuario admin
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

cat <<EOF | kubectl apply -f -
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

# Mostrar token de acceso
echo "Token de acceso al Dashboard:"
kubectl -n kubernetes-dashboard create token admin-user --duration=8760h

echo "Instalación completada exitosamente!"
echo "Para acceder al Dashboard, ejecute: kubectl proxy"
echo "Luego visite: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
