# System Optimizer for Legacy/Linux Mint
 
         Este conjunto de scripts está diseñado para optimizar el rendimiento de máquinas Linux antiguas o con
      recursos limitados, especialmente Ubuntu, Linux Mint y otras distribuciones basadas en Ubuntu.
 
## Características Principales
 
*   **Ajuste de parámetros del kernel:** Swappiness, cache pressure, dirty ratios.
*   **Configuración de zram:** Mejora el rendimiento de la memoria virtual comprimida.
*   **Deshabilitación de servicios innecesarios:** Reduce el consumo de recursos.
*   **Limpieza del sistema:** Elimina paquetes y cachés no esenciales.
*   **Mantenimiento de memoria:** Incluye script y cron job para liberar cachés.
*   **Registro detallado:** Todos los cambios se registran en `/var/log/`.
 
## Archivos Incluidos
 
*   `optimize-universal.sh`: Script principal de optimización completa.
*   `optimize-menu-universal.sh`: Versión con interfaz de menú para selección de optimizaciones específicas.
    `optimization.conf`: Archivo de configuración para personalizar los parámetros.
 
## Uso
 
1.  Clona o descarga el repositorio.
2.  Haz los scripts ejecutables: `chmod +x optimize-*.sh`
3.  Revisa `optimization.conf` y ajusta los parámetros si es necesario.
4.  Ejecuta la optimización completa (requiere `sudo`):
              sudo ./optimize-universal.sh

5.  O usa la interfaz de menú: `./optimize-menu-universal.sh`
 
## Personalización
 
    Edita `optimization.conf` para ajustar parámetros como `swappiness`, `zram_percentage`, y los servicios
    a deshabilitar.

## Autor

*	**Marco Andre Yunge**    
 
 
## Notas Importantes
 
*   Se recomienda reiniciar el sistema después de aplicar las optimizaciones.
*   Los scripts realizan cambios en la configuración del sistema. Siempre hay un backup.


