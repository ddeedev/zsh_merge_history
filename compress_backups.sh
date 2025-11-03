#!/bin/bash

# Zsh History Backup Compression Script
# Compresses backup files older than specified days to save disk space

set -e

# Default settings
DAYS_OLD=90
BACKUP_DIR="."
DRY_RUN=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Compress zsh history backup files older than specified days"
    echo ""
    echo "Options:"
    echo "  -d, --days DAYS     Files older than DAYS will be compressed (default: 90)"
    echo "  -p, --path PATH     Directory containing backup files (default: current)"
    echo "  -n, --dry-run       Show what would be compressed without doing it"
    echo "  -v, --verbose       Show detailed compression statistics"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Compress files older than 90 days"
    echo "  $0 -d 30            # Compress files older than 30 days"
    echo "  $0 -n -v            # Dry run with verbose output"
    echo "  $0 -p ~/backups     # Compress files in ~/backups directory"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--days)
            DAYS_OLD="$2"
            shift 2
            ;;
        -p|--path)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
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

# Validate directory
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Directory '$BACKUP_DIR' does not exist${NC}"
    exit 1
fi

cd "$BACKUP_DIR"

# Find files to compress
FILES_TO_COMPRESS=$(find . -name "zsh_history_*.bak" -mtime +$DAYS_OLD 2>/dev/null || true)
COMPRESSED_FILES=$(find . -name "*.bak.gz" 2>/dev/null | wc -l)
UNCOMPRESSED_FILES=$(find . -name "zsh_history_*.bak" 2>/dev/null | wc -l)

echo -e "${BLUE}=== Zsh History Backup Compression ===${NC}"
echo "Directory: $(pwd)"
echo "Compression threshold: Files older than $DAYS_OLD days"
echo ""

if [ -z "$FILES_TO_COMPRESS" ]; then
    echo -e "${GREEN}✓ No files found that are older than $DAYS_OLD days${NC}"
    echo "Current status:"
    echo "  - Compressed files (.gz): $COMPRESSED_FILES"
    echo "  - Uncompressed files (.bak): $UNCOMPRESSED_FILES"
    exit 0
fi

# Count files to compress
FILES_COUNT=$(echo "$FILES_TO_COMPRESS" | wc -l)

echo "Files to compress: $FILES_COUNT"
echo "Already compressed: $COMPRESSED_FILES"
echo "Will remain uncompressed: $((UNCOMPRESSED_FILES - FILES_COUNT))"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}=== DRY RUN - No files will be compressed ===${NC}"
    echo "Files that would be compressed:"
    echo "$FILES_TO_COMPRESS"
    echo ""
    echo "To actually compress, run without --dry-run flag"
    exit 0
fi

# Show space usage before compression
if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}=== Space Usage Before Compression ===${NC}"
    echo "Files to compress:"
    echo "$FILES_TO_COMPRESS" | head -5
    if [ $FILES_COUNT -gt 5 ]; then
        echo "... and $((FILES_COUNT - 5)) more files"
    fi
    echo ""
fi

# Perform compression
echo -e "${GREEN}Starting compression...${NC}"
echo ""

COMPRESSION_STATS=""
if [ "$VERBOSE" = true ]; then
    echo "$FILES_TO_COMPRESS" | xargs -I {} gzip -v {}
else
    echo "$FILES_TO_COMPRESS" | xargs -I {} gzip {}
fi

echo ""
echo -e "${GREEN}✓ Compression completed successfully!${NC}"
echo ""

# Show final statistics
FINAL_COMPRESSED=$(find . -name "*.bak.gz" 2>/dev/null | wc -l)
FINAL_UNCOMPRESSED=$(find . -name "zsh_history_*.bak" 2>/dev/null | wc -l)

echo -e "${BLUE}=== Final Status ===${NC}"
echo "Compressed files (.gz): $FINAL_COMPRESSED (+$FILES_COUNT)"
echo "Uncompressed files (.bak): $FINAL_UNCOMPRESSED"
echo ""

if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}=== Space Usage After Compression ===${NC}"
    COMPRESSED_SIZE=$(find . -name "*.bak.gz" -exec ls -l {} \; 2>/dev/null | awk '{sum += $5} END {printf "%.1f MB\n", sum/1024/1024}')
    UNCOMPRESSED_SIZE=$(find . -name "zsh_history_*.bak" -exec ls -l {} \; 2>/dev/null | awk '{sum += $5} END {printf "%.1f MB\n", sum/1024/1024}')
    TOTAL_SIZE=$(du -sm . 2>/dev/null | cut -f1)
    
    echo "Compressed files: $COMPRESSED_SIZE"
    echo "Uncompressed files: $UNCOMPRESSED_SIZE"
    echo "Total directory: ${TOTAL_SIZE} MB"
    echo ""
fi

echo -e "${GREEN}Tip: Set up a cron job to automate this process:${NC}"
echo "30 14 * * * $0 -p $(pwd)"