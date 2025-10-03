#!/bin/bash
set -e

IMAGE_NAME="${1:-odoo-custom}"
IMAGE_TAG="${2:-v0.0.2}"
REGISTRY="registry.vultur-code.vpn:30013"

if [ -n "$REGISTRY" ]; then
    FULL_IMAGE="$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
else
    FULL_IMAGE="$IMAGE_NAME:$IMAGE_TAG"
fi

echo "🐳 Building Docker image: $FULL_IMAGE"
docker build -t "$FULL_IMAGE" .

echo "✅ Build completato!"
echo ""
if [ -n "$REGISTRY" ]; then
    echo "Per pushare l'immagine:"
    echo "  docker push $FULL_IMAGE"
else
    echo "Immagine locale: $FULL_IMAGE"
    echo "Per pushare, definisci DOCKER_REGISTRY nel .env"
fi
