#!/bin/bash
set -e

# --- CONFIGURACIÓN DE VARIABLES ---
API_USER="clarke"
API_GROUP="clarke"
DEPLOY_DIR="/opt/ClarkeAPI"
SERVICE_NAME="clarke_api"
JAR_NAME="ClarkeAPI.jar"
PROJECT_ROOT="$(pwd)"
REQUIRED_JAVA_VERSION="22"
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

echo "--- 1. INICIANDO SCRIPT DE DESPLIEGUE PARA ${SERVICE_NAME} ---"

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
  echo "ERROR: La versión de Java instalada es v${JAVA_VERSION}. Se requiere Java v${REQUIRED_JAVA_VERSION} para la compilación."
  exit 1
fi
echo "    - Java v${JAVA_VERSION} detectado. Requisito cumplido."

echo "--- 2. Compilando el proyecto..."
echo "    - Ejecutando mvn clean package..."
cd "${PROJECT_ROOT}"
mvn clean package

JAR_SOURCE="${PROJECT_ROOT}/target/${JAR_NAME}"

if [ ! -f "$JAR_SOURCE" ]; then
  echo "ERROR: El archivo JAR '${JAR_NAME}' no se encontró en target/. ¿Falló la compilación?"
  exit 1
fi

echo "--- 3. Deteniendo el servicio ${SERVICE_NAME}..."
if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
  sudo systemctl stop "${SERVICE_NAME}"
  echo "    - Servicio detenido."
else
  echo "    - El servicio no estaba activo. Continuamos con el despliegue."
fi

echo "--- 4. Desplegando el nuevo JAR y verificando permisos..."
echo "    - Moviendo ${JAR_NAME} a ${DEPLOY_DIR}..."
sudo mv "$JAR_SOURCE" "${DEPLOY_DIR}/${JAR_NAME}"

sudo chown "${API_USER}":"${API_GROUP}" "${DEPLOY_DIR}/${JAR_NAME}"
sudo chmod 600 "${DEPLOY_DIR}/${JAR_NAME}"
echo "    - Permisos asegurados para ${API_USER}:${API_GROUP}."

echo "--- 5. Reiniciando el servicio..."
sudo systemctl start "${SERVICE_NAME}"
sleep 5

echo "--- SCRIPT DE DESPLIEGUE FINALIZADO ---"
