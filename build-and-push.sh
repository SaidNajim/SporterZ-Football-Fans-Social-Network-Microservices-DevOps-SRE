#!/bin/bash

set -e

DOCKER_USERNAME="mrxmoon"
IMAGE_PREFIX="sporterz"
VERSION="latest"
BUILD_JAR=false

if [[ "$1" == "--build" || "$1" == "-b" ]]; then
    BUILD_JAR=true
fi

SERVICES=(
    "auth-service"
    "posts-service"
    "match-service"
    "messaging-service"
    "api-gateway"
)

echo "=========================================="
echo "Build and Push Script"
echo "=========================================="
echo "Docker Hub: ${DOCKER_USERNAME}"
echo "Build JAR: ${BUILD_JAR}"
echo "=========================================="
echo ""
echo "Usage: ./build-and-push.sh [--build|-b]"
echo "  (no args)   : Use existing JAR files"
echo "  --build, -b : Build JARs with Maven first"
echo ""

if ! command -v docker &> /dev/null; then
    echo "Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "Docker daemon is not running or user not in docker group"
    exit 1
fi

echo "Logging in to Docker Hub..."
docker login || exit 1

for service in "${SERVICES[@]}"; do
    echo ""
    echo "=========================================="
    echo "Processing: ${service}"
    echo "=========================================="

    cd "${service}"

    if [ "$BUILD_JAR" = true ]; then
        echo "Building JAR with Maven..."
        if command -v mvn &> /dev/null; then
            mvn clean package -DskipTests
        else
            echo "Maven not found. Skipping ${service}."
            cd ..
            continue
        fi
    else
        echo "Using existing JAR file..."
        if ! ls target/*.jar 1> /dev/null 2>&1; then
            echo "No JAR file found in target/. Please build first or use --build flag."
            cd ..
            continue
        fi
    fi

    echo "Building Docker image..."
    IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_PREFIX}-${service}:${VERSION}"

    docker build -t "${IMAGE_NAME}" .

    echo "Pushing to Docker Hub..."
    docker push "${IMAGE_NAME}"

    echo "Done: ${IMAGE_NAME}"

    cd ..
done

echo ""
echo "=========================================="
echo "All images built and pushed!"
echo "=========================================="
echo ""
echo "Images:"
for service in "${SERVICES[@]}"; do
    echo "  ${DOCKER_USERNAME}/${IMAGE_PREFIX}-${service}:${VERSION}"
done
