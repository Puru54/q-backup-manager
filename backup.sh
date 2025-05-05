#!/bin/bash

# Colors
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

# Configuration
LOG_FILE="backup.log"
BACKUP_DIR="./backups"
RETENTION_DAYS=30
COMPRESSION_LEVEL=6
DRY_RUN=false
VERIFY_BACKUP=false

print_usage() {
    echo -e "Usage: $0 [OPTIONS]"
    echo -e "Options:"
    echo -e "  --full                Perform a full system backup"
    echo -e "  --project DIR         Backup a specific project directory"
    echo -e "  --dry-run             Show what would be done without making changes"
    echo -e "  --verify              Verify backup integrity after creation"
    echo -e "  --compression LEVEL   Set compression level (1-9, default: 6)"
    echo -e "  --retention DAYS      Number of days to keep backups (default: 30)"
    echo -e "  --incremental         Perform an incremental backup (requires previous full backup)"
    echo -e "  -h, --help            Show this help message"
}

log() {
    local level=$1
    local message=$2
    local color=$3
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${color}${level}${NC}] $message" | tee -a "$LOG_FILE"
}

check_dependencies() {
    local missing=false
    for cmd in tar rsync find; do
        if ! command -v $cmd &> /dev/null; then
            log "ERROR" "Required command '$cmd' not found" $RED
            missing=true
        fi
    done
    
    if $missing; then
        log "ERROR" "Please install missing dependencies and try again" $RED
        exit 1
    fi
}

check_disk_space() {
    local dir=$1
    local required_space=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    local available_space=$(df -B1 "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    
    if [[ $required_space -gt $available_space ]]; then
        log "ERROR" "Not enough disk space. Required: $(numfmt --to=iec $required_space), Available: $(numfmt --to=iec $available_space)" $RED
        return 1
    fi
    
    log "INFO" "Sufficient disk space available" $GREEN
    return 0
}

check_permissions() {
    local dir=$1
    if [[ ! -r "$dir" ]]; then
        log "ERROR" "No read permission for $dir" $RED
        return 1
    fi
    return 0
}

verify_backup() {
    local backup_file=$1
    log "INFO" "Verifying backup integrity: $backup_file" $BLUE
    
    if tar -tzf "$backup_file" &>/dev/null; then
        log "INFO" "Backup verification successful" $GREEN
        return 0
    else
        log "ERROR" "Backup verification failed" $RED
        return 1
    fi
}

cleanup_old_backups() {
    log "INFO" "Cleaning up backups older than $RETENTION_DAYS days" $BLUE
    if $DRY_RUN; then
        log "DRYRUN" "Would delete backups older than $RETENTION_DAYS days" $YELLOW
        find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -exec echo "Would delete: {}" \;
    else
        find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -exec rm {} \; -exec echo "Deleted: {}" \;
        log "INFO" "Cleanup completed" $GREEN
    fi
}

full_backup() {
    local target="full-$(date '+%Y%m%d_%H%M%S').tar.gz"
    log "INFO" "Starting full system backup..." $YELLOW
    
    # Check permissions for critical directories
    local dirs_to_backup=("/etc" "/home" "/var")
    local permission_error=false
    
    for dir in "${dirs_to_backup[@]}"; do
        if ! check_permissions "$dir"; then
            permission_error=true
        fi
    done
    
    if $permission_error; then
        log "ERROR" "Permission issues detected. Try running with sudo" $RED
        exit 1
    fi
    
    # Check disk space
    if ! check_disk_space "/etc /home /var"; then
        exit 1
    fi
    
    if $DRY_RUN; then
        log "DRYRUN" "Would archive entire system to $BACKUP_DIR/$target" $YELLOW
    else
        log "INFO" "Creating backup with compression level $COMPRESSION_LEVEL" $BLUE
        tar -cz --checkpoint=.1000 -f "$BACKUP_DIR/$target" /etc /home /var 2>/dev/null || {
            log "ERROR" "Backup failed" $RED
            exit 1
        }
        echo "" # New line after progress dots
        log "INFO" "Backup saved to $BACKUP_DIR/$target" $GREEN
        
        if $VERIFY_BACKUP; then
            verify_backup "$BACKUP_DIR/$target"
        fi
    fi
}

project_backup() {
    local dir=$1
    
    # Validate directory exists
    if [[ ! -d "$dir" ]]; then
        log "ERROR" "Project directory does not exist: $dir" $RED
        exit 1
    fi
    
    # Check permissions
    if ! check_permissions "$dir"; then
        exit 1
    fi
    
    # Check disk space
    if ! check_disk_space "$dir"; then
        exit 1
    fi
    
    local name=$(basename "$dir")
    local target="${name}-$(date '+%Y%m%d_%H%M%S').tar.gz"
    log "INFO" "Backing up project directory $dir" $YELLOW
    
    if $DRY_RUN; then
        log "DRYRUN" "Would archive $dir to $BACKUP_DIR/$target" $YELLOW
    else
        log "INFO" "Creating backup with compression level $COMPRESSION_LEVEL" $BLUE
        tar -cz --checkpoint=.1000 -f "$BACKUP_DIR/$target" "$dir" 2>/dev/null || {
            log "ERROR" "Backup failed" $RED
            exit 1
        }
        echo "" # New line after progress dots
        log "INFO" "Backup saved to $BACKUP_DIR/$target" $GREEN
        
        if $VERIFY_BACKUP; then
            verify_backup "$BACKUP_DIR/$target"
        fi
    fi
}

incremental_backup() {
    local dir=$1
    local name=$(basename "$dir")
    local snapshot_file="$BACKUP_DIR/${name}-snapshot"
    local target="${name}-incr-$(date '+%Y%m%d_%H%M%S').tar.gz"
    
    # Check if snapshot exists
    if [[ ! -f "$snapshot_file" && ! $DRY_RUN ]]; then
        log "ERROR" "No previous snapshot found. Run a full backup first" $RED
        exit 1
    fi
    
    log "INFO" "Starting incremental backup of $dir" $YELLOW
    
    if $DRY_RUN; then
        log "DRYRUN" "Would create incremental backup to $BACKUP_DIR/$target" $YELLOW
    else
        log "INFO" "Creating incremental backup with compression level $COMPRESSION_LEVEL" $BLUE
        tar --create --gzip --verbose --listed-incremental="$snapshot_file" \
            --file="$BACKUP_DIR/$target" "$dir" 2>/dev/null || {
            log "ERROR" "Incremental backup failed" $RED
            exit 1
        }
        log "INFO" "Incremental backup saved to $BACKUP_DIR/$target" $GREEN
        
        if $VERIFY_BACKUP; then
            verify_backup "$BACKUP_DIR/$target"
        fi
    fi
}

# Main execution starts here
check_dependencies
mkdir -p "$BACKUP_DIR"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --full) MODE="full";;
        --project) MODE="project"; PROJECT_DIR="$2"; shift;;
        --incremental) MODE="incremental"; PROJECT_DIR="$2"; shift;;
        --dry-run) DRY_RUN=true;;
        --verify) VERIFY_BACKUP=true;;
        --compression) COMPRESSION_LEVEL="$2"; shift;;
        --retention) RETENTION_DAYS="$2"; shift;;
        -h|--help) print_usage; exit 0;;
        *) echo "Unknown parameter: $1"; print_usage; exit 1;;
    esac
    shift
done

# Execute the appropriate backup mode
if [[ "$MODE" == "full" ]]; then
    full_backup
elif [[ "$MODE" == "project" && -n "$PROJECT_DIR" ]]; then
    project_backup "$PROJECT_DIR"
elif [[ "$MODE" == "incremental" && -n "$PROJECT_DIR" ]]; then
    incremental_backup "$PROJECT_DIR"
else
    print_usage
    exit 1
fi

# Clean up old backups
cleanup_old_backups
