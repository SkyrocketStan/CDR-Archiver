#!/bin/bash

# CDR Archiver (Optimized)
# Author: Stanislav Rakitov
# Repository: https://github.com/SkyrocketStan/CDR-Archiver
#
# Improvements:
# 1. Parallel processing with xargs
# 2. Enhanced error handling
# 3. Debug mode support
# 4. Standard Linux utilities only

# Default file pattern
file_pattern="cdr_*_*.csv"
debug_mode=0

# Function to display usage
usage() {
    echo "Usage:"
    echo "  $0 [--source-dir SOURCE_DIR] [--archive-dir ARCHIVE_DIR] [--pattern FILE_PATTERN] [--debug]"
    echo "  $0 SOURCE_DIR [ARCHIVE_DIR] [FILE_PATTERN] [--debug]"
    echo ""
    echo "Examples:"
    echo "  $0 --source-dir /data --archive-dir /archives --pattern 'cdr_*_*.csv' --debug"
    echo "  $0 /data /archives 'cdr_*_*.csv' --debug"
    exit 1
}

# Enhanced logging function (FIXED)
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="$timestamp - [$level] $message"
    
    echo "$log_entry" | tee -a "$log_file"
    
    # Corrected string comparison
    if [[ "$level" == "ERROR" ]] && [[ "$debug_mode" -eq 1 ]]; then
        echo "DEBUG - Stack trace:" | tee -a "$log_file"
        caller | tee -a "$log_file"
    fi
}

# Parse command-line arguments
positional_args=()
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
        --debug)
            debug_mode=1
            shift
            ;;
        --help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            positional_args+=("$1")
            shift
            ;;
    esac
done

# Handle positional arguments
if [[ ${#positional_args[@]} -gt 0 ]]; then
    source_dir="${positional_args[0]}"
    archive_dir="${positional_args[1]:-${source_dir}_archives}"
    file_pattern="${positional_args[2]:-cdr_*_*.csv}"
    [[ " ${positional_args[@]} " =~ " --debug " ]] && debug_mode=1
fi

# Validate mandatory arguments
if [[ -z "$source_dir" ]]; then
    echo "Error: Source directory must be specified."
    usage
fi

# Initialize log file
log_file="${archive_dir}/archive_log.txt"
mkdir -p "$archive_dir" || { echo "Failed to create archive directory"; exit 1; }

# Debug mode initialization
if [[ "$debug_mode" -eq 1 ]]; then
    log_message "DEBUG" "Debug mode enabled"
    set -x
fi

# Main processing function
process_month() {
    local month="$1"
    local folder_name=$(basename "$source_dir")
    local archive_name="${folder_name}_${month:0:4}_${month:4:2}.tar.gz"
    local archive_path="$archive_dir/$archive_name"
    
    log_message "INFO" "Processing month: $month"
    
    # Create temporary file list
    local tmp_file=$(mktemp)
    find "$source_dir" -type f -name "$file_pattern" -printf "%f\n" | 
        awk -F'_' -v month="$month" '$2 ~ "^"month' > "$tmp_file"
    
    # Check if files exist
    if [[ ! -s "$tmp_file" ]]; then
        log_message "WARNING" "No files found for month $month"
        rm "$tmp_file"
        return
    fi
    
    # Calculate required space
    local total_size=$(xargs -a "$tmp_file" -I{} du -sb "$source_dir/{}" | awk '{sum+=$1} END{print sum}')
    local available_space=$(df -B1 "$archive_dir" | awk 'NR==2 {print $4}')
    
    if [[ "$total_size" -gt "$available_space" ]]; then
        log_message "ERROR" "Insufficient space for $month: Need $total_size, available $available_space"
        rm "$tmp_file"
        return 1
    fi
    
    # Create archive
    if tar -czf "$archive_path" -C "$source_dir" --files-from="$tmp_file" 2>/dev/null; then
        log_message "INFO" "Archive created: $archive_name ($(wc -l < "$tmp_file") files)"
        xargs -a "$tmp_file" -I{} rm "$source_dir/{}"
    else
        log_message "ERROR" "Failed to create archive: $archive_name"
        rm "$tmp_file"
        return 1
    fi
    
    rm "$tmp_file"
}

# Export variables and functions
export -f log_message process_month
export source_dir archive_dir file_pattern debug_mode log_file

# Main processing pipeline
find "$source_dir" -type f -name "$file_pattern" -printf "%f\n" |
    awk -F'_' '{print substr($2, 1, 6)}' |
    sort -u |
    xargs -P $(nproc) -I{} bash -c 'process_month "{}"' _

log_message "INFO" "Archiving completed"
