#!/bin/bash

# Script de actualización y mantenimiento del sistema
# Versión mejorada con manejo de errores y registros

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para manejar errores
handle_error() {
    echo -e "${RED}[ERROR]${NC} Ocurrió un error en el paso anterior. Verifique el mensaje de error."
    echo -e "${YELLOW}Nota:${NC} El sistema no se reiniciará debido al error."
    exit 1
}

# Habilitar modo de seguimiento para depuración
set -e

echo -e "${GREEN}[INICIO]${NC} Comenzando el proceso de actualización del sistema..."

# Actualizar lista de paquetes
echo -e "${YELLOW}[PASO 1/4]${NC} Actualizando lista de paquetes..."
apt update || handle_error

# Actualizar paquetes instalados
echo -e "${YELLOW}[PASO 2/4]${NC} Actualizando paquetes instalados..."
apt upgrade -y || handle_error

# Eliminar paquetes no necesarios
echo -e "${YELLOW}[PASO 3/4]${NC} Eliminando paquetes no necesarios..."
apt autoremove -y || handle_error

# Limpiar cache de paquetes
echo -e "${YELLOW}[PASO 4/4]${NC} Limpiando cache de paquetes..."
apt autoclean || handle_error

echo -e "${GREEN}[ÉXITO]${NC} Todas las actualizaciones se completaron correctamente."

# Preguntar al usuario qué acción tomar
echo -e "\n${YELLOW}¿Qué acción desea realizar ahora?${NC}"
echo "1) Reiniciar el sistema (recomendado si hubo actualizaciones del kernel)"
echo "2) Apagar el sistema"
echo "3) No hacer nada y salir"
read -p "Ingrese su elección (1-3): " choice

case $choice in
    1)
        echo -e "${GREEN}[INFO]${NC} Reiniciando el sistema..."
        reboot
        ;;
    2)
        echo -e "${GREEN}[INFO]${NC} Apagando el sistema..."
        poweroff
        ;;
    *)
        echo -e "${YELLOW}[INFO]${NC} Saliendo sin realizar acciones adicionales."
        exit 0
        ;;
esac
