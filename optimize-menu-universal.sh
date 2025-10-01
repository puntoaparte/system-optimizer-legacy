#!/bin/bash

# Versión simplificada con interfaz de menú del script de optimización de rendimiento
# Compatible con Ubuntu, Linux Mint y otras distribuciones basadas en Ubuntu

# Variables de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTIMIZE_SCRIPT="$SCRIPT_DIR/optimize-universal.sh"
CONFIG_FILE="$SCRIPT_DIR/optimization.conf"
LOG_FILE="/var/log/system-optimization-menu.log"

# Valores por defecto
SWAPPINESS=10
VFS_CACHE_PRESSURE=50
DIRTY_RATIO=5
DIRTY_BACKGROUND_RATIO=2
ZRAM_PERCENTAGE=25
DISABLED_SERVICES=(
    "bluetooth.service"
    "cups-browsed.service"
    "avahi-daemon.service"
    "ModemManager.service"
    "power-profiles-daemon.service"
    "fwupd.service"
    "kerneloops.service"
    "colord.service"
    "rtkit-daemon.service"
    "whoopsie.service"
    "speech-dispatcher.service"
)

# Función para registrar mensajes
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Función para cargar la configuración
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_message "INFO" "Cargando configuración desde $CONFIG_FILE"
        # Cargar configuración sin ejecutar comandos
        while IFS= read -r line; do
            # Ignorar comentarios y líneas vacías
            if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "$line" ]]; then
                # Evaluar solo asignaciones simples
                if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                    eval "$line" 2>/dev/null
                fi
            fi
        done < "$CONFIG_FILE"
        log_message "INFO" "Configuración cargada correctamente"
    else
        log_message "INFO" "Archivo de configuración no encontrado, usando valores por defecto"
    fi
}

# Función para verificar si el script de optimización existe
check_optimization_script() {
    if [ ! -f "$OPTIMIZE_SCRIPT" ]; then
        echo "Error: No se encuentra el script de optimización en $OPTIMIZE_SCRIPT"
        log_message "ERROR" "Script de optimización no encontrado: $OPTIMIZE_SCRIPT"
        exit 1
    fi
}

# Función para verificar privilegios de root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Este script requiere privilegios de root para algunas operaciones."
        echo "Se solicitarán credenciales cuando sea necesario."
        echo ""
    fi
}

# Función para ajustar parámetros de memoria
adjust_memory_params() {
    echo "Ajustando parámetros de memoria..."
    log_message "INFO" "Ajustando parámetros de memoria"
    
    # Verificar si los parámetros ya existen y actualizarlos, si no, agregarlos
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=$SWAPPINESS" | sudo tee -a /etc/sysctl.conf >/dev/null
    else
        sudo sed -i "s/vm.swappiness=.*/vm.swappiness=$SWAPPINESS/" /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=$VFS_CACHE_PRESSURE" | sudo tee -a /etc/sysctl.conf >/dev/null
    else
        sudo sed -i "s/vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=$VFS_CACHE_PRESSURE/" /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.dirty_ratio" /etc/sysctl.conf; then
        echo "vm.dirty_ratio=$DIRTY_RATIO" | sudo tee -a /etc/sysctl.conf >/dev/null
    else
        sudo sed -i "s/vm.dirty_ratio=.*/vm.dirty_ratio=$DIRTY_RATIO/" /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.dirty_background_ratio" /etc/sysctl.conf; then
        echo "vm.dirty_background_ratio=$DIRTY_BACKGROUND_RATIO" | sudo tee -a /etc/sysctl.conf >/dev/null
    else
        sudo sed -i "s/vm.dirty_background_ratio=.*/vm.dirty_background_ratio=$DIRTY_BACKGROUND_RATIO/" /etc/sysctl.conf
    fi
    
    # Aplicar cambios inmediatamente
    if sudo sysctl -w "vm.swappiness=$SWAPPINESS" >/dev/null 2>&1 && \
       sudo sysctl -w "vm.vfs_cache_pressure=$VFS_CACHE_PRESSURE" >/dev/null 2>&1 && \
       sudo sysctl -w "vm.dirty_ratio=$DIRTY_RATIO" >/dev/null 2>&1 && \
       sudo sysctl -w "vm.dirty_background_ratio=$DIRTY_BACKGROUND_RATIO" >/dev/null 2>&1; then
        echo "Parámetros de memoria ajustados correctamente."
        log_message "INFO" "Parámetros de memoria ajustados correctamente"
    else
        echo "Error al ajustar parámetros de memoria."
        log_message "ERROR" "Error al ajustar parámetros de memoria"
    fi
}

# Función para deshabilitar servicios innecesarios
disable_unnecessary_services() {
    echo "Deshabilitando servicios innecesarios..."
    log_message "INFO" "Deshabilitando servicios innecesarios"
    
    # Usar servicios de la configuración
    for service in "${DISABLED_SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^$service"; then
            if systemctl is-active --quiet "$service"; then
                echo "Deshabilitando $service..."
                if sudo systemctl stop "$service" 2>/dev/null && sudo systemctl disable "$service" 2>/dev/null; then
                    echo "$service deshabilitado correctamente."
                    log_message "INFO" "$service deshabilitado correctamente"
                else
                    echo "Error al deshabilitar $service."
                    log_message "WARNING" "Error al deshabilitar $service"
                fi
            else
                echo "$service ya está inactivo."
                log_message "INFO" "$service ya está inactivo"
            fi
        else
            log_message "DEBUG" "$service no está instalado en el sistema"
        fi
    done
    
    echo "Servicios innecesarios procesados."
}

# Función para configurar zram
configure_zram() {
    echo "Configurando zram..."
    log_message "INFO" "Configurando zram"
    
    if ! command -v zramctl &> /dev/null; then
        echo "Instalando zram-tools..."
        log_message "INFO" "Instalando zram-tools"
        if sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y zram-tools >/dev/null 2>&1; then
            echo "zram-tools instalado correctamente."
            log_message "INFO" "zram-tools instalado correctamente"
        else
            echo "Error al instalar zram-tools."
            log_message "ERROR" "Error al instalar zram-tools"
            return 1
        fi
    fi

    if [ -f /etc/default/zramswap ]; then
        if grep -q "#PERCENTAGE=75" /etc/default/zramswap; then
            if sudo sed -i "s/#PERCENTAGE=75/PERCENTAGE=$ZRAM_PERCENTAGE/" /etc/default/zramswap; then
                echo "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE."
                log_message "INFO" "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE"
            else
                echo "Error al configurar zram."
                log_message "ERROR" "Error al configurar zram"
            fi
        elif ! grep -q "PERCENTAGE=" /etc/default/zramswap; then
            if echo "PERCENTAGE=$ZRAM_PERCENTAGE" | sudo tee -a /etc/default/zramswap >/dev/null; then
                echo "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE."
                log_message "INFO" "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE"
            else
                echo "Error al configurar zram."
                log_message "ERROR" "Error al configurar zram"
            fi
        else
            echo "zram ya está configurado."
            log_message "INFO" "zram ya está configurado"
        fi
    else
        if echo "PERCENTAGE=$ZRAM_PERCENTAGE" | sudo tee /etc/default/zramswap >/dev/null; then
            echo "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE."
            log_message "INFO" "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE"
        else
            echo "Error al configurar zram."
            log_message "ERROR" "Error al configurar zram"
        fi
    fi

    if sudo systemctl enable zramswap >/dev/null 2>&1 && sudo systemctl restart zramswap >/dev/null 2>&1; then
        echo "zramswap habilitado y reiniciado."
        log_message "INFO" "zramswap habilitado y reiniciado"
    else
        echo "Error al habilitar o reiniciar zramswap."
        log_message "WARNING" "Error al habilitar o reiniciar zramswap"
    fi
}

# Función para limpiar el sistema
clean_system() {
    echo "Limpiando el sistema..."
    log_message "INFO" "Limpiando el sistema"
    
    if sudo apt-get autoremove -y >/dev/null 2>&1 && sudo apt-get autoclean -y >/dev/null 2>&1; then
        echo "Paquetes innecesarios eliminados y caché limpiada."
        log_message "INFO" "Paquetes innecesarios eliminados y caché limpiada"
    else
        echo "Error al limpiar paquetes."
        log_message "WARNING" "Error al limpiar paquetes"
    fi
    
    # Limpiar caché de thumbnails para todos los usuarios
    for home_dir in /home/*; do
        if [ -d "$home_dir" ]; then
            if sudo rm -rf "$home_dir/.cache/thumbnails"/* 2>/dev/null; then
                log_message "INFO" "Caché de thumbnails limpiada en $home_dir"
            fi
        fi
    done
    
    if sudo rm -rf /root/.cache/thumbnails/* 2>/dev/null; then
        log_message "INFO" "Caché de thumbnails limpiada en /root"
    fi
    
    echo "Sistema limpiado."
}

# Función para ejecutar mantenimiento de memoria
run_memory_maintenance() {
    echo "Ejecutando mantenimiento de memoria..."
    log_message "INFO" "Ejecutando mantenimiento de memoria"
    
    # Sincronizar discos
    sync
    
    # Liberar cachés del sistema en secuencia
    for i in 1 2 3; do
        if echo $i | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1; then
            log_message "INFO" "drop_caches=$i ejecutado"
        else
            log_message "WARNING" "Error al ejecutar drop_caches=$i"
        fi
        sleep 1
    done
    
    echo "Mantenimiento de memoria completado."
    log_message "INFO" "Mantenimiento de memoria completado"
}

# Función para mostrar el menú principal
show_menu() {
    clear
    echo "=== Optimizador de Rendimiento Universal ==="
    echo "Compatible con Ubuntu, Linux Mint y otras distros basadas en Ubuntu"
    echo ""
    echo "Selecciona una opción:"
    echo "1. Ejecutar todas las optimizaciones"
    echo "2. Solo ajustar parámetros de memoria (swappiness, etc.)"
    echo "3. Solo deshabilitar servicios innecesarios"
    echo "4. Solo configurar zram (memoria virtual comprimida)"
    echo "5. Solo limpiar el sistema"
    echo "6. Ejecutar mantenimiento de memoria ahora"
    echo "7. Salir"
    echo ""
}

# Función principal
main() {
    # Registrar inicio
    log_message "INFO" "=== INICIO DEL MENÚ DE OPTIMIZACIÓN ==="
    
    # Cargar configuración
    load_config
    
    # Verificar script de optimización
    check_optimization_script
    
    # Verificar privilegios
    check_root
    
    while true; do
        show_menu
        read -p "Ingresa tu opción (1-7): " choice

        case $choice in
            1)
                echo "Ejecutando todas las optimizaciones..."
                log_message "INFO" "Ejecutando todas las optimizaciones"
                sudo "$OPTIMIZE_SCRIPT"
                echo "Optimizaciones completadas. Se recomienda reiniciar el sistema."
                log_message "INFO" "Optimizaciones completadas"
                ;;
            2)
                adjust_memory_params
                ;;
            3)
                disable_unnecessary_services
                ;;
            4)
                configure_zram
                ;;
            5)
                clean_system
                ;;
            6)
                run_memory_maintenance
                ;;
            7)
                echo "Saliendo..."
                log_message "INFO" "=== FIN DEL MENÚ DE OPTIMIZACIÓN ==="
                break
                ;;
            *)
                echo "Opción inválida. Por favor selecciona una opción entre 1 y 7."
                log_message "WARNING" "Opción inválida: $choice"
                ;;
        esac
        echo ""
        read -p "Presiona Enter para continuar..."
        clear
    done
}

# Ejecutar función principal
main "$@"