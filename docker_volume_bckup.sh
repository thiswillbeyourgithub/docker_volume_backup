#!/bin/zsh

# Parse arguments
VERBOSE=0
CONTAINER_NAME=""
OUTPUT_DIR=""

print_usage() {
    echo "Usage: $0 --output-dir DIR [--verbose] CONTAINER_NAME"
    echo "Options:"
    echo "  --output-dir DIR    Directory where backups will be stored"
    echo "  --verbose           Enable verbose logging"
    echo "  CONTAINER_NAME      Name of the Docker container to backup"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=1
            shift
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            print_usage
            ;;
        *)
            CONTAINER_NAME="$1"
            shift
            ;;
    esac
done

if [[ -z "$CONTAINER_NAME" ]]; then
    echo "Error: Container name is required"
    print_usage
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory is required (use --output-dir)"
    print_usage
fi

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# Logging function
log() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}


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
        
        # Move previous backup to trash if it exists
        if ls "${backup_dir}"/*.tar.gz >/dev/null 2>&1; then
            log "Moving previous backup to trash"
            trash "${backup_dir}"/*.tar.gz
        fi
        
        log "Creating backup of volume $volume_name"
        log "Source path: $volume_path"
        log "Destination: $backup_file"
        
        sudo tar -czf "$backup_file" -C "$volume_path" .
        
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
