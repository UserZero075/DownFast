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

# Función para el menú de selección con teclas de dirección
menu_selector() {
    local options=("$@")
    local selected=0
    local key=""
    local TOTAL=$((${#options[@]} - 1))

    # Función para imprimir el menú
    print_menu() {
        echo -e "\n+-----------------------------------------------------------------------------+"
        echo -e "|                              MENU DE OPCIONES                                |"
        echo -e "+-----------------------------------------------------------------------------+"
        echo -e "|                                                                             |"
        
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "|\033[7m  ${options[$i]}  \033[0m                                     |"
            else
                echo -e "|  ${options[$i]}                                                      |"
            fi
        done
        
        echo -e "|                                                                             |"
        echo -e "+-----------------------------------------------------------------------------+"
        echo -e "\nUsa las flechas ↑↓ para navegar y ENTER para seleccionar"
    }

    # Ocultar el cursor
    tput civis

    # Leer teclas
    while true; do
        clear
        print_menu

        # Leer una tecla
        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            case $key in
                '[A') # Flecha arriba
                    ((selected--))
                    [ $selected -lt 0 ] && selected=$TOTAL
                    ;;
                '[B') # Flecha abajo
                    ((selected++))
                    [ $selected -gt $TOTAL ] && selected=0
                    ;;
            esac
        elif [[ $key == "" ]]; then # Enter
            break
        fi
    done

    # Mostrar el cursor nuevamente
    tput cnorm

    return $selected
}

# Función para seleccionar versión específica
version_selector() {
    local versions=("$@")
    local selected=0
    local key=""
    local TOTAL=$((${#versions[@]} - 1))

    print_versions_menu() {
        echo -e "\n+-----------------------------------------------------------------------------+"
        echo -e "|                           VERSIONES DISPONIBLES                              |"
        echo -e "+-----------------------------------------------------------------------------+"
        echo -e "|                                                                             |"
        
        for i in "${!versions[@]}"; do
            local version=$(echo "${versions[$i]}" | sed 's/^index_\|\.js$//g')
            if [ $i -eq $selected ]; then
                echo -e "|\033[7m  v$version  \033[0m                                          |"
            else
                echo -e "|  v$version                                                           |"
            fi
        done
        
        echo -e "|                                                                             |"
        echo -e "+-----------------------------------------------------------------------------+"
        echo -e "\nUsa las flechas ↑↓ para navegar y ENTER para seleccionar, ESC para volver"
    }

    tput civis

    while true; do
        clear
        print_versions_menu

        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            case $key in
                '[A') # Flecha arriba
                    ((selected--))
                    [ $selected -lt 0 ] && selected=$TOTAL
                    ;;
                '[B') # Flecha abajo
                    ((selected++))
                    [ $selected -gt $TOTAL ] && selected=0
                    ;;
                '') # ESC
                    tput cnorm
                    return 255
                    ;;
            esac
        elif [[ $key == "" ]]; then # Enter
            break
        fi
    done

    tput cnorm
    return $selected
}

# Función para comparar versiones
compare_version() {
    local ver1="$1"
    local ver2="$2"
    
    ver1_clean=$(echo "$ver1" | sed 's/^index_\|\.js$//g')
    ver2_clean=$(echo "$ver2" | sed 's/^index_\|\.js$//g')
    
    if [ "$(printf '%s\n' "$ver1_clean" "$ver2_clean" | sort -V | tail -n1)" = "$ver1_clean" ]; then
        if [ "$ver1_clean" != "$ver2_clean" ]; then
            echo "1"
        else
            echo "0"
        fi
    else
        echo "-1"
    fi
}

# Función para obtener archivos del repositorio GitHub
obtener_archivos_github() {
    local api_url="https://api.github.com/repos/UserZero075/DownFast/contents"
    local temp_file="/tmp/github_temp_$$"
    
    if ! wget -q --timeout=30 --user-agent="DownFast-Updater" -O "$temp_file" "$api_url" 2>/dev/null; then
        rm -f "$temp_file"
        return 1
    fi
    
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    local github_files=$(grep -o '"name":"index_[^"]*\.js"' "$temp_file" | sed 's/"name":"//g; s/"//g')
    rm -f "$temp_file"
    
    if [ -z "$github_files" ]; then
        return 1
    fi
    
    echo "$github_files"
    return 0
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

# Función para instalar dependencias necesarias
instalar_dependencias() {
    if ! command -v wget &> /dev/null; then
        imprimir_mensaje "INFO" "$AMARILLO" "Instalando wget..."
        if ! (apt-get update -y && apt-get install -y wget) &> /dev/null; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar wget"
            exit 1
        fi
    fi

    if ! command -v node &> /dev/null; then
        imprimir_mensaje "INFO" "$AMARILLO" "Instalando Node.js..."
        if ! pkg install nodejs-lts -y &> /dev/null; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar Node.js"
            exit 1
        fi
    fi
}
# Programa principal
clear
echo
echo "==============================================================================="
echo
echo "                        DownFast Auto-Updater v2.0"
echo
echo "==============================================================================="
echo

# Instalar dependencias necesarias
instalar_dependencias

# Verificar y crear carpeta DevFastVPN si no existe
if [ ! -d "DevFastVPN" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando DevFastVPN..."
    if ! wget -q "https://raw.githubusercontent.com/UserZero075/DownFast/main/DevFastVPN.zip" 2>/dev/null; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al descargar DevFastVPN"
        exit 1
    fi
    
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando DevFastVPN..."
    if ! unzip -o "DevFastVPN.zip" > /dev/null 2>&1; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al descomprimir DevFastVPN"
        exit 1
    fi
    rm -f "DevFastVPN.zip"
    imprimir_mensaje "OK" "$VERDE" "DevFastVPN instalado correctamente"
fi

cd "DevFastVPN/" || exit 1

# Crear carpeta VPN si no existe
if [ ! -d "VPN" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Creando carpeta VPN..."
    mkdir -p "VPN"
fi

# Definir las opciones del menú principal
OPTIONS=(
    "Usar ultima version disponible (por defecto)"
    "Elegir version manualmente"
    "Usar ultima version seleccionada manualmente"
)

# Mostrar menú principal y obtener selección
while true; do
    menu_selector "${OPTIONS[@]}"
    user_choice=$?

    case $user_choice in
        0) # Última versión disponible
            echo
            imprimir_mensaje "INFO" "$AZUL" "Buscando actualizaciones..."
            
            latest_github_file=$(obtener_archivos_github | sort -V | tail -n1)
            if [ -z "$latest_github_file" ]; then
                imprimir_mensaje "ERROR" "$ROJO" "No se pudo obtener la última versión"
                exit 1
            fi

            latest_version=$(echo "$latest_github_file" | sed 's/^index_\|\.js$//g')
            imprimir_mensaje "OK" "$VERDE" "Ultima version disponible: v$latest_version"

            # Verificar versión local
            local_files=$(find VPN -name "index_*.js" 2>/dev/null)
            needs_download=true
            
            if [ ! -z "$local_files" ]; then
                latest_local_file=$(echo "$local_files" | sort -V | tail -n1)
                latest_local_version=$(basename "$latest_local_file" | sed 's/^index_\|\.js$//g')
                
                imprimir_mensaje "INFO" "$CIAN" "Version local: v$latest_local_version"
                
                if [ "$(compare_version "$latest_github_file" "$(basename "$latest_local_file")")" != "1" ]; then
                    needs_download=false
                    file_to_execute="$latest_local_file"
                    imprimir_mensaje "OK" "$VERDE" "Ya tienes la última versión"
                else
                    imprimir_mensaje "INFO" "$AMARILLO" "Nueva actualización disponible"
                    rm -f VPN/index_*.js
                fi
            fi
            
            if [ "$needs_download" = true ]; then
                if ! descargar_archivo_github "$latest_github_file" "VPN/$latest_github_file"; then
                    exit 1
                fi
                file_to_execute="VPN/$latest_github_file"
            fi
            break
            ;;
            
        1) # Elegir versión manualmente
            echo
            imprimir_mensaje "INFO" "$AZUL" "Obteniendo lista de versiones..."
            
            # Obtener y ordenar versiones disponibles
            mapfile -t available_versions < <(obtener_archivos_github | sort -V)
            
            if [ ${#available_versions[@]} -eq 0 ]; then
                imprimir_mensaje "ERROR" "$ROJO" "No se encontraron versiones disponibles"
                continue
            fi
            
            # Mostrar selector de versiones
            version_selector "${available_versions[@]}"
            version_choice=$?
            
            if [ $version_choice -eq 255 ]; then
                continue
            fi
            
            selected_file="${available_versions[$version_choice]}"
            echo "$selected_file" > last_manual_choice.txt
            
            if [ -f "VPN/$selected_file" ]; then
                imprimir_mensaje "OK" "$VERDE" "Usando versión local: $selected_file"
                file_to_execute="VPN/$selected_file"
            else
                imprimir_mensaje "INFO" "$AMARILLO" "Descargando versión seleccionada..."
                if ! descargar_archivo_github "$selected_file" "VPN/$selected_file"; then
                    exit 1
                fi
                file_to_execute="VPN/$selected_file"
            fi
            break
            ;;
            
        2) # Última versión seleccionada manualmente
            if [ ! -f "last_manual_choice.txt" ]; then
                imprimir_mensaje "ERROR" "$ROJO" "No hay una versión manual previa guardada"
                imprimir_mensaje "INFO" "$AMARILLO" "Usa la opción 2 primero para seleccionar una versión"
                continue
            fi
            
            MANUAL_FILE=$(cat "last_manual_choice.txt")
            echo
            imprimir_mensaje "INFO" "$AZUL" "Usando última versión manual: $MANUAL_FILE"
            
            if [ -f "VPN/$MANUAL_FILE" ]; then
                imprimir_mensaje "OK" "$VERDE" "Archivo encontrado localmente"
                file_to_execute="VPN/$MANUAL_FILE"
            else
                imprimir_mensaje "INFO" "$AMARILLO" "Descargando versión seleccionada..."
                if ! descargar_archivo_github "$MANUAL_FILE" "VPN/$MANUAL_FILE"; then
                    exit 1
                fi
                file_to_execute="VPN/$MANUAL_FILE"
            fi
            break
            ;;
    esac
done

# Verificar archivo final
if [ ! -f "$file_to_execute" ]; then
    imprimir_mensaje "ERROR" "$ROJO" "Archivo no encontrado: $file_to_execute"
    exit 1
fi

echo
echo "==============================================================================="
echo "                              DOWNFAST INICIADO"
echo "==============================================================================="
echo

# Ejecutar el archivo con Node.js
node "$file_to_execute"
exit_code=$?

echo
echo "==============================================================================="

if [ $exit_code -ne 0 ]; then
    imprimir_mensaje "ERROR" "$ROJO" "DownFast terminó con errores (Código: $exit_code)"
    imprimir_mensaje "INFO" "$AMARILLO" "Revisa los mensajes anteriores para más detalles"
else
    imprimir_mensaje "OK" "$VERDE" "DownFast ejecutado exitosamente"
fi

echo
imprimir_mensaje "INFO" "$AZUL" "Minimizando ventana en 3 segundos..."
imprimir_mensaje "INFO" "$AZUL" "Puedes cerrar esta ventana cuando quieras"

sleep 3

# En sistemas que lo soporten, minimizar la ventana
if command -v xdotool &> /dev/null; then
    xdotool getactivewindow windowminimize
fi

# Mantener el script vivo
while true; do
    sleep 60
done
