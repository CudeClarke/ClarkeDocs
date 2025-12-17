#!/bin/bash
set -e

# --- CONFIGURACIÓN DE VARIABLES ---
API_USER="clarke"
API_GROUP="clarke"
DEPLOY_DIR="/opt/ClarkeAPI"
SERVICE_NAME="clarke_api"
JAR_NAME="ClarkeAPI.jar"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PROJECT_ROOT="$(pwd)"
REQUIRED_JAVA_VERSION="22"
DB_NAME="ClarkeDB"
DB_SETUP_SCRIPT="CudecaDB.sql"
# ----------------------------------

if [ "$EUID" -eq 0 ]; then
  echo " "
  echo "=========================================================================="
  echo "ERROR: Este script no debe ejecutarse directamente como root (con 'sudo')."
  echo "Por favor, ejecútalo como un usuario normal que tenga privilegios de sudo:"
  echo "    ./$(basename "$0")"
  echo "=========================================================================="
  echo " "
  exit 1
fi

echo "--- 1. INICIANDO SCRIPT DE INSTALACIÓN PARA ${SERVICE_NAME} ---"

echo "--- 1.1 Solicitando y verificando privilegios sudo..."
if ! sudo -v; then
  echo "ERROR: Falló la autenticación o no tienes privilegios de 'sudo'."
  exit 1
fi
echo "    - Privilegios sudo autenticados y cacheados."

echo "--- 1.2 Verificando dependencias..."
if ! command -v mvn &>/dev/null; then
  echo "ERROR: Maven (mvn) no está instalado. Por favor, instálalo y vuelve a intentarlo."
  exit 1
fi
echo "    - Maven (mvn) detectado."

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)

if [ "$JAVA_VERSION" != "$REQUIRED_JAVA_VERSION" ]; then
  echo "ERROR: La versión de Java instalada es v${JAVA_VERSION}. Se requiere Java v${REQUIRED_JAVA_VERSION} para compilar y ejecutar esta API."
  exit 1
fi
echo "    - Java v${JAVA_VERSION} detectado. Requisito cumplido."

echo "--- 2. CONFIGURACIÓN DE MYSQL ---"
if ! command -v mysql &>/dev/null; then
  echo "ERROR: El cliente MySQL (mysql) no está instalado. Por favor, instálalo y vuelve a intentarlo."
  exit 1
fi
echo "    - Cliente MySQL detectado."

DB_EXISTS=$(sudo mysql -s -N -e "SHOW DATABASES LIKE '${DB_NAME}';" 2>/dev/null)

if [ -z "$DB_EXISTS" ]; then
  echo "    - Base de datos '${DB_NAME}' no encontrada."
  echo "    - Intentando crear y configurar la base de datos usando ${DB_SETUP_SCRIPT}..."

  if [ ! -f "${PROJECT_ROOT}/${DB_SETUP_SCRIPT}" ]; then
    echo "ERROR: El archivo de configuración de la base de datos '${DB_SETUP_SCRIPT}' no se encontró en ${PROJECT_ROOT}."
    exit 1
  fi

  if sudo mysql <"${PROJECT_ROOT}/${DB_SETUP_SCRIPT}"; then
    echo "    - Base de datos '${DB_NAME}' configurada exitosamente."
  else
    echo "ERROR: Falló la ejecución del script SQL. Asegúrate de que MySQL esté configurado correctamente para que root pueda ejecutar comandos."
    exit 1
  fi
else
  echo "    - Base de datos '${DB_NAME}' ya existe. Saltando la configuración inicial."
fi

echo "--- 3. Creando usuario y grupo de sistema (${API_USER})..."

if ! getent group "${API_GROUP}" >/dev/null; then
  sudo addgroup --system "${API_GROUP}"
  echo "    - Grupo ${API_GROUP} creado."
fi

if ! getent passwd "${API_USER}" >/dev/null; then
  sudo adduser --system --no-create-home --shell /bin/false --ingroup "${API_GROUP}" "${API_USER}"
  echo "    - Usuario ${API_USER} creado."
else
  echo "    - Usuario ${API_USER} ya existe. Saltando la creación."
fi

echo "--- 4. Creando y asegurando el directorio de despliegue (${DEPLOY_DIR})..."

sudo mkdir -p "${DEPLOY_DIR}"
sudo chown -R "${API_USER}":"${API_GROUP}" "${DEPLOY_DIR}"
sudo chmod 700 "${DEPLOY_DIR}"
echo "    - Permisos configurados a ${API_USER}: ${API_GROUP}."

echo "--- 5. Creando el archivo de servicio (${SERVICE_FILE})..."

cat <<EOF | sudo tee "${SERVICE_FILE}" >/dev/null
[Unit]
Description=Clarke's Cudeca's API for ticketing service
After=network.target

[Service]
User=${API_USER}
Group=${API_GROUP}
ExecStart=/usr/bin/java -jar ${DEPLOY_DIR}/${JAR_NAME}
WorkingDirectory=${DEPLOY_DIR}/
Restart=always
RestartSec=10
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

echo "    - Archivo de servicio creado."

echo "--- 6. Recargando systemd y habilitando el servicio..."

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"

echo "    - Servicio habilitado."

echo "--- 7. Compilando y moviendo el JAR para el primer arranque..."

echo "    - Ejecutando mvn clean package..."
cd "${PROJECT_ROOT}"
mvn clean package

JAR_SOURCE="${PROJECT_ROOT}/target/${JAR_NAME}"

if [ ! -f "$JAR_SOURCE" ]; then
  echo "ERROR: El archivo JAR '${JAR_NAME}' no se encontró en target/. ¿Falló la compilación?"
  exit 1
fi

echo "    - Moviendo ${JAR_NAME} a ${DEPLOY_DIR}..."
sudo mv "$JAR_SOURCE" "${DEPLOY_DIR}/${JAR_NAME}"

echo "    - Iniciando el servicio ${SERVICE_NAME}..."
sudo systemctl start "${SERVICE_NAME}"

echo "--- SCRIPT DE INSTALACIÓN FINALIZADO Y SERVICIO INICIADO ---"
echo " "
echo "Verifique el estado con: sudo systemctl status ${SERVICE_NAME}"
echo "Recuerda usar ./deploy.sh para futuras actualizaciones."
