#!/bin/bash

# Zsh History Validation and Backup Script
# Safely decompresses, validates, and manages zsh history files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default settings
BACKUP_CURRENT=true
VALIDATE_ONLY=false
DECOMPRESS_ALL=false
TARGET_FILE=""
BACKUP_DIR="."
TEMP_DIR="/tmp/zsh_validation_$$"

usage() {
    echo "Usage: $0 [OPTIONS] [FILE]"
    echo ""
    echo "Safely decompress, validate, and backup zsh history files"
    echo ""
    echo "Options:"
    echo "  -f, --file FILE     Specific .gz file to decompress and validate"
    echo "  -a, --all           Decompress and validate ALL .gz files"
    echo "  -v, --validate-only Only validate without decompressing"
    echo "  -n, --no-backup     Skip backing up current ~/.zsh_history"
    echo "  -d, --dir DIR       Directory containing backup files (default: current)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Backup current history and validate setup"
    echo "  $0 -f zsh_history_2023_01_01.bak.gz  # Decompress and validate specific file"
    echo "  $0 -a                                 # Decompress and validate ALL compressed files"
    echo "  $0 -v                                 # Only validate current history without changes"
    echo ""
    echo "Safety features:"
    echo "  • Automatically backs up ~/.zsh_history before any operations"
    echo "  • Creates temporary files for validation"
    echo "  • Validates zsh extended_history format"
    echo "  • Reports file statistics and potential issues"
    echo "  • Preserves original compressed files"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            TARGET_FILE="$2"
            shift 2
            ;;
        -a|--all)
            DECOMPRESS_ALL=true
            shift
            ;;
        -v|--validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -n|--no-backup)
            BACKUP_CURRENT=false
            shift
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$TARGET_FILE" && "$1" == *.gz ]]; then
                TARGET_FILE="$1"
                shift
            else
                echo "Unknown option: $1"
                usage
                exit 1
            fi
            ;;
    esac
done

# Create temporary directory
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Function to backup current zsh history
backup_current_history() {
    if [ "$BACKUP_CURRENT" = true ] && [ -f ~/.zsh_history ]; then
        local backup_name="zsh_history_backup_$(date +%Y_%m_%d_%H_%M_%S).bak"
        cp ~/.zsh_history "$BACKUP_DIR/$backup_name"
        echo -e "${GREEN}✓ Current ~/.zsh_history backed up as: $backup_name${NC}"
        return 0
    elif [ "$BACKUP_CURRENT" = true ]; then
        echo -e "${YELLOW}⚠ No ~/.zsh_history found to backup${NC}"
        return 1
    fi
}

# Function to validate zsh history format
validate_history_file() {
    local file="$1"
    local file_name=$(basename "$file")
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ File not found: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== Validating: $file_name ===${NC}"
    
    # Basic file stats
    local total_lines=$(wc -l < "$file")
    local file_size=$(ls -lh "$file" | awk '{print $5}')
    
    echo "File size: $file_size"
    echo "Total lines: $total_lines"
    
    if [ $total_lines -eq 0 ]; then
        echo -e "${RED}✗ File is empty${NC}"
        return 1
    fi
    
    # Check for extended_history format
    local extended_format=$(grep -c "^: [0-9]\{10,\}:[0-9]*;" "$file" 2>/dev/null || echo 0)
    local regular_commands=$(grep -v "^: [0-9]\{10,\}:[0-9]*;" "$file" | grep -c "^[^#]" 2>/dev/null || echo 0)
    local comments=$(grep -c "^#" "$file" 2>/dev/null || echo 0)
    local empty_lines=$(grep -c "^$" "$file" 2>/dev/null || echo 0)
    
    echo "Extended format entries: $extended_format"
    echo "Regular commands: $regular_commands"
    echo "Comments: $comments"
    echo "Empty lines: $empty_lines"
    
    # Validate format
    if [ $extended_format -gt 0 ]; then
        echo -e "${GREEN}✓ Extended history format detected${NC}"
        
        # Check for malformed entries
        local malformed=$(grep "^: [0-9]" "$file" | grep -v "^: [0-9]\{10,\}:[0-9]*;" | wc -l)
        if [ $malformed -gt 0 ]; then
            echo -e "${YELLOW}⚠ Found $malformed potentially malformed timestamp entries${NC}"
        fi
        
        # Sample valid entries
        echo -e "${BLUE}Sample entries:${NC}"
        grep "^: [0-9]\{10,\}:[0-9]*;" "$file" | head -3
        
        # Check for multiline commands
        local multiline=$(grep -c "\\\\" "$file" 2>/dev/null || echo 0)
        if [ $multiline -gt 0 ]; then
            echo -e "${PURPLE}ℹ Found $multiline lines with potential multiline commands${NC}"
        fi
        
    elif [ $regular_commands -gt 0 ]; then
        echo -e "${YELLOW}⚠ Regular format detected (no timestamps)${NC}"
        echo "First few commands:"
        grep "^[^#]" "$file" | head -3
    else
        echo -e "${RED}✗ No valid command entries found${NC}"
        return 1
    fi
    
    # Check for UTF-8 issues
    local utf8_issues=$(grep -c "�" "$file" 2>/dev/null || echo 0)
    if [ $utf8_issues -gt 0 ]; then
        echo -e "${YELLOW}⚠ Found $utf8_issues potential UTF-8 encoding issues${NC}"
    fi
    
    # Check timestamp range (if extended format)
    if [ $extended_format -gt 0 ]; then
        local first_timestamp=$(grep "^: [0-9]\{10,\}:[0-9]*;" "$file" | head -1 | sed 's/^: \([0-9]*\):.*/\1/')
        local last_timestamp=$(grep "^: [0-9]\{10,\}:[0-9]*;" "$file" | tail -1 | sed 's/^: \([0-9]*\):.*/\1/')
        
        if [ -n "$first_timestamp" ] && [ -n "$last_timestamp" ]; then
            local first_date=$(date -r "$first_timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Invalid")
            local last_date=$(date -r "$last_timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Invalid")
            echo "Time range: $first_date → $last_date"
        fi
    fi
    
    echo -e "${GREEN}✓ Validation completed${NC}"
    echo ""
    return 0
}

# Function to safely decompress a file
decompress_file() {
    local gz_file="$1"
    local output_file="$2"
    
    if [ ! -f "$gz_file" ]; then
        echo -e "${RED}✗ Compressed file not found: $gz_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Decompressing: $(basename "$gz_file")${NC}"
    
    # Test the compressed file first
    if ! gzip -t "$gz_file" 2>/dev/null; then
        echo -e "${RED}✗ Compressed file is corrupted: $gz_file${NC}"
        return 1
    fi
    
    # Decompress to temporary location first
    local temp_output="$TEMP_DIR/$(basename "$gz_file" .gz)"
    if gzip -dc "$gz_file" > "$temp_output" 2>/dev/null; then
        echo -e "${GREEN}✓ Successfully decompressed${NC}"
        
        # Validate the decompressed file
        if validate_history_file "$temp_output"; then
            # Move to final location if specified
            if [ -n "$output_file" ]; then
                cp "$temp_output" "$output_file"
                echo -e "${GREEN}✓ Decompressed file saved as: $output_file${NC}"
            fi
            return 0
        else
            echo -e "${RED}✗ Decompressed file failed validation${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to decompress file${NC}"
        return 1
    fi
}

# Main execution
cd "$BACKUP_DIR"

echo -e "${BLUE}=== Zsh History Validation and Backup Tool ===${NC}"
echo "Working directory: $(pwd)"
echo "Date: $(date)"
echo ""

# Backup current history first
backup_current_history

# Handle different modes
if [ "$VALIDATE_ONLY" = true ]; then
    echo -e "${BLUE}=== Validation Mode (No Changes) ===${NC}"
    if [ -f ~/.zsh_history ]; then
        validate_history_file ~/.zsh_history
    else
        echo -e "${YELLOW}No ~/.zsh_history found to validate${NC}"
    fi
    
elif [ "$DECOMPRESS_ALL" = true ]; then
    echo -e "${BLUE}=== Decompressing All Files ===${NC}"
    
    gz_files=($(find . -name "*.bak.gz" | sort))
    if [ ${#gz_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No .gz files found in current directory${NC}"
        exit 0
    fi
    
    echo "Found ${#gz_files[@]} compressed files to process"
    echo ""
    
    success_count=0
    for gz_file in "${gz_files[@]}"; do
        output_file="${gz_file%.gz}"
        if decompress_file "$gz_file" "$output_file"; then
            ((success_count++))
        fi
        echo ""
    done
    
    echo -e "${GREEN}Successfully processed: $success_count/${#gz_files[@]} files${NC}"
    
elif [ -n "$TARGET_FILE" ]; then
    echo -e "${BLUE}=== Processing Single File ===${NC}"
    
    if [[ "$TARGET_FILE" == *.gz ]]; then
        output_file="${TARGET_FILE%.gz}"
        decompress_file "$TARGET_FILE" "$output_file"
    else
        validate_history_file "$TARGET_FILE"
    fi
    
else
    echo -e "${BLUE}=== System Overview ===${NC}"
    
    # Show current status
    compressed_count=$(find . -name "*.bak.gz" | wc -l)
    uncompressed_count=$(find . -name "zsh_history_*.bak" | wc -l)
    
    echo "Compressed files (.gz): $compressed_count"
    echo "Uncompressed files (.bak): $uncompressed_count"
    echo ""
    
    # Validate current history if it exists
    if [ -f ~/.zsh_history ]; then
        validate_history_file ~/.zsh_history
    else
        echo -e "${YELLOW}No ~/.zsh_history found${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Usage suggestions:${NC}"
    echo "• To decompress a specific file: $0 -f filename.bak.gz"
    echo "• To decompress all files: $0 -a"
    echo "• To validate without changes: $0 -v"
fi

echo ""
echo -e "${GREEN}Operation completed. Your original files are preserved.${NC}"