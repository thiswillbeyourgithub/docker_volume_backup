# Docker Volume Backup Script

A shell script for safely backing up Docker container volumes. The script automatically handles stopping and restarting containers as needed during the backup process.

## Features

- Automatically stops and restarts containers during backup
- Creates timestamped backups of all volumes
- Moves previous backups to trash instead of deleting them
- Verbose logging option
- System logging integration
- Handles multiple volumes per container

## Prerequisites

- Docker
- sudo access
- `trash-cli` package for safe file deletion
- ZSH shell

## Installation

1. Clone this repository
2. Make the script executable:
   ```bash
   chmod +x docker_volume_backup.sh
   ```

## Usage

```bash
./docker_volume_backup.sh --output-dir DIR [--verbose] CONTAINER_NAME
```

### Options

- `--output-dir DIR`: Directory where backups will be stored
- `--verbose`: Enable verbose logging
- `CONTAINER_NAME`: Name of the Docker container to backup

### Example

```bash
./docker_volume_backup.sh --output-dir /path/to/backups --verbose my-container
```

## Backup Structure

Backups are organized as follows:
```
output-dir/
└── container-name/
    └── volume-name/
        └── YYYYMMDD_HHMMSS.tar.gz
```

## Error Handling

- Validates container existence and running state
- Ensures output directory exists
- Handles backup failures gracefully
- Automatically restores container state on error

## Logging

- Uses system logger (via `logger`)
- Optional verbose console output
- Timestamps all log messages

## License

MIT License
