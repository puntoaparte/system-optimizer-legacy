#!/bin/bash

# Script de optimización de rendimiento universal para máquinas Linux antiguas
# Compatible con Ubuntu, Linux Mint y otras distribuciones basadas en Ubuntu

# Variables de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/optimization.conf"
LOG_FILE="/var/log/system-optimization.log"
BACKUP_DIR="/etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)"

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

# Función para registrar mensajes
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Función para verificar privilegios de root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_message "ERROR" "Este script debe ejecutarse como root (sudo)"
        exit 1
    fi
}

# Función para detectar distribución
detect_distro() {
    log_message "INFO" "Detectando distribución..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$NAME
        VERSION=$VERSION_ID
    else
        DISTRO="Desconocida"
        VERSION="Desconocida"
    fi
    log_message "INFO" "Distribución detectada: $DISTRO $VERSION"
}

# Función para hacer backup de configuraciones
backup_config() {
    log_message "INFO" "Creando backup de configuraciones en $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    cp /etc/sysctl.conf "$BACKUP_DIR/" 2>/dev/null || log_message "WARNING" "No se pudo hacer backup de sysctl.conf"
}

# Función para configurar parámetros del kernel
configure_kernel_params() {
    log_message "INFO" "1. Configurando parámetros del kernel para mejorar el rendimiento..."
    
    # Backup antes de modificar
    backup_config
    
    # Reducir el uso de swap
    log_message "INFO" "Configurando swappiness a $SWAPPINESS..."
    if grep -q "vm.swappiness" /etc/sysctl.conf; then
        sed -i "s/vm.swappiness=.*/vm.swappiness=$SWAPPINESS/" /etc/sysctl.conf
    else
        echo "vm.swappiness=$SWAPPINESS" >> /etc/sysctl.conf
    fi
    
    if sysctl -w "vm.swappiness=$SWAPPINESS" >/dev/null 2>&1; then
        log_message "INFO" "Swappiness configurado correctamente"
    else
        log_message "ERROR" "Error al configurar swappiness"
    fi

    # Aumentar la presión de caché VFS para liberar memoria más rápidamente
    log_message "INFO" "Configurando vfs_cache_pressure a $VFS_CACHE_PRESSURE..."
    if grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        sed -i "s/vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=$VFS_CACHE_PRESSURE/" /etc/sysctl.conf
    else
        echo "vm.vfs_cache_pressure=$VFS_CACHE_PRESSURE" >> /etc/sysctl.conf
    fi
    
    if sysctl -w "vm.vfs_cache_pressure=$VFS_CACHE_PRESSURE" >/dev/null 2>&1; then
        log_message "INFO" "vfs_cache_pressure configurado correctamente"
    else
        log_message "ERROR" "Error al configurar vfs_cache_pressure"
    fi

    # Mejorar el comportamiento de la memoria virtual
    log_message "INFO" "Configurando dirty ratio..."
    if grep -q "vm.dirty_ratio" /etc/sysctl.conf; then
        sed -i "s/vm.dirty_ratio=.*/vm.dirty_ratio=$DIRTY_RATIO/" /etc/sysctl.conf
    else
        echo "vm.dirty_ratio=$DIRTY_RATIO" >> /etc/sysctl.conf
    fi
    
    if grep -q "vm.dirty_background_ratio" /etc/sysctl.conf; then
        sed -i "s/vm.dirty_background_ratio=.*/vm.dirty_background_ratio=$DIRTY_BACKGROUND_RATIO/" /etc/sysctl.conf
    else
        echo "vm.dirty_background_ratio=$DIRTY_BACKGROUND_RATIO" >> /etc/sysctl.conf
    fi
    
    if sysctl -w "vm.dirty_ratio=$DIRTY_RATIO" >/dev/null 2>&1 && sysctl -w "vm.dirty_background_ratio=$DIRTY_BACKGROUND_RATIO" >/dev/null 2>&1; then
        log_message "INFO" "Dirty ratios configurados correctamente"
    else
        log_message "ERROR" "Error al configurar dirty ratios"
    fi
}

# Función para optimizar el planificador de I/O
optimize_io_scheduler() {
    log_message "INFO" "2. Optimizando el planificador de I/O..."
    
    # Detectar dispositivos de bloque disponibles
    BLOCK_DEVICES=$(ls /sys/block/ 2>/dev/null | grep -E 'sd|nvme')
    if [ ! -z "$BLOCK_DEVICES" ]; then
        for device in $BLOCK_DEVICES; do
            if [ -f /sys/block/$device/queue/scheduler ]; then
                # Verificar si 'none' está disponible
                if grep -q "none" /sys/block/$device/queue/scheduler; then
                    if echo "none" > /sys/block/$device/queue/scheduler 2>/dev/null; then
                        log_message "INFO" "Planificador de I/O para $device cambiado a none"
                    else
                        log_message "WARNING" "No se pudo cambiar el planificador de I/O para $device"
                    fi
                else
                    # Usar el planificador por defecto
                    DEFAULT_SCHED=$(cat /sys/block/$device/queue/scheduler | grep -o "\[.*\]" | tr -d "[]")
                    log_message "INFO" "Usando planificador $DEFAULT_SCHED para $device (none no disponible)"
                fi
            fi
        done
        
        # Crear regla udev para persistencia
        if [ ! -f /etc/udev/rules.d/60-scheduler.rules ]; then
            if echo 'ACTION=="add|change", KERNEL=="sd[a-z]*|nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"' > /etc/udev/rules.d/60-scheduler.rules 2>/dev/null; then
                log_message "INFO" "Regla udev para persistencia de scheduler creada"
            else
                log_message "WARNING" "No se pudo crear regla udev para persistencia de scheduler"
            fi
        fi
    else
        log_message "INFO" "No se encontraron dispositivos de bloque para optimizar"
    fi
}

# Función para deshabilitar servicios innecesarios
disable_unnecessary_services() {
    log_message "INFO" "3. Deshabilitando servicios innecesarios..."
    
    # Usar servicios de la configuración
    for service in "${DISABLED_SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^$service"; then
            if systemctl is-active --quiet "$service"; then
                log_message "INFO" "Deshabilitando $service..."
                systemctl stop "$service" 2>/dev/null
                if systemctl disable "$service" 2>/dev/null; then
                    log_message "INFO" "$service deshabilitado correctamente"
                else
                    log_message "WARNING" "No se pudo deshabilitar $service"
                fi
            else
                log_message "INFO" "$service ya está inactivo"
            fi
        else
            log_message "DEBUG" "$service no está instalado en el sistema"
        fi
    done
}

# Función para configurar systemd
configure_systemd() {
    log_message "INFO" "4. Configurando systemd para reducir uso de recursos..."
    
    # Limitar recursos de systemd
    mkdir -p /etc/systemd/system.conf.d/
    if cat > /etc/systemd/system.conf.d/resource-control.conf << EOF
[Manager]
DefaultLimitNOFILE=8192
DefaultLimitNPROC=1024
EOF
    then
        log_message "INFO" "Configuración de systemd creada correctamente"
    else
        log_message "ERROR" "Error al crear configuración de systemd"
    fi
}

# Función para optimizar el gestor de inicio de sesión
optimize_login_manager() {
    log_message "INFO" "5. Optimizando el gestor de inicio de sesión..."
    
    # Detectar el gestor de inicio de sesión actual
    if [ -f /etc/lightdm/lightdm.conf ]; then
        log_message "INFO" "Configurando LightDM..."
        if ! grep -q "\[Seat:*\]" /etc/lightdm/lightdm.conf; then
            echo -e "\n[Seat:*]" >> /etc/lightdm/lightdm.conf
        fi
        
        if ! grep -q "greeter-hide-users" /etc/lightdm/lightdm.conf; then
            sed -i '/\[Seat:*\]/a greeter-hide-users=true' /etc/lightdm/lightdm.conf
        fi
        
        if ! grep -q "allow-guest" /etc/lightdm/lightdm.conf; then
            sed -i '/\[Seat:*\]/a allow-guest=false' /etc/lightdm/lightdm.conf
        fi
        log_message "INFO" "LightDM configurado correctamente"
        
    elif [ -f /etc/mdm/mdm.conf ]; then
        log_message "INFO" "Configurando MDM..."
        # Configuraciones básicas para MDM
        log_message "INFO" "MDM detectado (configuración básica aplicada)"
        
    elif [ -f /etc/gdm3/custom.conf ]; then
        log_message "INFO" "Configurando GDM..."
        # Configuraciones básicas para GDM
        log_message "INFO" "GDM detectado (configuración básica aplicada)"
        
    else
        log_message "INFO" "No se detectó un gestor de inicio de sesión conocido"
    fi
}

# Función para limpiar el sistema
clean_system() {
    log_message "INFO" "6. Limpiando el sistema..."
    
    # Limpiar paquetes innecesarios
    log_message "INFO" "Limpiando paquetes..."
    if apt-get autoremove -y >/dev/null 2>&1; then
        log_message "INFO" "Paquetes innecesarios eliminados"
    else
        log_message "WARNING" "Error al eliminar paquetes innecesarios"
    fi
    
    if apt-get autoclean -y >/dev/null 2>&1; then
        log_message "INFO" "Caché de paquetes limpiada"
    else
        log_message "WARNING" "Error al limpiar caché de paquetes"
    fi

    # Limpiar caché de thumbnails usando directorios de configuración
    for dir_pattern in "${THUMBNAIL_CLEANUP_DIRS[@]}"; do
        # Expandir patrones simples
        if [[ "$dir_pattern" == *"*"* ]]; then
            # Manejar patrones con *
            for dir in $dir_pattern; do
                if [ -d "$dir" ]; then
                    if rm -rf "$dir"/* 2>/dev/null; then
                        log_message "INFO" "Caché de thumbnails limpiada en $dir"
                    fi
                fi
            done
        else
            # Directorio específico
            if [ -d "$dir_pattern" ]; then
                if rm -rf "$dir_pattern"/* 2>/dev/null; then
                    log_message "INFO" "Caché de thumbnails limpiada en $dir_pattern"
                fi
            fi
        fi
    done
}

# Función para configurar zram
configure_zram() {
    log_message "INFO" "7. Configurando zram para mejorar el rendimiento de memoria..."
    
    # Verificar si zram-tools está instalado
    if ! command -v zramctl &> /dev/null; then
        log_message "INFO" "Instalando zram-tools..."
        if apt-get update >/dev/null 2>&1 && apt-get install -y zram-tools >/dev/null 2>&1; then
            log_message "INFO" "zram-tools instalado correctamente"
        else
            log_message "ERROR" "Error al instalar zram-tools"
            return 1
        fi
    fi

    # Configurar zram usando el porcentaje de la configuración
    if [ -f /etc/default/zramswap ]; then
        if grep -q "#PERCENTAGE=75" /etc/default/zramswap; then
            if sed -i "s/#PERCENTAGE=75/PERCENTAGE=$ZRAM_PERCENTAGE/" /etc/default/zramswap; then
                log_message "INFO" "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE"
            else
                log_message "ERROR" "Error al configurar zram"
            fi
        elif ! grep -q "PERCENTAGE=" /etc/default/zramswap; then
            if echo "PERCENTAGE=$ZRAM_PERCENTAGE" >> /etc/default/zramswap; then
                log_message "INFO" "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE"
            else
                log_message "ERROR" "Error al configurar zram"
            fi
        else
            log_message "INFO" "zram ya está configurado"
        fi
    else
        if echo "PERCENTAGE=$ZRAM_PERCENTAGE" > /etc/default/zramswap; then
            log_message "INFO" "zram configurado con PERCENTAGE=$ZRAM_PERCENTAGE"
        else
            log_message "ERROR" "Error al configurar zram"
        fi
    fi

    if systemctl enable zramswap >/dev/null 2>&1 && systemctl restart zramswap >/dev/null 2>&1; then
        log_message "INFO" "zramswap habilitado y reiniciado"
    else
        log_message "WARNING" "Error al habilitar o reiniciar zramswap"
    fi
}

# Función para crear script de mantenimiento de memoria
create_memory_maintenance_script() {
    log_message "INFO" "8. Creando script de mantenimiento de memoria..."
    
    # Crear script de mantenimiento de memoria
    if cat > /usr/local/bin/memory-maintenance.sh << 'EOF'
#!/bin/bash
# Script para liberar memoria no esencial

# Verificar que se ejecute como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# Registrar inicio
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando mantenimiento de memoria" >> /var/log/memory-maintenance.log

# Sincronizar discos
sync

# Liberar cachés del sistema en secuencia
for i in 1 2 3; do
    if echo $i > /proc/sys/vm/drop_caches 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] drop_caches=$i ejecutado" >> /var/log/memory-maintenance.log
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error al ejecutar drop_caches=$i" >> /var/log/memory-maintenance.log
    fi
    sleep 1
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mantenimiento de memoria completado" >> /var/log/memory-maintenance.log
EOF
    then
        if chmod +x /usr/local/bin/memory-maintenance.sh; then
            log_message "INFO" "Script de mantenimiento de memoria creado y permisos establecidos"
        else
            log_message "ERROR" "Error al establecer permisos del script de mantenimiento"
        fi
    else
        log_message "ERROR" "Error al crear script de mantenimiento de memoria"
    fi

    # Crear cron job para ejecutarlo cada hora
    if (crontab -l 2>/dev/null | grep -q "memory-maintenance.sh") || (echo "0 * * * * /usr/local/bin/memory-maintenance.sh" | crontab - 2>/dev/null); then
        log_message "INFO" "Cron job para mantenimiento de memoria configurado"
    else
        log_message "WARNING" "Error al configurar cron job para mantenimiento de memoria"
    fi
}

# Función principal
main() {
    echo "=== Script de Optimización de Rendimiento Universal ==="
    echo "Este script optimizará tu sistema para mejorar el rendimiento en una máquina con recursos limitados"
    echo ""
    
    # Inicializar log
    log_message "INFO" "=== INICIO DE OPTIMIZACIÓN DEL SISTEMA ==="
    
    # Cargar configuración
    load_config
    
    # Verificar privilegios
    check_root
    
    # Detectar distribución
    detect_distro
    
    echo ""
    echo "1. Configurando parámetros del kernel para mejorar el rendimiento..."
    configure_kernel_params
    
    echo ""
    echo "2. Optimizando el planificador de I/O..."
    optimize_io_scheduler
    
    echo ""
    echo "3. Deshabilitando servicios innecesarios..."
    disable_unnecessary_services
    
    echo ""
    echo "4. Configurando systemd para reducir uso de recursos..."
    configure_systemd
    
    echo ""
    echo "5. Optimizando el gestor de inicio de sesión..."
    optimize_login_manager
    
    echo ""
    echo "6. Limpiando el sistema..."
    clean_system
    
    echo ""
    echo "7. Configurando zram para mejorar el rendimiento de memoria..."
    configure_zram
    
    echo ""
    echo "8. Creando script de mantenimiento de memoria..."
    create_memory_maintenance_script
    
    echo ""
    echo "=== Optimización completada ==="
    echo ""
    echo "Resumen de cambios realizados:"
    echo "- Se redujo el uso de swap (swappiness=10)"
    echo "- Se ajustó la presión de caché VFS"
    echo "- Se deshabilitaron servicios innecesarios"
    echo "- Se configuró zram para mejorar la memoria virtual"
    echo "- Se creó un script de mantenimiento de memoria"
    echo ""
    echo "Para aplicar todos los cambios completamente, por favor reinicia el sistema:"
    echo "sudo reboot"
    echo ""
    echo "Para ejecutar manualmente el mantenimiento de memoria en cualquier momento:"
    echo "sudo /usr/local/bin/memory-maintenance.sh"
    
    log_message "INFO" "=== FIN DE OPTIMIZACIÓN DEL SISTEMA ==="
}

# Ejecutar función principal
main "$@"