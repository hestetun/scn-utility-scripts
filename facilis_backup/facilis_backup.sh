#!/bin/bash

##############################################################################
# Facilis Flash Storage Backup Script
# Purpose: Backup all volumes from Facilis flash using rsync (Homebrew only)
# Uses: fccmd list_mounts to detect mounted volumes
# Logging: Managed via launch agent
##############################################################################

set -euo pipefail

# Configuration
BACKUP_DESTINATION="${BACKUP_DEST:-/Volumes/blackhole/facilis_backup}"
EXCLUDE_FILE="$(dirname "$0")/facilis_backup_exclude.txt"
RSYNC_OPTS="-avW --inplace --progress"
MAX_PARALLEL_RSYNC="${MAX_PARALLEL_RSYNC:-3}"
DRY_RUN="${DRY_RUN:-0}"
EMAIL_TO="${EMAIL_TO:-scntech@shortcutoslo.no}"
EMAIL_SUBJECT_PREFIX="${EMAIL_SUBJECT_PREFIX:-Facilis backup report}"
DEBUG_RSYNC="0"
DEBUG_LOG_FILE=""
RUN_LOG_FILE=""
RUN_TEMP_DIR=""
STOP_REQUESTED="0"
backup_errors=0
FCCMD_BIN=""
RSYNC_BIN=""
MAIL_BIN=""

# Edit these here if the special volumes should land somewhere else.
SCN_COMMERCIAL_BACKUP_DIR="/Volumes/whiterabbit/zz_scn_commercial_archive"
WBD_PROMO_BACKUP_DIR="/Volumes/whiterabbit/zz_wbd"

##############################################################################
# Utility Functions
##############################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[${timestamp}] [${level}] ${message}"

    if [[ -n "${RUN_LOG_FILE:-}" ]]; then
        echo "$line" >> "$RUN_LOG_FILE"
    fi

    if [[ -n "${DEBUG_LOG_FILE:-}" ]]; then
        echo "$line" >> "$DEBUG_LOG_FILE"
    fi

    if [[ "$level" == "ERROR" ]]; then
        echo "$line" >&2
    else
        echo "$line"
    fi
}

send_email_report() {
    local status_label="$1"

    if [[ -z "$EMAIL_TO" ]]; then
        return
    fi

    if [[ -z "${RUN_LOG_FILE:-}" || ! -s "$RUN_LOG_FILE" ]]; then
        log "WARN" "EMAIL_TO is set, but no run log was captured. Skipping email report."
        return
    fi

    local subject
    subject="${EMAIL_SUBJECT_PREFIX} | ${status_label} | $(hostname) | $(date '+%Y-%m-%d %H:%M')"

    if [[ -n "$MAIL_BIN" ]]; then
        if "$MAIL_BIN" -s "$subject" "$EMAIL_TO" < "$RUN_LOG_FILE"; then
            log "INFO" "Email report sent to: $EMAIL_TO"
            return
        fi
        log "WARN" "mail command failed for: $EMAIL_TO"
        return
    fi

    log "WARN" "EMAIL_TO is set, but the native mail utility was not found. Skipping email report."
}

error_exit() {
    log "ERROR" "$@"
    exit 1
}

request_stop() {
    STOP_REQUESTED="1"
    log "WARN" "Stop requested. Finishing the current step and exiting cleanly."
}

log_section() {
    local title="$1"
    log "INFO" ""
    log "INFO" "============================================================"
    log "INFO" "$title"
    log "INFO" "============================================================"
}

format_duration() {
    local total_seconds="$1"
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))
    printf '%02dh:%02dm:%02ds' "$hours" "$minutes" "$seconds"
}

bytes_to_gb() {
    local bytes_value="$1"
    awk -v b="$bytes_value" 'BEGIN { printf "%.2f GB", (b / 1000000000) }'
}

result_file_value() {
    local key="$1"
    local result_file="$2"

    awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, "", $0); print; exit }' "$result_file"
}

run_volume_backup_job() {
    local volume="$1"
    local volume_name="$2"
    local volume_capacity="$3"
    local volume_available="$4"
    local backup_path="$5"
    local result_file="$6"
    local volume_start_epoch

    volume_start_epoch=$(date +%s)

    local rsync_output
    local rsync_exit_code=0
    local files_copied
    local transferred_size_bytes
    local transferred_size
    local volume_end_epoch
    local volume_duration

    if mkdir -p "$backup_path"; then
        if [[ "$DEBUG_RSYNC" == "1" ]]; then
            if rsync_output=$("$RSYNC_BIN" "${rsync_args[@]}" "$volume/" "$backup_path/" 2>&1 | tee -a "$DEBUG_LOG_FILE"); then
                rsync_exit_code=0
            else
                rsync_exit_code=$?
            fi
        else
            if rsync_output=$("$RSYNC_BIN" "${rsync_args[@]}" "$volume/" "$backup_path/" 2>&1); then
                rsync_exit_code=0
            else
                rsync_exit_code=$?
            fi
        fi

        if [[ "$rsync_exit_code" -eq 0 ]]; then
            files_copied=$(printf '%s\n' "$rsync_output" | awk -F': ' '
                /^Number of regular files transferred: / { print $2; found=1 }
                /^Number of files transferred: / { print $2; found=1 }
                END { if (!found) print "unknown" }
            ')

            transferred_size_bytes=$(printf '%s\n' "$rsync_output" | awk -F': ' '
                /^Total transferred file size: / {
                    gsub(/ bytes$/, "", $2)
                    gsub(/,/, "", $2)
                    print $2
                    found=1
                }
                END { if (!found) print "0" }
            ')

            transferred_size=$(bytes_to_gb "$transferred_size_bytes")
            volume_end_epoch=$(date +%s)
            volume_duration=$((volume_end_epoch - volume_start_epoch))

            {
                printf 'status=success\n'
                printf 'volume_name=%s\n' "$volume_name"
                printf 'volume_capacity=%s\n' "$volume_capacity"
                printf 'volume_available=%s\n' "$volume_available"
                printf 'files_copied=%s\n' "$files_copied"
                printf 'transferred_size_bytes=%s\n' "$transferred_size_bytes"
                printf 'transferred_size=%s\n' "$transferred_size"
                printf 'duration_seconds=%s\n' "$volume_duration"
            } > "$result_file"
        else
            log "ERROR" "Failed to backup: $volume_name"
            while IFS= read -r rsync_error_line; do
                [[ -n "$rsync_error_line" ]] && log "ERROR" "rsync: $rsync_error_line"
            done <<< "$rsync_output"

            {
                printf 'status=failure\n'
                printf 'volume_name=%s\n' "$volume_name"
                printf 'volume_capacity=%s\n' "$volume_capacity"
                printf 'volume_available=%s\n' "$volume_available"
                printf 'files_copied=unknown\n'
                printf 'transferred_size_bytes=0\n'
                printf 'transferred_size=0.00 GB\n'
                printf 'duration_seconds=0\n'
            } > "$result_file"
        fi
    else
        log "ERROR" "Failed to create backup directory: $backup_path"

        {
            printf 'status=failure\n'
            printf 'volume_name=%s\n' "$volume_name"
            printf 'volume_capacity=%s\n' "$volume_capacity"
            printf 'volume_available=%s\n' "$volume_available"
            printf 'files_copied=unknown\n'
            printf 'transferred_size_bytes=0\n'
            printf 'transferred_size=0.00 GB\n'
            printf 'duration_seconds=0\n'
        } > "$result_file"
    fi
}

log_backup_destination_space() {
    local df_line
    df_line=$(df -k "$BACKUP_DESTINATION" 2>/dev/null | awk 'NR==2 {print}')

    if [[ -z "$df_line" ]]; then
        log "WARN" "Could not read backup destination disk space for: $BACKUP_DESTINATION"
        return
    fi

    # shellcheck disable=SC2086
    set -- $df_line
    local available_kb="$4"
    local used_percent="$5"
    local available_gb

    available_gb=$(awk -v kb="$available_kb" 'BEGIN { printf "%.2f GB", (kb * 1024 / 1000000000) }')

    log "INFO" "Backup destination: $BACKUP_DESTINATION"
    log "INFO" "Backup destination free space: $available_gb (used: $used_percent)"
}

get_volume_backup_path() {
    local volume_name="$1"

    case "$volume_name" in
        *_edit)
            echo "SKIP"
            ;;
        scn_commercial)
            if [[ -n "$SCN_COMMERCIAL_BACKUP_DIR" ]]; then
                echo "$SCN_COMMERCIAL_BACKUP_DIR"
            else
                echo "$BACKUP_DESTINATION/$volume_name"
            fi
            ;;
        wbd_promo)
            if [[ -n "$WBD_PROMO_BACKUP_DIR" ]]; then
                echo "$WBD_PROMO_BACKUP_DIR"
            else
                echo "$BACKUP_DESTINATION/$volume_name"
            fi
            ;;
        *)
            echo "$BACKUP_DESTINATION/$volume_name"
            ;;
    esac
}

resolve_command() {
    local command_name="$1"
    shift
    local candidate

    if candidate=$(command -v "$command_name" 2>/dev/null); then
        echo "$candidate"
        return 0
    fi

    for candidate in "$@"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

validate_destination_paths() {
    log "INFO" "Validating destination paths..."

    # Check main backup destination
    if [[ ! -d "$BACKUP_DESTINATION" ]]; then
        error_exit "Backup destination does not exist: $BACKUP_DESTINATION"
    fi
    if [[ ! -w "$BACKUP_DESTINATION" ]]; then
        error_exit "Backup destination is not writable: $BACKUP_DESTINATION"
    fi

    # Check special volume destinations
    for dest_name in "SCN_COMMERCIAL_BACKUP_DIR" "WBD_PROMO_BACKUP_DIR"; do
        local dest_path
        dest_path="${!dest_name}"

        if [[ -z "$dest_path" ]]; then
            continue
        fi

        local parent_dir
        parent_dir="$(dirname "$dest_path")"

        if [[ ! -d "$parent_dir" ]]; then
            error_exit "Parent directory does not exist for $dest_name: $parent_dir"
        fi
        if [[ ! -w "$parent_dir" ]]; then
            error_exit "Parent directory is not writable for $dest_name: $parent_dir"
        fi

        log "INFO" "  $dest_name: $dest_path (parent writable)"
    done

    log "INFO" "All destination paths validated."
}

##############################################################################
# Main Backup Logic
##############################################################################

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG_RSYNC="1"
                shift
                ;;
            -h|--help)
                cat <<'EOF'
Usage: facilis_backup.sh [--debug]

Options:
    --debug         Print full raw rsync output to stdout for each volume
  -h, --help      Show this help message
EOF
                return 0
                ;;
            *)
                error_exit "Unknown argument: $1"
                ;;
        esac
    done

    local run_start_epoch
    local run_start_human
    local host_name
    backup_errors=0

    if ! [[ "$MAX_PARALLEL_RSYNC" =~ ^[1-9][0-9]*$ ]]; then
        error_exit "MAX_PARALLEL_RSYNC must be a positive integer"
    fi

    RUN_TEMP_DIR=$(mktemp -d -t facilis_backup_run.XXXXXX)
    RUN_LOG_FILE="$RUN_TEMP_DIR/facilis_backup_run.log"
    
    # Global trap catches exits anywhere in main and sends the report
    trap '
        exit_code=$?
        if [[ $exit_code -eq 0 && "$backup_errors" -eq 0 ]]; then 
            send_email_report "SUCCESS"; 
        elif [[ $exit_code -eq 0 && "$backup_errors" -eq 1 ]]; then
            send_email_report "PARTIAL FAILURE";
        else 
            send_email_report "CRASHED/INTERRUPTED (Code $exit_code)"; 
        fi; 
        [[ -n "${RUN_LOG_FILE:-}" && -f "$RUN_LOG_FILE" ]] && rm -f "$RUN_LOG_FILE"
        [[ -n "${RUN_TEMP_DIR:-}" && -d "$RUN_TEMP_DIR" ]] && rm -rf "$RUN_TEMP_DIR"
    ' EXIT
    trap 'request_stop' INT TERM

    run_start_epoch=$(date +%s)
    run_start_human=$(date '+%Y-%m-%d %H:%M:%S')
    host_name=$(hostname)

    log_section "Backup session"
    log "INFO" "Host: $host_name"
    log "INFO" "Started: $run_start_human"
    log "INFO" "Starting Facilis backup process"

    if [[ "$DRY_RUN" == "1" ]]; then
        RSYNC_OPTS+=" -n"
        log "INFO" "Dry-run mode enabled (rsync -n). No files will be copied."
    fi

    if [[ "$DEBUG_RSYNC" == "1" ]]; then
        DEBUG_LOG_FILE="$HOME/Desktop/facilis_backup_debug_$(date '+%Y%m%d_%H%M%S').log"
        touch "$DEBUG_LOG_FILE"
        log "INFO" "Debug rsync mode enabled. Full rsync output will be printed to stdout."
        log "INFO" "Debug log file: $DEBUG_LOG_FILE"
    fi

    # Strictly find Homebrew rsync path (skips /usr/bin/rsync built-in)
    if ! RSYNC_BIN=$(resolve_command /opt/homebrew/bin/rsync /usr/local/bin/rsync); then
        error_exit "Homebrew rsync not found at /opt/homebrew/bin/rsync or /usr/local/bin/rsync. Aborting."
    fi
    log "INFO" "Using Homebrew rsync binary: $RSYNC_BIN"

    if ! MAIL_BIN=$(resolve_command mail /usr/bin/mail); then
        MAIL_BIN=""
    fi
    
    if ! FCCMD_BIN=$(resolve_command fccmd /usr/local/bin/fccmd); then
        error_exit "fccmd command not found. Is Facilis software installed?"
    fi
    log "INFO" "Using fccmd binary: $FCCMD_BIN"

    validate_destination_paths
    
    log "INFO" "Detecting Facilis mounted volumes..."
    local mounts
    mounts=$("$FCCMD_BIN" list_mounts 2>/dev/null | awk -F' = ' -v mount_base="/Volumes/" '
        /^  volume name = / { volume_name=$2 }
        /^  capacity = / { capacity=$2 }
        /^  available = / { available=$2 }
        /^  mount point = / {
            mount_point=$2
            if (index(mount_point, mount_base) == 1) {
                print mount_point "|" volume_name "|" capacity "|" available
            }
        }
    ')
    
    if [[ -z "$mounts" ]]; then
        log "WARN" "No Facilis volumes found mounted"
        return 0
    fi
    
    local exclude_opts=""
    if [[ -f "$EXCLUDE_FILE" ]]; then
        exclude_opts="--exclude-from=$EXCLUDE_FILE"
        log "INFO" "Using exclude list: $EXCLUDE_FILE"
    fi

    local -a rsync_args=()
    read -r -a rsync_args <<< "$RSYNC_OPTS"
    rsync_args+=(--stats)
    if [[ -n "$exclude_opts" ]]; then
        rsync_args+=("$exclude_opts")
    fi

    log_section "General information"
    log_backup_destination_space
    log "INFO" ""
    log "INFO" "Volumes to be backed up:"
    log "INFO" "Concurrent rsync jobs: $MAX_PARALLEL_RSYNC"
    while IFS='|' read -r _ volume_name volume_capacity volume_available; do
        if [[ "$STOP_REQUESTED" == "1" ]]; then
            log "WARN" "Stopping before the next volume because exit was requested."
            break
        fi

        [[ -z "$volume_name" ]] && continue

        if [[ -z "$volume_capacity" ]]; then
            volume_capacity="unknown"
        fi
        if [[ -z "$volume_available" ]]; then
            volume_available="unknown"
        fi

        log "INFO" "- $volume_name | size: $volume_capacity | available: $volume_available"

        if [[ "$volume_available" != "unknown" ]]; then
            local available_gb
            available_gb=$(awk -v available="$volume_available" 'BEGIN {
                split(available, parts, " ")
                value = parts[1]
                unit = toupper(parts[2])
                if (unit == "TB") {
                    value = value * 1000
                } else if (unit == "MB") {
                    value = value / 1000
                } else if (unit != "GB") {
                    print -1
                    exit
                }
                printf("%.0f", value)
            }')

            if [[ "$available_gb" -ge 0 && "$available_gb" -lt 900 ]]; then
                log "WARN" "LOW SPACE ALERT: $volume_name has only $volume_available available"
            fi
        fi
    done <<< "$mounts"
    
    local backed_up_summary=""
    local total_transferred_bytes=0
    local -a backup_job_pids=()
    local -a backup_job_result_files=()
    local backup_job_index=0

    collect_backup_job_result() {
        local job_index
        local job_pid
        local result_file
        local result_status
        local result_volume_name
        local result_volume_capacity
        local result_volume_available
        local result_files_copied
        local result_transferred_size_bytes
        local result_transferred_size
        local result_duration_seconds
        local -a remaining_pids=()
        local -a remaining_result_files=()
        local remaining_index

        while true; do
            for job_index in "${!backup_job_result_files[@]}"; do
                result_file="${backup_job_result_files[$job_index]}"

                if [[ -f "$result_file" ]]; then
                    job_pid="${backup_job_pids[$job_index]}"

                    if ! wait "$job_pid"; then
                        backup_errors=1
                    fi

                    result_status=$(result_file_value status "$result_file")
                    result_volume_name=$(result_file_value volume_name "$result_file")
                    result_volume_capacity=$(result_file_value volume_capacity "$result_file")
                    result_volume_available=$(result_file_value volume_available "$result_file")
                    result_files_copied=$(result_file_value files_copied "$result_file")
                    result_transferred_size_bytes=$(result_file_value transferred_size_bytes "$result_file")
                    result_transferred_size=$(result_file_value transferred_size "$result_file")
                    result_duration_seconds=$(result_file_value duration_seconds "$result_file")

                    if [[ "$result_status" == "success" ]]; then
                        backed_up_summary+="- ${result_volume_name} | size: ${result_volume_capacity:-unknown} | available: ${result_volume_available} | files copied: ${result_files_copied} | copied size: ${result_transferred_size} | duration: $(format_duration "$result_duration_seconds")"$'\n'
                        total_transferred_bytes=$((total_transferred_bytes + result_transferred_size_bytes))
                    else
                        backup_errors=1
                    fi

                    for remaining_index in "${!backup_job_pids[@]}"; do
                        [[ "$remaining_index" == "$job_index" ]] && continue
                        remaining_pids+=("${backup_job_pids[$remaining_index]}")
                        remaining_result_files+=("${backup_job_result_files[$remaining_index]}")
                    done

                    backup_job_pids=("${remaining_pids[@]}")
                    backup_job_result_files=("${remaining_result_files[@]}")
                    return 0
                fi
            done

            sleep 1
        done
    }

    while IFS='|' read -r volume volume_name volume_capacity volume_available; do
        if [[ "$STOP_REQUESTED" == "1" ]]; then
            log "WARN" "Stopping before the next volume because exit was requested."
            break
        fi

        if [[ -z "$volume" ]]; then
            continue
        fi

        if [[ -z "$volume_name" ]]; then
            volume_name=$(basename "$volume")
        fi

        if [[ -z "$volume_available" ]]; then
            volume_available="unknown"
        fi

        local backup_path
        backup_path=$(get_volume_backup_path "$volume_name")
        if [[ "$backup_path" == "SKIP" ]]; then
            log "INFO" "Skipping volume by rule: $volume_name"
            continue
        fi

        while [[ ${#backup_job_pids[@]} -ge $MAX_PARALLEL_RSYNC ]]; do
            collect_backup_job_result "${backup_job_pids[0]}" "${backup_job_result_files[0]}"
        done

        local result_file
        result_file="$RUN_TEMP_DIR/job_${backup_job_index}.result"

        run_volume_backup_job "$volume" "$volume_name" "$volume_capacity" "$volume_available" "$backup_path" "$result_file" &
        backup_job_pids+=("$!")
        backup_job_result_files+=("$result_file")
        backup_job_index=$((backup_job_index + 1))
    done <<< "$mounts"

    while [[ ${#backup_job_pids[@]} -gt 0 ]]; do
        collect_backup_job_result "${backup_job_pids[0]}" "${backup_job_result_files[0]}"
    done

    if [[ -n "$backed_up_summary" ]]; then
        log_section "Backed up volumes"
        while IFS= read -r summary_line; do
            [[ -n "$summary_line" ]] && log "INFO" "$summary_line"
        done <<< "$backed_up_summary"
    else
        log "WARN" "No volumes were backed up successfully"
    fi

    local run_end_epoch
    local total_duration

    run_end_epoch=$(date +%s)
    total_duration=$((run_end_epoch - run_start_epoch))

    log "INFO" "Backup process completed"
    log "INFO" "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Total duration: $(format_duration "$total_duration")"
    
    local total_transferred_gb
    local throughput_mbps
    total_transferred_gb=$(bytes_to_gb "$total_transferred_bytes")
    if [[ "$total_duration" -gt 0 ]]; then
        throughput_mbps=$(awk -v bytes="$total_transferred_bytes" -v secs="$total_duration" 'BEGIN { printf "%.2f", (bytes / secs / 1000000) }')
    else
        throughput_mbps="0.00"
    fi
    log "INFO" "Total data transferred: $total_transferred_gb"
    log "INFO" "Average throughput: ${throughput_mbps} MB/s"

    if [[ "$STOP_REQUESTED" == "1" ]]; then
        log "WARN" "Backup was interrupted before completion."
        return 130
    fi
}

##############################################################################
# Entry Point
##############################################################################

main "$@"
