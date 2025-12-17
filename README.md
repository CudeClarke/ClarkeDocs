# Scripts para el despliegue del back-end

Para la instalación del back-end, es necesario un sistema Linux con Java 22, Maven, y una base de datos. Este script usa una base de datos mysql.

Para ejecutar el script se debe copiar a la raiz del proyecto (mismo directorio que el pom.xml del back-end). Recordar dar los permisos de ejecución necesarios a los scripts con `chmod +x install.sh` y `chmod +x update.sh`

Ejecutar el script install.sh primero: `./install.sh`. El script crea el archivo de servicio clarke_api.service y lo configura automáticamente.

Para actualizar el proyecto se usa el script de despliegue con `./deploy.sh`. El script deploy.sh necesita que se haya ejecutado anteriormente el script de instalación, ya que requiere del usuario y archivo de servicio creados en la instalación.

# Instalación

``` bash
git clone https://github.com/CudeClarke/ClarkeAPI.git
cd ClarkeAPI
./install.sh
```

# Actualización

``` bash
./update.sh
```
