#!/bin/bash

# CDR Archiver
# Author: Stanislav Rakitov
# Repository: https://github.com/SkyrocketStan/CDR-Archiver
#
# Description: This script automates the archiving of CDR (Call Detail Records) files.
# It groups files by month, compresses them into archives, and deletes the original files
# after successful archiving. Logs of all actions are saved in the `archive_log.txt` file.

# Default file pattern
file_pattern="cdr_*_*.csv"

# Function to display usage
usage() {
    echo "Usage:"
    echo "  $0 [--source-dir SOURCE_DIR] [--archive-dir ARCHIVE_DIR] [--pattern FILE_PATTERN]"
    echo "  $0 SOURCE_DIR ARCHIVE_DIR [FILE_PATTERN]"
    echo ""
    echo "Examples:"
    echo "  $0 --source-dir /path/to/source --archive-dir /path/to/archives --pattern 'cdr_*_*.csv'"
    echo "  $0 /path/to/source /path/to/archives 'cdr_*_*.csv'"
    exit 1
}

# Parse command-line arguments
if [[ "$1" == --* ]]; then
    # Named parameters mode
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source-dir)
                source_dir="$2"
                shift 2
                ;;
            --archive-dir)
                archive_dir="$2"
                shift 2
                ;;
            --pattern)
                file_pattern="$2"
                shift 2
                ;;
            --help)
                usage
                ;;
            *)
                echo "Unknown argument: $1"
                usage
                ;;
        esac
    done
else
    # Positional arguments mode
    if [[ $# -lt 2 ]]; then
        echo "Error: Source directory and archive directory must be specified."
        usage
    fi
    source_dir="$1"
    archive_dir="$2"
    file_pattern="${3:-cdr_*_*.csv}"  # Default pattern if not provided
fi

# Log file
log_file="$archive_dir/archive_log.txt"

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
}

# Check if source directory exists
if [ ! -d "$source_dir" ]; then
    log_message "Error: Source directory $source_dir does not exist."
    exit 1
fi

# Check if there are files to process
if [ -z "$(find "$source_dir" -type f -name "$file_pattern" -print -quit)" ]; then
    log_message "Error: No files matching the pattern '$file_pattern' found in $source_dir."
    exit 1
fi

# Create archive directory if it doesn't exist
if [ ! -d "$archive_dir" ]; then
    log_message "Archive directory $archive_dir does not exist. Creating..."
    mkdir -p "$archive_dir" || {
        log_message "Error: Failed to create archive directory $archive_dir."
        exit 1
    }
fi

# Check if archive directory is writable
if [ ! -w "$archive_dir" ]; then
    log_message "Error: Archive directory $archive_dir is not writable."
    exit 1
fi

# Function to check disk space
check_disk_space() {
    local required_space="$1"
    local available_space
    available_space=$(df -B1 "$archive_dir" | awk 'NR==2 {print $4}')

    if [ "$available_space" -lt "$required_space" ]; then
        log_message "Error: Not enough disk space. Required: $required_space bytes, available: $available_space bytes."
        exit 1
    fi
}

# Function to archive files
archive_files() {
    local month="$1"
    local files=("${@:2}")

    # Archive name based on folder name and month
    local folder_name=$(basename "$source_dir")
    local archive_name="${folder_name}_${month:0:4}_${month:4:2}.tar.gz"
    local archive_path="$archive_dir/$archive_name"

    # Calculate total size of files
    local total_size
    total_size=$(du -cb "${files[@]}" | grep total$ | awk '{print $1}')
    check_disk_space "$total_size"

    # Archive files
    if tar -czf "$archive_path" -C "$source_dir" "${files[@]}"; then
        log_message "Success: Created archive $archive_name with ${#files[@]} files."
        # Delete original files
        rm "${files[@]}"
    else
        log_message "Error: Failed to create archive $archive_name."
    fi
}

# Export functions for use with xargs
export -f archive_files log_message check_disk_space
export source_dir archive_dir log_file

# Group files by month and archive them
declare -A files_by_month
find "$source_dir" -type f -name "$file_pattern" -print0 | while IFS= read -r -d '' file; do
    # Extract year and month from the file name
    year_month=$(echo "$file" | awk -F'_' '{print substr($2, 1, 6)}')  # yyyymm

    # Add the file to the corresponding month's list
    files_by_month["$year_month"]+="$file"$'\n'
done

# Archive files for each month
for month in "${!files_by_month[@]}"; do
    # Convert the list of files into an array
    IFS=$'\n' read -r -d '' -a files <<< "${files_by_month[$month]}"

    # Archive the files
    archive_files "$month" "${files[@]}"
done

# Script completion
log_message "Script completed."
