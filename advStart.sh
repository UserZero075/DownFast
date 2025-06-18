#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Colores para mensajes
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
AZUL='\033[0;34m'
CIAN='\033[0;36m'
NC='\033[0m' # Sin Color

# Función para imprimir mensajes con formato
imprimir_mensaje() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# Función para comparar versiones
compare_version() {
    local ver1="$1"
    local ver2="$2"
    
    # Extraer números de versión
    ver1_clean=$(echo "$ver1" | sed 's/^index_\|\.js$//g')
    ver2_clean=$(echo "$ver2" | sed 's/^index_\|\.js$//g')
    
    # Comparar versiones usando sort -V
    if [ "$(printf '%s\n' "$ver1_clean" "$ver2_clean" | sort -V | tail -n1)" = "$ver1_clean" ]; then
        if [ "$ver1_clean" != "$ver2_clean" ]; then
            echo "1"  # ver1 > ver2
        else
            echo "0"  # ver1 = ver2
        fi
    else
        echo "-1" # ver1 < ver2
    fi
}

# Función para instalar wget
instalar_wget() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando wget..."
    if ! (apt update -y && apt install -y wget && apt upgrade -y); then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar wget. Intentando reparar..."
        apt --fix-broken install -y
        if ! (apt update -y && apt install -y wget && apt upgrade -y); then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar wget. Abortando."
            exit 1
        fi
    fi
    wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh && bash InstallTools.sh
}

# Función para instalar Node.js
instalar_nodejs() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando Node.js..."
    if ! pkg install nodejs-lts -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar Node.js. Intentando reparar..."
        termux-change-repo
        pkg repair
        if ! pkg reinstall coreutils liblz4; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo reparar. Abortando."
            exit 1
        fi
        if ! pkg install nodejs-lts -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar Node.js. Abortando."
            exit 1
        fi
    fi
}

# Función para leer teclas especiales
leer_tecla() {
    local key
    IFS= read -rsn1 key 2>/dev/null >&2
    if [[ $key = $'\x1b' ]]; then
        read -rsn2 key 2>/dev/null >&2
        case $key in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
        esac
    elif [[ $key = $'\x0a' ]] || [[ $key = $'\x0d' ]]; then
        echo "ENTER"
    elif [[ $key = $'\x1b' ]]; then
        echo "ESC"
    elif [[ $key = 'q' ]] || [[ $key = 'Q' ]]; then
        echo "QUIT"
    else
        echo "OTHER"
    fi
}

# Función para mostrar menú con navegación por flechas
mostrar_menu_navegable() {
    local opciones=("Usar ultima version disponible (por defecto)" "Elegir version manualmente" "Usar ultima version seleccionada manualmente")
    local seleccionado=0
    local total_opciones=${#opciones[@]}
    
    while true; do
        clear
        echo
        echo "==============================================="
        echo
        echo "            DownFast Auto-Updater v2.0"
        echo
        echo "================================================"
        echo
        echo "================================================"
        echo "             MENU DE OPCIONES"
        echo "================================================"
        
        for i in "${!opciones[@]}"; do
            if [ $i -eq $seleccionado ]; then
                echo -e "|  ${VERDE}► $((i+1)). ${opciones[i]}${NC}"
            else
                echo "|    $((i+1)). ${opciones[i]}"
            fi
        done
        
        echo "================================================"
        echo
        echo -e "${AMARILLO}Usa las flechas ↑↓ para navegar, Enter para seleccionar, 'q' para salir${NC}"
        
        local tecla=$(leer_tecla)
        
        case $tecla in
            "UP")
                ((seleccionado--))
                if [ $seleccionado -lt 0 ]; then
                    seleccionado=$((total_opciones-1))
                fi
                ;;
            "DOWN")
                ((seleccionado++))
                if [ $seleccionado -ge $total_opciones ]; then
                    seleccionado=0
                fi
                ;;
            "ENTER")
                case $seleccionado in
                    0) opcion_ultima_version ;;
                    1) opcion_manual ;;
                    2) opcion_ultima_manual ;;
                esac
                break
                ;;
            "QUIT")
                echo
                imprimir_mensaje "INFO" "$AMARILLO" "Saliendo..."
                exit 0
                ;;
        esac
    done
}

# Función para mostrar versiones con navegación por flechas
mostrar_versiones_navegable() {
    local versions_array=("$@")
    local seleccionado=0
    local total_versiones=${#versions_array[@]}
    
    # Obtener información de commits para todas las versiones
    local commit_info_array=()
    for version in "${versions_array[@]}"; do
        local commit_info=$(obtener_commit_info "$version")
        commit_info_array+=("$commit_info")
    done
    
    while true; do
        clear
        echo
        echo "================================================"
        echo "             VERSIONES DISPONIBLES      "
        echo "================================================"
        
        for i in "${!versions_array[@]}"; do
            local version_num=$(echo "${versions_array[i]}" | sed 's/^index_\|\.js$//g')
            if [ $i -eq $seleccionado ]; then
                echo -e "|  ${VERDE}► $((i+1)). v$version_num - ${commit_info_array[i]}${NC}"
            else
                echo "|    $((i+1)). v$version_num - ${commit_info_array[i]}"
            fi
        done
        
        echo "================================================"
        echo
        echo -e "${AMARILLO}Usa las flechas ↑↓ para navegar, Enter para seleccionar, 'q' para volver al menú${NC}"
        
        local tecla=$(leer_tecla)
        
        case $tecla in
            "UP")
                ((seleccionado--))
                if [ $seleccionado -lt 0 ]; then
                    seleccionado=$((total_versiones-1))
                fi
                ;;
            "DOWN")
                ((seleccionado++))
                if [ $seleccionado -ge $total_versiones ]; then
                    seleccionado=0
                fi
                ;;
            "ENTER")
                local selected_file="${versions_array[seleccionado]}"
                
                # Guardar selección manual
                echo "$selected_file" > "last_manual_choice.txt"
                clear
                imprimir_mensaje "INFO" "$VERDE" "Version seleccionada guardada para uso futuro"
                
                MANUAL_FILE="$selected_file"
                imprimir_mensaje "INFO" "$AZUL" "Has seleccionado: $selected_file"
                
                # Verificar si ya existe localmente
                if [ -f "VPN/$selected_file" ]; then
                    imprimir_mensaje "OK" "$VERDE" "Archivo encontrado localmente"
                    FILE_TO_EXECUTE="$selected_file"
                    ejecutar_archivo
                else
                    imprimir_mensaje "INFO" "$AZUL" "Descargando version seleccionada..."
                    descargar_version_especifica "$selected_file"
                fi
                return
                ;;
            "QUIT")
                mostrar_menu_navegable
                return
                ;;
        esac
    done
}

# Función para obtener archivos del repositorio GitHub
obtener_archivos_github() {
    local api_url="https://api.github.com/repos/UserZero075/DownFast/contents"
    local temp_file="$HOME/.github_temp_$$"
    
    # Descargar información del repositorio (sin mensajes de debug aquí)
    if ! wget -q --timeout=30 --user-agent="DownFast-Updater" -O "$temp_file" "$api_url" 2>/dev/null; then
        # Solo retornar error, no imprimir mensaje
        rm -f "$temp_file"
        return 1
    fi
    
    # Verificar que el archivo se descargó correctamente
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Extraer archivos index_*.js usando grep y sed
    local github_files=$(grep -o '"name":"index_[^"]*\.js"' "$temp_file" 2>/dev/null | sed 's/"name":"//g; s/"//g')
    
    if [ -z "$github_files" ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Encontrar la versión más alta
    local latest_file=""
    local latest_version="0.0.0"
    
    for file in $github_files; do
        local version=$(echo "$file" | sed 's/^index_\|\.js$//g')
        if [ "$(compare_version "index_${version}.js" "index_${latest_version}.js")" = "1" ]; then
            latest_version="$version"
            latest_file="$file"
        fi
    done
    
    rm -f "$temp_file"
    
    # Solo devolver el nombre del archivo, sin mensajes
    echo "$latest_file"
    return 0
}

# Función para obtener lista completa de versiones
obtener_lista_versiones() {
    local api_url="https://api.github.com/repos/UserZero075/DownFast/contents"
    local temp_file="$HOME/.github_temp_$$"
    
    if ! wget -q --timeout=30 --user-agent="DownFast-Updater" -O "$temp_file" "$api_url" 2>/dev/null; then
        rm -f "$temp_file"
        return 1
    fi
    
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Extraer archivos index_*.js
    local github_files=$(grep -o '"name":"index_[^"]*\.js"' "$temp_file" 2>/dev/null | sed 's/"name":"//g; s/"//g')
    
    if [ -z "$github_files" ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Crear array temporal para ordenar
    local temp_array=()
    for file in $github_files; do
        temp_array+=("$file")
    done
    
    # Ordenar por versión (descendente)
    IFS=$'\n' sorted_files=($(printf '%s\n' "${temp_array[@]}" | sort -V -r))
    
    rm -f "$temp_file"
    
    # Devolver archivos ordenados
    printf '%s\n' "${sorted_files[@]}"
    return 0
}

# Función para obtener información de commit
obtener_commit_info() {
    local filename="$1"
    local commit_url="https://api.github.com/repos/UserZero075/DownFast/commits?path=$filename&per_page=1"
    local temp_commit_file="$HOME/.commit_temp_$$"
    
    # Intentar obtener información del commit con timeout corto
    if wget -q --timeout=8 --user-agent="DownFast-Updater" -O "$temp_commit_file" "$commit_url" 2>/dev/null; then
        if [ -f "$temp_commit_file" ] && [ -s "$temp_commit_file" ]; then
            # Extraer el mensaje del commit
            local commit_msg=$(grep -o '"message":"[^"]*"' "$temp_commit_file" 2>/dev/null | head -n1 | sed 's/"message":"//g; s/"//g' | sed 's/\\n.*//g')
            
            if [ -n "$commit_msg" ] && [ ${#commit_msg} -gt 0 ]; then
                # Truncar mensaje si es muy largo
                if [ ${#commit_msg} -gt 40 ]; then
                    echo "${commit_msg:0:37}..."
                else
                    echo "$commit_msg"
                fi
            else
                echo "Disponible para descarga"
            fi
        else
            echo "Disponible para descarga"
        fi
    else
        echo "Disponible para descarga"
    fi
    
    rm -f "$temp_commit_file"
}

# Función para mostrar menú de opciones (mantener compatibilidad)
mostrar_menu() {
    mostrar_menu_navegable
}

# Opción 1: Usar última versión disponible
opcion_ultima_version() {
    clear
    echo
    imprimir_mensaje "INFO" "$AZUL" "Usando ultima version disponible..."
    imprimir_mensaje "INFO" "$AZUL" "Buscando actualizaciones..."
    descargar_ultima_version
}

# Opción 2: Elegir versión manualmente
opcion_manual() {
    clear
    echo
    imprimir_mensaje "INFO" "$AZUL" "Obteniendo lista de versiones disponibles..."
    
    # Obtener lista de versiones
    local versions_list=$(obtener_lista_versiones)
    
    if [ $? -ne 0 ] || [ -z "$versions_list" ]; then
        imprimir_mensaje "ERROR" "$ROJO" "No se pudo obtener la lista de versiones"
        read -p "Presiona Enter para volver al menu..." 
        mostrar_menu_navegable
        return 1
    fi
    
    # Convertir a array
    local versions_array=()
    while IFS= read -r line; do
        versions_array+=("$line")
    done <<< "$versions_list"
    
    # Mostrar versiones con navegación
    mostrar_versiones_navegable "${versions_array[@]}"
}

# Opción 3: Usar última versión seleccionada manualmente
opcion_ultima_manual() {
    clear
    if [ ! -f "last_manual_choice.txt" ]; then
        imprimir_mensaje "ERROR" "$ROJO" "No hay una version manual previa guardada"
        imprimir_mensaje "INFO" "$AMARILLO" "Usa la opcion 2 primero para seleccionar una version"
        echo
        read -p "Presiona Enter para volver al menu..." 
        mostrar_menu_navegable
        return
    fi
    
    # Leer el archivo y limpiar posibles caracteres extra
    MANUAL_FILE=$(cat "last_manual_choice.txt" | tr -d '\r\n' | sed 's/[[:space:]]*$//')
    
    echo
    imprimir_mensaje "INFO" "$AZUL" "Usando ultima version manual seleccionada: $MANUAL_FILE"
    
    # Verificar si el archivo existe localmente
    if [ -f "VPN/$MANUAL_FILE" ]; then
        imprimir_mensaje "OK" "$VERDE" "Archivo encontrado localmente"
        FILE_TO_EXECUTE="$MANUAL_FILE"
        ejecutar_archivo
    else
        imprimir_mensaje "INFO" "$AZUL" "Descargando version seleccionada..."
        descargar_version_especifica "$MANUAL_FILE"
    fi
}

# Función para descargar versión específica
descargar_version_especifica() {
    local filename="$1"
    
    if descargar_archivo_github "$filename" "VPN/$filename"; then
        FILE_TO_EXECUTE="$filename"
        ejecutar_archivo
    else
        imprimir_mensaje "ERROR" "$ROJO" "Error al descargar la version seleccionada"
        exit 1
    fi
}

# Función para descargar última versión
descargar_ultima_version() {
    # Obtener la última versión de GitHub
    latest_github_file=$(obtener_archivos_github)

    if [ $? -ne 0 ] || [ -z "$latest_github_file" ]; then
        imprimir_mensaje "ERROR" "$ROJO" "No se pudo conectar a GitHub o no hay archivos disponibles"
        exit 1
    fi

    # Limpiar el nombre del archivo por si tiene caracteres extraños
    latest_github_file=$(echo "$latest_github_file" | tr -d '\r\n' | sed 's/[^a-zA-Z0-9._-]//g')

    latest_version=$(echo "$latest_github_file" | sed 's/^index_\|\.js$//g')
    imprimir_mensaje "OK" "$VERDE" "Ultima version disponible: v$latest_version"

    # Verificar archivos locales
    local_files=$(find VPN -name "index_*.js" 2>/dev/null)
    needs_download=false
    file_to_execute="$latest_github_file"

    if [ -z "$local_files" ]; then
        imprimir_mensaje "INFO" "$AMARILLO" "Primera instalacion detectada"
        needs_download=true
    else
        # Encontrar el archivo local más reciente
        latest_local_file=""
        latest_local_version="0.0.0"
        
        for file in $local_files; do
            filename=$(basename "$file")
            version=$(echo "$filename" | sed 's/^index_\|\.js$//g')
            if [ "$(compare_version "index_${version}.js" "index_${latest_local_version}.js")" = "1" ]; then
                latest_local_version="$version"
                latest_local_file="$filename"
            fi
        done
        
        imprimir_mensaje "INFO" "$CIAN" "Version local: v$latest_local_version"
        
        # Comparar versiones
        if [ "$(compare_version "$latest_github_file" "$latest_local_file")" = "1" ]; then
            imprimir_mensaje "INFO" "$AMARILLO" "Nueva actualizacion disponible"
            needs_download=true
            # Eliminar archivos antiguos
            rm -f VPN/index_*.js
        else
            imprimir_mensaje "OK" "$VERDE" "Tu version esta actualizada"
            file_to_execute="$latest_local_file"
        fi
    fi

    # Descargar si es necesario
    if [ "$needs_download" = true ]; then
        if ! descargar_archivo_github "$latest_github_file" "VPN/$latest_github_file"; then
            exit 1
        fi
    fi
    
    FILE_TO_EXECUTE="$file_to_execute"
    ejecutar_archivo
}

# Función para ejecutar el archivo
ejecutar_archivo() {
    # Configurar almacenamiento de Termux si es necesario (suprimiendo warnings del sistema)
    if [ ! -d "../storage" ]; then
        imprimir_mensaje "INFO" "$AMARILLO" "Configurando almacenamiento de Termux..."
        termux-setup-storage 2>/dev/null
    fi

    # Verificar que el archivo existe
    if [ ! -f "VPN/$FILE_TO_EXECUTE" ]; then
        imprimir_mensaje "ERROR" "$ROJO" "Archivo no encontrado: $FILE_TO_EXECUTE"
        exit 1
    fi

    echo
    imprimir_mensaje "OK" "$VERDE" "Ejecutando: $FILE_TO_EXECUTE"
    echo
    echo "================================================"
    echo "              DOWNFAST INICIADO        "
    echo "================================================"
    echo

    # Ejecutar el archivo con Node.js
    node "VPN/$FILE_TO_EXECUTE"
    exit_code=$?

    echo
    echo "================================================"

    if [ $exit_code -ne 0 ]; then
        imprimir_mensaje "ERROR" "$ROJO" "DownFast termino con errores (Codigo: $exit_code)"
        imprimir_mensaje "INFO" "$AMARILLO" "Revisa los mensajes anteriores para mas detalles"
    else
        imprimir_mensaje "OK" "$VERDE" "DownFast ejecutado exitosamente"
    fi
}

# Función para descargar archivo de GitHub
descargar_archivo_github() {
    local filename="$1"
    local output_path="$2"
    local download_url="https://raw.githubusercontent.com/UserZero075/DownFast/main/$filename"
    
    imprimir_mensaje "INFO" "$AZUL" "Descargando: $filename"
    if wget -q --timeout=60 -O "$output_path" "$download_url" 2>/dev/null; then
        imprimir_mensaje "OK" "$VERDE" "Descarga completada"
        return 0
    else
        imprimir_mensaje "ERROR" "$ROJO" "Error al descargar $filename"
        return 1
    fi
}

echo
echo "================================================"
echo
echo "         DownFast Auto-Updater v2.0"
echo
echo "================================================"
echo

# Limpiar archivos temporales de ejecuciones anteriores
imprimir_mensaje "INFO" "$AMARILLO" "Limpiando archivos temporales..."
rm -f last_manual_choice.txt.tmp version_list.txt version_count.txt 2>/dev/null
imprimir_mensaje "OK" "$VERDE" "Limpieza completada"
echo

# Verificar e instalar wget si es necesario
if ! command -v wget &> /dev/null; then
    instalar_wget
fi

# Verificar e instalar Node.js si es necesario
if ! command -v node &> /dev/null; then
    instalar_nodejs
fi

# Verificar si existe la carpeta DevFastVPN
if [ ! -d "DevFastVPN" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Carpeta DevFastVPN no encontrada. Descargando..."
    
    # Descargar DevFastVPN.zip
    if ! wget -q --timeout=60 "https://raw.githubusercontent.com/UserZero075/DownFast/main/DevFastVPN.zip" 2>/dev/null; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al descargar DevFastVPN.zip"
        exit 1
    fi
    
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando DevFast VPN..."
    if ! unzip -o "DevFastVPN.zip" > /dev/null 2>&1; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al descomprimir DevFastVPN.zip"
        exit 1
    fi
    
    # Limpiar archivo zip
    rm -f "DevFastVPN.zip"
    imprimir_mensaje "OK" "$VERDE" "DevFastVPN instalado exitosamente"
fi

cd "DevFastVPN/"

# Crear carpeta VPN si no existe
if [ ! -d "VPN" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Creando carpeta VPN..."
    mkdir -p "VPN"
    imprimir_mensaje "OK" "$VERDE" "Carpeta creada exitosamente"
    echo
fi

# Mostrar menú de opciones
mostrar_menu
