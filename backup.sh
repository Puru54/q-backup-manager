#!/bin/bash

# Colors
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

LOG_FILE="backup.log"
BACKUP_DIR="./backups"
DRY_RUN=false

print_usage() {
    echo -e "Usage: $0 [--full] [--project DIR] [--dry-run]"
}

log() {
    local level=$1
    local message=$2
    local color=$3
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${color}${level}${NC}] $message" | tee -a "$LOG_FILE"
}

full_backup() {
    local target="full-$(date '+%Y%m%d_%H%M%S').tar.gz"
    log "INFO" "Starting full system backup..." $YELLOW
    if $DRY_RUN; then
        log "DRYRUN" "Would archive entire system to $BACKUP_DIR/$target" $YELLOW
    else
        sudo tar -czf "$BACKUP_DIR/$target" /etc /home /var
        log "INFO" "Backup saved to $BACKUP_DIR/$target" $GREEN
    fi
}

project_backup() {
    local dir=$1
    local name=$(basename "$dir")
    local target="${name}-$(date '+%Y%m%d_%H%M%S').tar.gz"
    log "INFO" "Backing up project directory $dir" $YELLOW
    if $DRY_RUN; then
        log "DRYRUN" "Would archive $dir to $BACKUP_DIR/$target" $YELLOW
    else
        tar -czf "$BACKUP_DIR/$target" "$dir"
        log "INFO" "Backup saved to $BACKUP_DIR/$target" $GREEN
    fi
}

mkdir -p "$BACKUP_DIR"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --full) MODE="full";;
        --project) MODE="project"; PROJECT_DIR="$2"; shift;;
        --dry-run) DRY_RUN=true;;
        -h|--help) print_usage; exit 0;;
        *) echo "Unknown parameter: $1"; print_usage; exit 1;;
    esac
    shift
done

if [[ "$MODE" == "full" ]]; then
    full_backup
elif [[ "$MODE" == "project" && -n "$PROJECT_DIR" ]]; then
    project_backup "$PROJECT_DIR"
else
    prit_usage
    exit 1
fi
