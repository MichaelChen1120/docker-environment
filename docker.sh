#!/bin/bash

# Docker container management script

# Default Configuration
DEFAULT_IMAGE_NAME="aoc2026-env"
DEFAULT_CONTAINER_NAME="aoc2026-container"
DEFAULT_USERNAME="appuser"
DEFAULT_DOCKERFILE_PATH="dockerfile"

# Initialize variables with defaults
IMAGE_NAME="$DEFAULT_IMAGE_NAME"
CONTAINER_NAME="$DEFAULT_CONTAINER_NAME"
USERNAME="$DEFAULT_USERNAME"
DOCKERFILE_PATH="$DEFAULT_DOCKERFILE_PATH"
MOUNT_PATHS=()
action="run"

# Function to build Docker image
build_image() {
    # Check if its build(nocache = null) or rebuild(nocache = "nocache")
    local nocache="$1"
    # Check if image exists (inline)
    if [[ "$nocache" != "nocache" ]] && docker image ls | grep -q "$IMAGE_NAME"; then
        echo "Image '$IMAGE_NAME' already exists"
        return 1
    fi
    
    echo "Building image '$IMAGE_NAME'..."
    echo "Using Dockerfile: $DOCKERFILE_PATH"
    
    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        echo "Error: $DOCKERFILE_PATH not found in current directory"
        return 1
    fi
    
    # Build arguments
    local build_args=""
    if [[ "$nocache" == "nocache" ]]; then
        build_args="--no-cache"
        echo "Rebuild (no cache)"
    fi
    
    # Build the Docker image
    docker build $build_args --platform linux/arm64 \
        --build-arg USERNAME="$USERNAME" \
        -t "$IMAGE_NAME" \
        -f "$DOCKERFILE_PATH" .
    
    # Check build result
    if [ $? -eq 0 ]; then
        echo "Image '$IMAGE_NAME' built successfully!"
    else
        echo "Image '$IMAGE_NAME' build failed"
        return 1
    fi
}

# Function to run container (main container logic)
run_container() {
    # Check container status
    if docker ps | grep -q "$CONTAINER_NAME"; then
        # Container is running - enter it
        echo "Entering container '$CONTAINER_NAME'..."
        docker exec -it "$CONTAINER_NAME" /bin/bash
        
    elif docker ps -a | grep -q "$CONTAINER_NAME"; then
        # Container exists but stopped - start and enter
        docker start "$CONTAINER_NAME"
        if [ $? -eq 0 ]; then
            echo "Container started successfully, entering..."
            docker exec -it "$CONTAINER_NAME" /bin/bash
        else
            echo "Container '$CONTAINER_NAME' start failed"
            return 1
        fi
    else
        # Container does not exist - create new one
        # Check if image exists first
        if ! docker image ls | grep -q "$IMAGE_NAME"; then
            echo "Error: Image '$IMAGE_NAME' does not exist, please build image first"
            return 1
        fi
        # Build mount arguments
        local mount_args=""
        for mount_path in "${MOUNT_PATHS[@]}"; do
            if [[ "$mount_path" == *":"* ]]; then
                # Format: host_path:container_path
                IFS=':' read -r host_path container_path <<< "$mount_path"
            else
                # Only host path provided, use default container path
                host_path="$mount_path"
                container_path="/app/workspace"
            fi
            
            # Create host directory if it doesn't exist
            mkdir -p "$host_path"
            mount_args="$mount_args -v $(realpath "$host_path"):$container_path"
        done
        
        # Default mount if none specified
        if [ ${#MOUNT_PATHS[@]} -eq 0 ]; then
            mkdir -p "./workspace"
            mount_args="-v $(pwd)/workspace:/app/workspace"
        fi
        
        # Create and run container (removed --hostname parameter)
        docker run -it --name "$CONTAINER_NAME" \
            --user "$USERNAME" \
            $mount_args \
            "$IMAGE_NAME" /bin/bash
        
        if [ $? -ne 0 ]; then
            echo "Container '$CONTAINER_NAME' creation failed"
            return 1
        fi
    fi
}

# Help function
show_help() {
    echo "Docker Environment Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "    run              Run container (default action)"
    echo "    build            Build Docker image"
    echo "    stop             Stop container"
    echo "    clean            Clean container and image"
    echo "    rebuild          Rebuild Docker image (clean and rebuild)"
    echo "    help             Show this help message"
    echo ""
    echo "OPTIONS:"
    echo "    --image-name NAME      Specify image name (default: $DEFAULT_IMAGE_NAME)"
    echo "    --container-name NAME  Specify container name (default: $DEFAULT_CONTAINER_NAME)"
    echo "    --username NAME        Specify username (default: $DEFAULT_USERNAME)"
    echo "    --dockerfile PATH      Specify Dockerfile path (default: $DEFAULT_DOCKERFILE_PATH)"
    echo "    --mount PATH[:PATH]    Mount directory (can be used multiple times)"
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            run|build|stop|clean|rebuild|help)
                action="$1"
                shift
                ;;
            --image-name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --image-name requires a value"
                    exit 1
                fi
                IMAGE_NAME="$2"
                shift 2
                ;;
            --container-name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --container-name requires a value"
                    exit 1
                fi
                CONTAINER_NAME="$2"
                shift 2
                ;;
            --username)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --username requires a value"
                    exit 1
                fi
                USERNAME="$2"
                shift 2
                ;;
            --dockerfile)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --dockerfile requires a value"
                    exit 1
                fi
                DOCKERFILE_PATH="$2"
                shift 2
                ;;
            --mount)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --mount requires a path"
                    exit 1
                fi
                MOUNT_PATHS+=("$2")
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Error: Unknown option $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Execute based on action
    case $action in
        "build")
            build_image
            ;;
        "run")
            run_container
            ;;
        "stop")
            echo "Stopping container '$CONTAINER_NAME'..."
            if docker ps | grep -q "$CONTAINER_NAME"; then
                docker stop "$CONTAINER_NAME"
                if [ $? -eq 0 ]; then
                    echo "Container '$CONTAINER_NAME' stopped"
                else
                    echo "Container '$CONTAINER_NAME' stop failed"
                fi
            else
                echo "Container '$CONTAINER_NAME' is not running"
            fi
            ;;
        "clean")
            echo "Cleaning container and image..."
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
            docker rmi -f "$IMAGE_NAME" 2>/dev/null || true
            echo "Cleanup completed"
            ;;
        "rebuild")
            echo "Rebuilding image..."
            echo "Cleaning container and image..."
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
            docker rmi -f "$IMAGE_NAME" 2>/dev/null || true
            build_image nocache
            ;;
        "help")
            show_help
            ;;
        *)
            echo "Error: Unknown action $action"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
