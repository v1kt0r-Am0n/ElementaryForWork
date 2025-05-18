#!/bin/bash

# Script para organizar archivos en carpetas por tipo
# Uso: ./organizar_archivos.sh [carpeta_origen] [carpeta_destino]

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar parámetros
if [ "$#" -ne 2 ]; then
    echo -e "${RED}Error: Se requieren dos parámetros.${NC}"
    echo -e "Uso: $0 <carpeta_origen> <carpeta_destino>"
    exit 1
fi

ORIGEN="$1"
DESTINO="$2"

# Verificar existencia de carpetas
if [ ! -d "$ORIGEN" ]; then
    echo -e "${RED}Error: La carpeta origen '$ORIGEN' no existe.${NC}"
    exit 1
fi

if [ ! -d "$DESTINO" ]; then
    echo -e "${YELLOW}La carpeta destino no existe. Creando '$DESTINO'...${NC}"
    mkdir -p "$DESTINO" || { echo -e "${RED}Error al crear carpeta destino.${NC}"; exit 1; }
fi

# Crear subcarpetas si no existen
declare -a CARPETAS=("Documentos" "Fotos" "Videos" "Ejecutables" "Otros")

for carpeta in "${CARPETAS[@]}"; do
    if [ ! -d "$DESTINO/$carpeta" ]; then
        mkdir -p "$DESTINO/$carpeta"
    fi
done

# Contadores
total=0
documentos=0
fotos=0
videos=0
ejecutables=0
otros=0

# Funciones para identificar tipos de archivo
es_documento() {
    case "${1,,}" in
        *.pdf|*.doc|*.docx|*.xls|*.xlsx|*.txt|*.odt|*.ods|*.ppt|*.pptx) return 0 ;;
        *) return 1 ;;
    esac
}

es_foto() {
    case "${1,,}" in
        *.jpg|*.jpeg|*.png|*.gif|*.bmp|*.tiff|*.webp) return 0 ;;
        *) return 1 ;;
    esac
}

es_video() {
    case "${1,,}" in
        *.mp4|*.avi|*.mov|*.mkv|*.flv|*.wmv|*.webm) return 0 ;;
        *) return 1 ;;
    esac
}

es_ejecutable() {
    if [[ -x "$1" ]] || [[ "${1,,}" == *.sh ]] || [[ "${1,,}" == *.run ]] || [[ "${1,,}" == *.bin ]]; then
        return 0
    else
        return 1
    fi
}

# Procesar archivos
echo -e "${GREEN}Organizando archivos...${NC}"

while IFS= read -r -d '' archivo; do
    if [ -f "$archivo" ]; then
        nombre_archivo=$(basename "$archivo")
        ((total++))
        
        if es_documento "$nombre_archivo"; then
            cp "$archivo" "$DESTINO/Documentos/"
            ((documentos++))
        elif es_foto "$nombre_archivo"; then
            cp "$archivo" "$DESTINO/Fotos/"
            ((fotos++))
        elif es_video "$nombre_archivo"; then
            cp "$archivo" "$DESTINO/Videos/"
            ((videos++))
        elif es_ejecutable "$archivo"; then
            cp "$archivo" "$DESTINO/Ejecutables/"
            ((ejecutables++))
        else
            cp "$archivo" "$DESTINO/Otros/"
            ((otros++))
        fi
    fi
done < <(find "$ORIGEN" -type f -print0)

# Mostrar resumen
echo -e "\n${GREEN}Organización completada!${NC}"
echo -e "Total de archivos procesados: $total"
echo -e "Documentos: $documentos (PDF, DOC, XLS, TXT, etc.)"
echo -e "Fotos: $fotos (JPG, PNG, GIF, etc.)"
echo -e "Videos: $videos (MP4, AVI, MOV, etc.)"
echo -e "Ejecutables: $ejecutables (SH, BIN, ejecutables, etc.)"
echo -e "Otros archivos: $otros"

exit 0
