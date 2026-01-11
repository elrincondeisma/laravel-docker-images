#!/bin/bash

# ==================================================
# Build & Push Multi-Arch Laravel Image (Local)
# ==================================================

set -e

# Configuración
IMAGE_NAME="elrincondeisma/laravel-docker-images"
PLATFORMS="linux/amd64,linux/arm64"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ==================================================
# Parsear argumentos
# ==================================================
PUSH=false
TAG="latest"

while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --help|-h)
            echo "Uso: ./build.sh [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --push       Subir imagen a Docker Hub después de construir"
            echo "  --tag TAG    Tag adicional para la imagen (default: latest)"
            echo "  --help       Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  ./build.sh                    # Solo construir localmente"
            echo "  ./build.sh --push             # Construir y subir"
            echo "  ./build.sh --push --tag v1.0  # Construir y subir con tag v1.0"
            exit 0
            ;;
        *)
            print_error "Opción desconocida: $1"
            exit 1
            ;;
    esac
done

# ==================================================
# Verificar Docker
# ==================================================
print_step "Verificando Docker..."

if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon no está corriendo"
    exit 1
fi

print_success "Docker disponible"

# ==================================================
# Configurar Buildx
# ==================================================
print_step "Configurando Docker Buildx..."

BUILDER_NAME="multiarch-builder"

# Verificar si el builder existe
if ! docker buildx inspect "$BUILDER_NAME" &> /dev/null; then
    print_warning "Creando nuevo builder multi-arquitectura..."
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
fi

docker buildx use "$BUILDER_NAME"
print_success "Buildx configurado: $BUILDER_NAME"

# ==================================================
# Login Docker Hub (solo si --push)
# ==================================================
if [ "$PUSH" = true ]; then
    print_step "Verificando login en Docker Hub..."
    
    # Intentar un pull para verificar si hay sesión activa
    if ! docker pull hello-world &> /dev/null; then
        print_warning "Necesitas hacer login en Docker Hub"
        docker login
    fi
    
    print_success "Sesión de Docker Hub activa"
fi

# ==================================================
# Generar tags
# ==================================================
print_step "Preparando tags..."

GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TAGS="-t ${IMAGE_NAME}:latest -t ${IMAGE_NAME}:sha-${GIT_SHA}"

if [ "$TAG" != "latest" ]; then
    TAGS="$TAGS -t ${IMAGE_NAME}:${TAG}"
fi

echo "  Tags a generar:"
echo "    - ${IMAGE_NAME}:latest"
echo "    - ${IMAGE_NAME}:sha-${GIT_SHA}"
if [ "$TAG" != "latest" ]; then
    echo "    - ${IMAGE_NAME}:${TAG}"
fi

# ==================================================
# Build
# ==================================================
print_step "Construyendo imagen multi-arquitectura..."
echo "  Plataformas: $PLATFORMS"

BUILD_CMD="docker buildx build --platform $PLATFORMS $TAGS"

if [ "$PUSH" = true ]; then
    BUILD_CMD="$BUILD_CMD --push"
    echo "  Modo: Build + Push"
else
    BUILD_CMD="$BUILD_CMD --load"
    echo "  Modo: Build local (sin push)"
    # Para --load solo podemos construir para una plataforma
    CURRENT_ARCH=$(uname -m)
    if [ "$CURRENT_ARCH" = "arm64" ] || [ "$CURRENT_ARCH" = "aarch64" ]; then
        PLATFORM="linux/arm64"
    else
        PLATFORM="linux/amd64"
    fi
    BUILD_CMD="docker buildx build --platform $PLATFORM $TAGS --load"
    print_warning "Build local solo para $PLATFORM (usa --push para multi-arch)"
fi

BUILD_CMD="$BUILD_CMD ."

echo ""
echo "Ejecutando: $BUILD_CMD"
echo ""

eval $BUILD_CMD

# ==================================================
# Resultado
# ==================================================
echo ""
if [ "$PUSH" = true ]; then
    print_success "¡Imagen construida y subida a Docker Hub!"
    echo ""
    echo "Puedes usar la imagen con:"
    echo "  docker pull ${IMAGE_NAME}:latest"
else
    print_success "¡Imagen construida localmente!"
    echo ""
    echo "Para subir a Docker Hub, ejecuta:"
    echo "  ./build.sh --push"
fi
