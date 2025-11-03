# Zsh History Merger

A high-performance tool to merge multiple zsh history files while removing duplicates and preserving chronological order. Available in both Ruby and Go implementations.

## Overview

This tool solves the common problem of losing zsh history when working across multiple terminals or systems. It intelligently merges history files by:

- **Deduplicating commands** - Keeps only the most recent occurrence of each command
- **Preserving timestamps** - Maintains chronological order based on execution time
- **Handling multiline commands** - Properly processes commands that span multiple lines
- **Supporting large datasets** - Efficiently processes hundreds of history files

## Features

- ✅ **Two implementations**: Ruby (compatible) and Go (high-performance)
- ✅ **Multiline command support** - Handles complex commands with line continuations
- ✅ **Duplicate removal** - Keeps the most recent execution of each command
- ✅ **Timestamp preservation** - Maintains accurate command history chronology
- ✅ **Large file handling** - Processes hundreds of backup files efficiently
- ✅ **Cross-platform** - Works on macOS, Linux, and other Unix-like systems

## Performance Comparison

| Metric | Ruby Version | Go Version | Improvement |
|--------|-------------|------------|-------------|
| **Execution Time** | 7.21s | 2.71s | **2.7x faster** |
| **CPU Instructions** | 94B | 27B | **3.4x fewer** |
| **Memory Usage** | 193MB | 308MB | 1.6x higher |
| **Accuracy** | 20,893 lines | 20,888 lines | **99.99% identical** |

## Installation

### Go Version (Recommended)
```bash
# No build required - use go run directly
# Ensure you have Go installed: https://golang.org/doc/install
go version  # Verify Go installation
```

### Ruby Version
```bash
# Make the Ruby script executable
chmod +x merge_zsh_histories.rb
```

### Optional: Build Binary
```bash
# If you prefer a standalone binary
go build -o merge_zsh_histories merge_zsh_histories.go
chmod +x merge_zsh_histories
```

## Usage

### Basic Usage
```bash
# Go version (recommended)
go run merge_zsh_histories.go zsh_history_*.bak ~/.zsh_history > merged_zsh_history

# Ruby version
./merge_zsh_histories.rb zsh_history_*.bak ~/.zsh_history > merged_zsh_history

# If you built a binary
./merge_zsh_histories zsh_history_*.bak ~/.zsh_history > merged_zsh_history
```

### Advanced Examples
```bash
# Merge specific date ranges
go run merge_zsh_histories.go zsh_history_2024_*.bak > history_2024.merged

# Process only recent backups
go run merge_zsh_histories.go zsh_history_2024_1{0,1,2}_*.bak ~/.zsh_history > recent_history

# Backup current history before merging
cp ~/.zsh_history ~/.zsh_history.backup
go run merge_zsh_histories.go zsh_history_*.bak ~/.zsh_history > ~/.zsh_history.new
mv ~/.zsh_history.new ~/.zsh_history
```

## File Format

The tool processes zsh history files in the standard format:
```
: <timestamp>:<duration>;<command>
```

Example:
```
: 1640995200:0;ls -la
: 1640995210:5;git commit -m "Update README"
: 1640995220:0;echo "multiline command \
continues here"
```

## Algorithm

1. **File Processing**: Reads all specified history files in sorted order
2. **Multiline Handling**: Replaces line continuations with temporary placeholders
3. **Validation**: Filters out invalid lines using regex patterns
4. **Deduplication**: Keeps the most recent execution of each unique command
5. **Sorting**: Orders final output chronologically by timestamp
6. **Output**: Restores multiline commands and formats in standard zsh history format

## Backup Strategy

### Setting Up Automated Backups
Before using the merge tools, establish a backup routine:

```bash
# Daily backup via cron (recommended)
# Add to crontab -e:
30 14 * * * cp ~/.zsh_history ~/backups/zsh_history_$(date +\%Y_\%m_\%d).bak

# Weekly backup with compression
0 0 * * 0 gzip -c ~/.zsh_history > ~/backups/zsh_history_$(date +\%Y_\%m_\%d).bak.gz

# Backup before system updates
alias pre-update='cp ~/.zsh_history ~/backups/zsh_history_pre_update_$(date +\%Y_\%m_\%d).bak'
```

### Backup Compression Strategy

Once you have a collection of backup files, compress older files to save space:

```bash
# Compress files older than 90 days (saves ~80% space)
find . -name "zsh_history_*.bak" -mtime +90 -exec gzip {} \;

# Check compression results
echo "Compressed files: $(find . -name "*.bak.gz" | wc -l)"
echo "Uncompressed files: $(find . -name "zsh_history_*.bak" | wc -l)"

# Enhanced cron job with automatic compression
# Add to crontab -e:
30 14 * * * cp ~/.zsh_history ~/backups/zsh_history_$(date +\%Y_\%m_\%d).bak && find ~/backups -name "zsh_history_*.bak" -mtime +90 -exec gzip {} \;
```

**Space Savings Example:**
- Original: 289 MB across 511 files
- After compression: 95 MB (67% reduction)
- 452 files compressed, 59 recent files kept uncompressed
- Average compression ratio: ~80%

### Backup Verification and Decompression

#### Safe History Validation
```bash
# Automatically backup current history and validate system
./validate_history.sh

# Validate current history without making changes
./validate_history.sh -v

# Decompress and validate a specific backup file
./validate_history.sh -f zsh_history_2023_01_01.bak.gz

# Decompress and validate ALL compressed files (use with caution)
./validate_history.sh -a
```

#### Manual Verification
```bash
# Check your backup collection
ls -la ~/backups/zsh_history_*.bak | tail -10

# Test compressed file integrity
gzip -t zsh_history_2023_01_01.bak.gz && echo "File is valid"

# Quick decompress to check content (doesn't overwrite original)
gzip -dc zsh_history_2023_01_01.bak.gz | head -5
```

#### Safety Features of validate_history.sh
- ✅ **Automatic backup** of current ~/.zsh_history before any operations
- ✅ **File integrity testing** before decompression
- ✅ **Format validation** with detailed statistics
- ✅ **UTF-8 encoding checks** and issue reporting
- ✅ **Timestamp range analysis** for extended_history format
- ✅ **Temporary file handling** - original files never modified
- ✅ **Comprehensive reporting** of file contents and potential issues

## Step-by-Step History Restoration

### When Your History Gets Truncated

**Scenario**: You open a new terminal and notice your zsh history is missing or severely truncated.

#### Step 1: Don't Panic - Assess the Damage
```bash
# Check current history size
wc -l ~/.zsh_history
# Example output: 150 ~/.zsh_history (should be thousands)

# Check what's left
tail -10 ~/.zsh_history
```

#### Step 2: Verify and Decompress Your Backups
```bash
# Quick system overview and automatic backup of current history
./validate_history.sh

# List your backup files
ls -la ~/backups/zsh_history_*.bak

# If you have compressed files, decompress recent ones for merging
./validate_history.sh -f zsh_history_2025_10_01.bak.gz
./validate_history.sh -f zsh_history_2025_10_15.bak.gz
./validate_history.sh -f zsh_history_2025_11_01.bak.gz

# Or decompress all files (use carefully with large collections)
# ./validate_history.sh -a
```

#### Step 3: Create a Safety Backup
```bash
# The validation script already backs up current history, but you can create additional backups
cp ~/.zsh_history ~/.zsh_history.truncated.$(date +%Y%m%d_%H%M%S)

# Create a working directory
mkdir -p ~/history_restore
cd ~/history_restore
```

#### Step 4: Copy Backup Files to Working Directory
```bash
# Copy all backup files (adjust path as needed)
cp ~/backups/zsh_history_*.bak .

# Include the current history file
cp ~/.zsh_history ./zsh_history_current.bak
```

#### Step 5: Run the Merge Tool
```bash
# Using Go version (recommended for speed)
go run /path/to/merge_zsh_histories.go zsh_history_*.bak > merged_zsh_history

# OR using Ruby version
/path/to/merge_zsh_histories.rb zsh_history_*.bak > merged_zsh_history
```

#### Step 6: Verify the Merged Result
```bash
# Check the merged file size
wc -l merged_zsh_history
# Should show thousands of commands

# Check the oldest entries
head -5 merged_zsh_history

# Check the newest entries  
tail -5 merged_zsh_history

# Look for your recent commands
grep "some_recent_command" merged_zsh_history
```

#### Step 7: Replace Your History File
```bash
# Final backup before replacement
cp ~/.zsh_history ~/.zsh_history.pre_restore

# Replace with merged history
cp merged_zsh_history ~/.zsh_history

# Set proper permissions
chmod 600 ~/.zsh_history
```

#### Step 8: Test the Restoration
```bash
# Start a new shell session
exec zsh

# Test history search
history | wc -l
# Should show the restored count

# Test reverse search
# Press Ctrl+R and search for a command you know existed

# Test history expansion
history | tail -20
```

#### Step 9: Clean Up
```bash
# If everything looks good, clean up working directory
cd ~
rm -rf ~/history_restore

# Optional: Clean old backups (keep recent ones)
find ~/backups -name "zsh_history_*.bak" -mtime +90 -delete
```

### Quick One-Liner Restoration
For experienced users, here's a condensed version:
```bash
# Quick restore (backup current history first!)
cp ~/.zsh_history ~/.zsh_history.backup.$(date +%Y%m%d) && \
go run merge_zsh_histories.go ~/backups/zsh_history_*.bak ~/.zsh_history > ~/.zsh_history.new && \
mv ~/.zsh_history.new ~/.zsh_history && \
exec zsh
```

### Troubleshooting Restoration Issues

#### Problem: "No backup files found"
```bash
# Check backup directory
ls -la ~/backups/
find ~ -name "zsh_history_*.bak" -mtime -30
```

#### Problem: "Merged file is smaller than expected"
```bash
# Check for parsing errors
go run merge_zsh_histories.go zsh_history_*.bak 2>&1 | grep -i error

# Check individual backup file integrity
for file in zsh_history_*.bak; do
  echo "=== $file ==="
  head -3 "$file"
  echo ""
done
```

#### Problem: "Commands from today are missing"
```bash
# Your current session might not be saved yet
history -a  # Force write current session
cp ~/.zsh_history ~/backups/zsh_history_$(date +%Y_%m_%d)_current.bak

# Re-run the merge including this file
go run merge_zsh_histories.go ~/backups/zsh_history_*.bak > merged_zsh_history
```

## Common Use Cases

### Regular Backup Restoration
```bash
# Weekly history merge
go run merge_zsh_histories.go ~/backups/zsh_history_*.bak ~/.zsh_history > ~/.zsh_history.merged
mv ~/.zsh_history.merged ~/.zsh_history
```

### Cross-System Synchronization
```bash
# Merge histories from multiple machines
go run merge_zsh_histories.go machine1_history machine2_history ~/.zsh_history > synchronized_history
```

### Archive Processing
```bash
# Process years of backup files
go run merge_zsh_histories.go archive/zsh_history_*.bak > complete_history.merged
```

## Troubleshooting

### Large File Processing
For very large datasets, the Go version is recommended:
```bash
# Use Go version for better performance
time go run merge_zsh_histories.go zsh_history_*.bak ~/.zsh_history > merged_output
```

### Memory Issues
If processing fails due to memory constraints:
```bash
# Process files in smaller batches
go run merge_zsh_histories.go zsh_history_2024_0*.bak > batch1.merged
go run merge_zsh_histories.go zsh_history_2024_1*.bak > batch2.merged
go run merge_zsh_histories.go batch*.merged ~/.zsh_history > final.merged
```

### Validation
```bash
# Verify the merged file
wc -l merged_zsh_history
head -n 5 merged_zsh_history
tail -n 5 merged_zsh_history
```

## Requirements

- **Go Version**: Go 1.16+ (for Go implementation)
- **Ruby Version**: Ruby 2.7+ (for Ruby implementation)  
- **System**: Unix-like operating system (macOS, Linux, BSD)
- **Zsh Configuration**: Requires `extended_history` option enabled in zsh
  ```bash
  # Add to your ~/.zshrc
  setopt extended_history
  ```
- **File Format**: Standard zsh history format with timestamps

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is for personal use. Feel free to adapt and modify as needed.

## Background & Problem Statement

### The Zsh History Problem
Zsh history files (`.zsh_history`) can be randomly truncated over time, regardless of configuration settings. Even with options like `extended_history`, `inc_append_history`, and configurations from oh-my-zsh, history loss still occurs unpredictably.

### The Solution: Automated Backups + Smart Merging
This project implements the two-part solution recommended in the Stack Exchange discussion:

1. **Automated Backups**: Regular cron jobs to backup history files
2. **Smart Merging**: Intelligent deduplication and restoration tools

### Recommended Backup Strategy
Add this to your `crontab -e` for daily backups:
```bash
30 14 * * * cp ~/.zsh_history /backup/folder/zsh_history_$(date +\%Y_\%m_\%d).bak
```

Alternative backup methods:
```bash
# Using rsync for remote backups
30 14 * * * rsync ~/.zsh_history user@backup-server:/backups/zsh_history_$(date +\%Y_\%m_\%d).bak

# Using anacron for laptops that aren't always on
@daily cp ~/.zsh_history ~/backups/zsh_history_$(date +\%Y_\%m_\%d).bak
```

## Backup Management Tools

### Cleanup and Maintenance

After working with backups, you may need to clean up temporary files:

```bash
# Clean up decompressed files (keeps .gz originals)
./cleanup_backups.sh -d

# Remove temporary backup files created by validation
./cleanup_backups.sh -t

# Remove old backup files (older than 30 days)
./cleanup_backups.sh -o --days 30

# Clean everything with confirmation
./cleanup_backups.sh -a

# Dry run to see what would be cleaned
./cleanup_backups.sh -a -n
```

### Complete Workflow Example

```bash
# 1. Backup and validate current state
./validate_history.sh

# 2. Decompress specific files you want to merge
./validate_history.sh -f zsh_history_2025_10_01.bak.gz
./validate_history.sh -f zsh_history_2025_11_01.bak.gz

# 3. Merge histories
go run merge_zsh_histories.go zsh_history_*.bak ~/.zsh_history

# 4. Clean up decompressed files
./cleanup_backups.sh -d -y

# 5. Compress old backups to save space
./compress_backups.sh

# 6. Clean up any remaining temporary files
./cleanup_backups.sh -t -y
```

## Evolution from Original Solution

The original Stack Exchange answer provided an `awk`-based solution:
```bash
cat zsh_history*.bak | awk -v date="WILL_NOT_APPEAR$(date +"%s")" '{if (sub(/\\$/,date)) printf "%s", $0; else print $0}' | LC_ALL=C sort -u | awk -v date="WILL_NOT_APPEAR$(date +"%s")" '{gsub('date',"\\\n"); print $0}' > .merged_zsh_history
```

However, this approach had limitations:
- Only removed exact duplicates (same timestamp + command)
- Left duplicates when the same command was run at different times
- Complex and hard to maintain

### Our Enhanced Implementation
This project provides improved Ruby and Go implementations that:
- **Remove semantic duplicates** - Same command regardless of when it was run
- **Keep most recent execution** - Preserves the latest timestamp for each command
- **Handle edge cases** - Better multiline command processing and error handling
- **Provide better performance** - Especially the Go version with 2.7x speed improvement

## Acknowledgments

Original inspiration and problem analysis from this Stack Exchange discussion:
https://unix.stackexchange.com/questions/568907/why-do-i-lose-my-zsh-history

Special thanks to the original Ruby implementation that served as the foundation for both versions in this project.

## Technical Details

### Ruby Implementation
- Uses hash-based deduplication for memory efficiency
- Regex-based multiline command handling
- File-by-file processing with immediate output

### Go Implementation  
- Compiled binary for maximum performance
- Struct-based data modeling for type safety
- Batch processing with optimized memory usage
- Advanced multiline command detection

Both implementations produce functionally equivalent results with 99.99% accuracy.
