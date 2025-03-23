#!/bin/bash

BACKUP_DIR="/mnt/internal2/backup"
VOLUMES=("homeassistant_data" "node_red_data" "portainer_data")
KEEP_BACKUPS_COUNT=10

BACKUP_STATUS=0

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >&2
}


mkdir -p "$BACKUP_DIR"

# Check available space
AVAILABLE_SPACE=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 1048576 ]; then  # Check if less than 1GB available
    log_error "Less than 1GB space available in backup directory!"
    exit 1
fi

# Perform backups for each volume
DATE=$(date +%Y%m%d)
for volume in "${VOLUMES[@]}"; do
    BACKUP_FILE="${volume}_backup_${DATE}.tar.gz"
    
    # Check if volume exists
    if ! docker volume inspect "$volume" >/dev/null 2>&1; then
        log_warning "Docker volume $volume does not exist, skipping..."
        BACKUP_STATUS=1
        continue
    fi

    # create backup
    log_info "Starting backup of $volume..."
    if docker run --rm --mount "source=${volume},target=/data" -v "${BACKUP_DIR}:/backup" busybox tar -czvf "/backup/${BACKUP_FILE}" /data; then
        log_info "Backup completed successfully: ${BACKUP_FILE}"
    else
        log_error "Backup failed for ${volume}!"
    fi

    #cleanup old backups
    if ls "${BACKUP_DIR}/${volume}_backup_"*.tar.gz >/dev/null 2>&1; then
        cd "$BACKUP_DIR" && ls -t "${volume}_backup_"*.tar.gz | tail -n "+$KEEP_BACKUPS_COUNT" | xargs rm -f
        log_info "Keeping latest $((KEEP_BACKUPS_COUNT-1)) backups for $volume"
    fi

done

if [ $BACKUP_STATUS -eq 0 ]; then
    log_info "All backups completed successfully!"
else
    log_info "Backup process completed with some warnings/errors. Check log for details."
fi

exit $BACKUP_STATUS
