Procedimiento redimencionar el disco

    Abrir la ventana de Comandos CMD
    Irnos al directorio donde tengamos instalado virtual box
    Debemos localizar el disco duro (vdi) de nuestra máquina virtual
    Ejecutar el comando Vboxmanage.exe con los siguientes parámetros
        Primer parámetro: Tipo de comando –> modifyHD (modificar el tamaño del disco duro)
        Ruta del disco Duro Virtual (VDI) entre comillas (en mi caso mi disco duro se llama “W7 WebDev.vdi”
        Tipo de Modificación que queramos hacer –> –resize
        Por último el nuevo tamaño que queramos asignarle –> en mi caso 35Gb (35000)

vboxmanage.exe modifyhd "D:\VirtualBox\W7 WebDev.vdi" --resize 35000