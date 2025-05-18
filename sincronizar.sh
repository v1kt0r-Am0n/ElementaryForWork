#!/bin/bash

# Script para sincronizar dos carpetas (origen -> destino) con progreso y tiempo estimado
# Uso: ./sincronizar.sh <origen> <destino> [opciones]

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para mostrar una barra de progreso animada
show_progress() {
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] Sincronizando..." "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r\033[K"
    done
}

# Función para calcular el tiempo transcurrido
format_time() {
    local seconds=$1
    local hours=$((seconds/3600))
    local minutes=$(( (seconds%3600)/60 ))
    local seconds=$((seconds%60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Verificar que se hayan proporcionado los argumentos necesarios
if [ "$#" -lt 2 ]; then
    echo -e "${RED}Error: Faltan argumentos.${NC}"
    echo -e "Uso: $0 <carpeta_origen> <carpeta_destino> [opciones]"
    echo -e "Opciones disponibles:"
    echo -e "  --dry-run    : Simular sincronización sin hacer cambios"
    echo -e "  --delete     : Eliminar archivos en destino que no existen en origen"
    echo -e "  --verbose    : Mostrar detalles de la sincronización"
    echo -e "  --progress   : Mostrar barra de progreso gráfica"
    exit 1
fi

ORIGEN=$(realpath "$1")
DESTINO=$(realpath "$2")
shift 2 # Eliminar los primeros dos argumentos para procesar opciones

# Variables para opciones
DRY_RUN=0
DELETE=0
VERBOSE=0
SHOW_PROGRESS=0

# Procesar opciones
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=1 ;;
        --delete) DELETE=1 ;;
        --verbose) VERBOSE=1 ;;
        --progress) SHOW_PROGRESS=1 ;;
        *) echo -e "${RED}Opción desconocida: $1${NC}"; exit 1 ;;
    esac
    shift
done

# Verificar que rsync esté instalado
if ! command -v rsync &> /dev/null; then
    echo -e "${RED}Error: rsync no está instalado.${NC}"
    echo -e "Instálelo con: sudo apt install rsync (Debian/Ubuntu) o sudo yum install rsync (CentOS/RHEL)"
    exit 1
fi

# Verificar que las carpetas existan
if [ ! -d "$ORIGEN" ]; then
    echo -e "${RED}Error: La carpeta origen '$ORIGEN' no existe.${NC}"
    exit 1
fi

if [ ! -d "$DESTINO" ]; then
    echo -e "${YELLOW}Advertencia: La carpeta destino '$DESTINO' no existe. Creándola...${NC}"
    mkdir -p "$DESTINO"
fi

# Construir comando rsync
RSYNC_CMD="rsync -avz"

# Añadir opciones según parámetros
if [ $DRY_RUN -eq 1 ]; then
    RSYNC_CMD="$RSYNC_CMD --dry-run"
    echo -e "${YELLOW}Modo simulación activado. No se realizarán cambios reales.${NC}"
fi

if [ $DELETE -eq 1 ]; then
    RSYNC_CMD="$RSYNC_CMD --delete"
    echo -e "${YELLOW}Advertencia: Se eliminarán archivos en destino que no existan en origen.${NC}"
fi

if [ $VERBOSE -eq 1 ]; then
    RSYNC_CMD="$RSYNC_CMD --progress --itemize-changes"
fi

if [ $SHOW_PROGRESS -eq 1 ]; then
    RSYNC_CMD="$RSYNC_CMD --info=progress2"
fi

# Mostrar resumen de la operación
echo -e "${GREEN}Preparando sincronización...${NC}"
echo -e "${CYAN}Origen:  $ORIGEN${NC}"
echo -e "${CYAN}Destino: $DESTINO${NC}"
echo -e "${BLUE}Tamaño origen: $(du -sh "$ORIGEN" | cut -f1)${NC}"
echo -e "${BLUE}Comando: $RSYNC_CMD $ORIGEN/ $DESTINO/${NC}"

# Calcular número aproximado de archivos (para estimación)
echo -e "${YELLOW}Calculando cantidad de archivos...${NC}"
TOTAL_FILES=$(find "$ORIGEN" -type f | wc -l)
echo -e "${GREEN}Archivos a sincronizar: $TOTAL_FILES${NC}"

# Iniciar temporizador
START_TIME=$(date +%s)

# Ejecutar rsync en segundo plano
echo -e "\n${GREEN}Iniciando sincronización...${NC}"
if [ $SHOW_PROGRESS -eq 1 ]; then
    $RSYNC_CMD "$ORIGEN"/ "$DESTINO"/ &
else
    $RSYNC_CMD "$ORIGEN"/ "$DESTINO"/ > /tmp/rsync_output.log 2>&1 &
fi

RSYNC_PID=$!

# Mostrar progreso
if [ $SHOW_PROGRESS -eq 0 ]; then
    show_progress $RSYNC_PID &
    PROGRESS_PID=$!
fi

# Esperar a que rsync termine
wait $RSYNC_PID
RSYNC_EXIT_STATUS=$?

# Detener la animación de progreso si estaba activa
if [ $SHOW_PROGRESS -eq 0 ]; then
    kill $PROGRESS_PID 2>/dev/null
    wait $PROGRESS_PID 2>/dev/null
fi

# Calcular tiempo transcurrido
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))

# Verificar resultado
if [ $RSYNC_EXIT_STATUS -eq 0 ]; then
    echo -e "\r${GREEN}Sincronización completada con éxito.${NC}"
    echo -e "${BLUE}Tiempo total: $(format_time $ELAPSED_TIME)${NC}"
    
    # Mostrar resumen de cambios si no está en modo verbose
    if [ $VERBOSE -eq 0 ] && [ $DRY_RUN -eq 0 ]; then
        echo -e "\n${CYAN}Resumen de cambios:${NC}"
        grep -E '^>f' /tmp/rsync_output.log | awk '{print $2}' | sort | uniq -c | \
        awk '{printf "  %-10s %s\n", $1 " " ($1==1?"archivo":"archivos"), $2}'
    fi
else
    echo -e "\r${RED}Error: Hubo un problema durante la sincronización.${NC}"
    echo -e "${YELLOW}Tiempo transcurrido: $(format_time $ELAPSED_TIME)${NC}"
    
    # Mostrar error detallado
    if [ $VERBOSE -eq 0 ]; then
        echo -e "\n${RED}Últimas líneas del log:${NC}"
        tail -n 5 /tmp/rsync_output.log
    fi
    exit 1
fi

# Limpiar archivo temporal
rm -f /tmp/rsync_output.log

# Mostrar espacio utilizado
echo -e "\n${CYAN}Espacio utilizado:${NC}"
echo -e "  Origen:  $(du -sh "$ORIGEN" | cut -f1)"
echo -e "  Destino: $(du -sh "$DESTINO" | cut -f1)"
