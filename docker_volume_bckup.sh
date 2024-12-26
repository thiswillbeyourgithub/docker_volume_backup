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

# Check if container is running
log "Checking container status"
container_status=$(sudo docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)
was_running=false

if [[ "$container_status" == "true" ]]; then
    log "Container is running, stopping it for backup"
    was_running=true
    sudo docker stop "$CONTAINER_NAME" >/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error stopping container $CONTAINER_NAME"
        exit 1
    fi
else
    log "Container is not running, proceeding with backup"
fi

# Get volume information for the container
log "Getting volume information for container: $CONTAINER_NAME"
volumes=$(sudo docker inspect -f '{{range .Mounts}}{{.Name}}:{{.Source}}{{"\n"}}{{end}}' "$CONTAINER_NAME")

if [[ -z "$volumes" ]]; then
    echo "No volumes found for container $CONTAINER_NAME"
    # Restart container if it was running before
    if [[ "$was_running" == "true" ]]; then
        log "Restarting container"
        sudo docker start "$CONTAINER_NAME" >/dev/null
    fi
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
            # Restart container if it was running before
            if [[ "$was_running" == "true" ]]; then
                log "Restarting container due to error"
                sudo docker start "$CONTAINER_NAME" >/dev/null
            fi
            exit 1
        fi
    fi
done

# Restart container if it was running before
if [[ "$was_running" == "true" ]]; then
    log "Restarting container after successful backup"
    sudo docker start "$CONTAINER_NAME" >/dev/null
fi
