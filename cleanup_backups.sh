#!/bin/bash

# Cleanup Script for Zsh History Backup Management
# Helps manage decompressed files and temporary backups

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
DRY_RUN=false
REMOVE_DECOMPRESSED=false
REMOVE_TEMP_BACKUPS=false
REMOVE_OLD_BACKUPS=false
DAYS_OLD=30
INTERACTIVE=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Cleanup decompressed files and temporary backups"
    echo ""
    echo "Options:"
    echo "  -d, --decompressed    Remove decompressed .bak files that have .gz versions"
    echo "  -t, --temp-backups    Remove temporary backup files (zsh_history_backup_*)"
    echo "  -o, --old-backups     Remove old backup files older than specified days"
    echo "  -a, --all             Clean up everything (decompressed + temp + old)"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -n, --dry-run         Show what would be deleted without doing it"
    echo "  --days DAYS           Days old for backup cleanup (default: 30)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d                 # Remove decompressed files that have .gz versions"
    echo "  $0 -t -y              # Remove temp backups without confirmation"
    echo "  $0 -a -n              # Dry run showing all cleanup operations"
    echo "  $0 -o --days 7        # Remove backup files older than 7 days"
    echo ""
    echo "Safety notes:"
    echo "  • Always keeps .gz files (compressed originals)"
    echo "  • Asks for confirmation unless -y is used"
    echo "  • Use -n for dry runs to see what would be affected"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--decompressed)
            REMOVE_DECOMPRESSED=true
            shift
            ;;
        -t|--temp-backups)
            REMOVE_TEMP_BACKUPS=true
            shift
            ;;
        -o|--old-backups)
            REMOVE_OLD_BACKUPS=true
            shift
            ;;
        -a|--all)
            REMOVE_DECOMPRESSED=true
            REMOVE_TEMP_BACKUPS=true
            REMOVE_OLD_BACKUPS=true
            shift
            ;;
        -y|--yes)
            INTERACTIVE=false
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --days)
            DAYS_OLD="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# If no options specified, show usage
if [ "$REMOVE_DECOMPRESSED" = false ] && [ "$REMOVE_TEMP_BACKUPS" = false ] && [ "$REMOVE_OLD_BACKUPS" = false ]; then
    usage
    exit 1
fi

echo -e "${BLUE}=== Zsh History Backup Cleanup ===${NC}"
echo "Working directory: $(pwd)"
echo "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "ACTUAL CLEANUP")"
echo ""

# Function to confirm action
confirm_action() {
    local message="$1"
    if [ "$INTERACTIVE" = true ] && [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}$message${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            return 1
        fi
    fi
    return 0
}

# Clean up decompressed files
if [ "$REMOVE_DECOMPRESSED" = true ]; then
    echo -e "${BLUE}=== Cleaning Up Decompressed Files ===${NC}"
    
    # Find .bak files that have corresponding .gz files
    decompressed_files=()
    while IFS= read -r -d '' bak_file; do
        gz_file="${bak_file}.gz"
        if [ -f "$gz_file" ]; then
            decompressed_files+=("$bak_file")
        fi
    done < <(find . -name "zsh_history_*.bak" -print0 2>/dev/null || true)
    
    if [ ${#decompressed_files[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No decompressed files to clean up${NC}"
    else
        echo "Found ${#decompressed_files[@]} decompressed files with .gz versions:"
        for file in "${decompressed_files[@]}"; do
            echo "  - $(basename "$file")"
        done
        echo ""
        
        if confirm_action "Remove these decompressed files?"; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY RUN] Would remove ${#decompressed_files[@]} files${NC}"
            else
                for file in "${decompressed_files[@]}"; do
                    rm "$file"
                    echo -e "${GREEN}✓ Removed: $(basename "$file")${NC}"
                done
            fi
        fi
    fi
    echo ""
fi

# Clean up temporary backup files
if [ "$REMOVE_TEMP_BACKUPS" = true ]; then
    echo -e "${BLUE}=== Cleaning Up Temporary Backup Files ===${NC}"
    
    temp_backups=($(find . -name "zsh_history_backup_*.bak" 2>/dev/null || true))
    
    if [ ${#temp_backups[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No temporary backup files to clean up${NC}"
    else
        echo "Found ${#temp_backups[@]} temporary backup files:"
        for file in "${temp_backups[@]}"; do
            echo "  - $(basename "$file") ($(ls -lh "$file" | awk '{print $5}'))"
        done
        echo ""
        
        if confirm_action "Remove these temporary backup files?"; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY RUN] Would remove ${#temp_backups[@]} files${NC}"
            else
                for file in "${temp_backups[@]}"; do
                    rm "$file"
                    echo -e "${GREEN}✓ Removed: $(basename "$file")${NC}"
                done
            fi
        fi
    fi
    echo ""
fi

# Clean up old backup files
if [ "$REMOVE_OLD_BACKUPS" = true ]; then
    echo -e "${BLUE}=== Cleaning Up Old Backup Files ===${NC}"
    echo "Looking for files older than $DAYS_OLD days..."
    
    old_backups=($(find . -name "zsh_history_*.bak" -mtime +$DAYS_OLD 2>/dev/null || true))
    
    if [ ${#old_backups[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No old backup files to clean up${NC}"
    else
        echo "Found ${#old_backups[@]} old backup files:"
        for file in "${old_backups[@]}"; do
            local file_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null || echo "unknown")
            echo "  - $(basename "$file") ($file_date, $(ls -lh "$file" | awk '{print $5}'))"
        done
        echo ""
        
        echo -e "${YELLOW}⚠ WARNING: This will permanently delete old backup files!${NC}"
        echo -e "${YELLOW}⚠ Make sure you have compressed versions (.gz) if needed${NC}"
        
        if confirm_action "Remove these old backup files?"; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY RUN] Would remove ${#old_backups[@]} files${NC}"
            else
                for file in "${old_backups[@]}"; do
                    rm "$file"
                    echo -e "${GREEN}✓ Removed: $(basename "$file")${NC}"
                done
            fi
        fi
    fi
    echo ""
fi

# Show final statistics
echo -e "${BLUE}=== Final Status ===${NC}"
compressed_count=$(find . -name "*.bak.gz" | wc -l)
uncompressed_count=$(find . -name "zsh_history_*.bak" | wc -l)
temp_count=$(find . -name "zsh_history_backup_*.bak" | wc -l)

echo "Compressed files (.gz): $compressed_count"
echo "Uncompressed files (.bak): $uncompressed_count"
echo "Temporary backups: $temp_count"

if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}Cleanup completed!${NC}"
else
    echo -e "${YELLOW}Dry run completed. Use without -n to perform actual cleanup.${NC}"
fi