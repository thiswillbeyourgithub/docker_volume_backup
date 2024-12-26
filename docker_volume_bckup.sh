#!/bin/zsh

# Directory where backups will be stored
OUTPUT_DIR="${HOME}/docker_volume_backups"

# Parse arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 [--verbose] CONTAINER_NAME"
    exit 1
fi

VERBOSE=0
CONTAINER_NAME=""

for arg in "$@"; do
    case $arg in
        --verbose)
            VERBOSE=1
            ;;
        *)
            CONTAINER_NAME=$arg
            ;;
    esac
done

if [[ -z "$CONTAINER_NAME" ]]; then
    echo "Error: Container name is required"
    exit 1
fi

# Logging function
log() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get volume information for the container
log "Getting volume information for container: $CONTAINER_NAME"
volumes=$(docker inspect -f '{{range .Mounts}}{{.Name}}:{{.Source}}{{"\n"}}{{end}}' "$CONTAINER_NAME")

if [[ -z "$volumes" ]]; then
    echo "No volumes found for container $CONTAINER_NAME"
    exit 1
fi

# Create backups for each volume
echo "$volumes" | while IFS=: read -r volume_name volume_path; do
    if [[ -n "$volume_name" && -n "$volume_path" ]]; then
        backup_dir="${OUTPUT_DIR}/${volume_name}"
        mkdir -p "$backup_dir"
        
        timestamp=$(date '+%Y%m%d_%H%M%S')
        backup_file="${backup_dir}/${timestamp}.tar.gz"
        
        log "Creating backup of volume $volume_name"
        log "Source path: $volume_path"
        log "Destination: $backup_file"
        
        tar -czf "$backup_file" -C "$volume_path" .
        
        if [[ $? -eq 0 ]]; then
            echo "Successfully created backup: $backup_file"
        else
            echo "Error creating backup for volume: $volume_name"
        fi
    fi
done
