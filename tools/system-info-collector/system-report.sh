#!/usr/bin/env bash

set -u

VERSION="1.0.0"
output_dir="$PWD"
quiet=0
declare -a export_formats=()

usage() {
    cat <<'EOF'
Usage: system-report.sh [options]

Collect a read-only Linux system information report.

Options:
  -e, --export FORMAT       Export as text, json, or csv (repeatable)
  -o, --output-dir DIR      Save reports in DIR (default: current directory)
  -q, --quiet               Do not print the report to the terminal
  -h, --help                Show this help
  -v, --version             Show the script version

Examples:
  ./system-report.sh
  ./system-report.sh --export text --export json --output-dir ./reports
EOF
}

command_value() {
    local fallback="$1"
    shift
    local value
    value=$("$@" 2>/dev/null) || value=""
    if [[ -n "${value//[[:space:]]/}" ]]; then
        printf '%s' "$value"
    else
        printf '%s' "$fallback"
    fi
}

read_first_file() {
    local path="$1"
    if [[ -r "$path" ]]; then
        local value
        IFS= read -r value < "$path" || true
        if [[ -n "${value:-}" ]]; then
            printf '%s' "$value"
            return
        fi
    fi
    printf '%s' 'Unavailable'
}

format_duration() {
    local total="$1"
    local days=$((total / 86400))
    local hours=$(((total % 86400) / 3600))
    local minutes=$(((total % 3600) / 60))
    local seconds=$((total % 60))
    local result=""

    ((days > 0)) && result+="${days}d "
    ((hours > 0)) && result+="${hours}h "
    ((minutes > 0)) && result+="${minutes}m "
    result+="${seconds}s"
    printf '%s' "$result"
}

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\r'/\\r}
    value=${value//$'\n'/\\n}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

csv_escape() {
    local value="$1"
    value=${value//\"/\"\"}
    printf '"%s"' "$value"
}

add_export_format() {
    local requested="${1,,}"
    case "$requested" in
        text|json|csv) export_formats+=("$requested") ;;
        *)
            printf 'Error: unsupported export format: %s\n' "$1" >&2
            exit 2
            ;;
    esac
}

while (($# > 0)); do
    case "$1" in
        -e|--export)
            (($# >= 2)) || { printf 'Error: %s requires a value.\n' "$1" >&2; exit 2; }
            add_export_format "$2"
            shift 2
            ;;
        -o|--output-dir)
            (($# >= 2)) || { printf 'Error: %s requires a value.\n' "$1" >&2; exit 2; }
            output_dir="$2"
            shift 2
            ;;
        -q|--quiet) quiet=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
        --) shift; break ;;
        *) printf 'Error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

collected_at=$(date --iso-8601=seconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')
computer_name=$(command_value 'Unavailable' hostname)
current_user=$(command_value 'Unavailable' id -un)
architecture=$(command_value 'Unavailable' uname -m)
kernel=$(command_value 'Unavailable' uname -r)

os_name='Unavailable'
os_version='Unavailable'
if [[ -r /etc/os-release ]]; then
    # This standard system file contains shell-style variable assignments.
    # shellcheck disable=SC1091
    . /etc/os-release
    os_name=${NAME:-Unavailable}
    os_version=${VERSION_ID:-${VERSION:-Unavailable}}
fi

manufacturer=$(read_first_file /sys/class/dmi/id/sys_vendor)
model=$(read_first_file /sys/class/dmi/id/product_name)
serial_number=$(read_first_file /sys/class/dmi/id/product_serial)

processor='Unavailable'
physical_cores='Unavailable'
logical_processors=$(command_value 'Unavailable' getconf _NPROCESSORS_ONLN)
if command -v lscpu >/dev/null 2>&1; then
    processor=$(lscpu 2>/dev/null | sed -n 's/^Model name:[[:space:]]*//p' | head -n 1)
    sockets=$(lscpu 2>/dev/null | awk -F: '/^Socket\(s\):/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')
    cores_per_socket=$(lscpu 2>/dev/null | awk -F: '/^Core\(s\) per socket:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')
    if [[ "$sockets" =~ ^[0-9]+$ && "$cores_per_socket" =~ ^[0-9]+$ ]]; then
        physical_cores=$((sockets * cores_per_socket))
    fi
elif [[ -r /proc/cpuinfo ]]; then
    processor=$(awk -F: '/model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo)
fi
[[ -n "$processor" ]] || processor='Unavailable'

memory_total_gb='Unavailable'
memory_available_gb='Unavailable'
if [[ -r /proc/meminfo ]]; then
    memory_total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    memory_available_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    [[ "$memory_total_kb" =~ ^[0-9]+$ ]] && memory_total_gb=$(awk -v kb="$memory_total_kb" 'BEGIN {printf "%.2f", kb/1048576}')
    [[ "$memory_available_kb" =~ ^[0-9]+$ ]] && memory_available_gb=$(awk -v kb="$memory_available_kb" 'BEGIN {printf "%.2f", kb/1048576}')
fi

uptime_seconds='Unavailable'
if [[ -r /proc/uptime ]]; then
    uptime_seconds=$(awk '{printf "%.0f", $1}' /proc/uptime)
fi
if [[ "$uptime_seconds" =~ ^[0-9]+$ ]]; then
    uptime_display=$(format_duration "$uptime_seconds")
else
    uptime_display='Unavailable'
fi
last_boot=$(command_value 'Unavailable' uptime -s)

ip_addresses=$(command_value 'Unavailable' hostname -I)
ip_addresses=$(awk '{$1=$1; print}' <<< "$ip_addresses")
default_gateway='Unavailable'
if command -v ip >/dev/null 2>&1; then
    default_gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')
    [[ -n "$default_gateway" ]] || default_gateway='Unavailable'
fi
dns_servers='Unavailable'
if [[ -r /etc/resolv.conf ]]; then
    dns_servers=$(awk '/^[[:space:]]*nameserver[[:space:]]+/ {print $2}' /etc/resolv.conf | paste -sd ' ' -)
    [[ -n "$dns_servers" ]] || dns_servers='Unavailable'
fi

declare -a disk_filesystems=()
declare -a disk_total_gb=()
declare -a disk_used_gb=()
declare -a disk_free_gb=()
declare -a disk_use_percent=()
declare -a disk_mounts=()

while read -r filesystem blocks used available use_percent mountpoint; do
    [[ "$filesystem" == 'Filesystem' ]] && continue
    disk_filesystems+=("$filesystem")
    disk_total_gb+=("$(awk -v kb="$blocks" 'BEGIN {printf "%.2f", kb/1048576}')")
    disk_used_gb+=("$(awk -v kb="$used" 'BEGIN {printf "%.2f", kb/1048576}')")
    disk_free_gb+=("$(awk -v kb="$available" 'BEGIN {printf "%.2f", kb/1048576}')")
    disk_use_percent+=("$use_percent")
    disk_mounts+=("$mountpoint")
done < <(df -Pk -x tmpfs -x devtmpfs 2>/dev/null)

render_text() {
    printf '%s\n' 'SYSTEM INFORMATION REPORT'
    printf 'Generated: %s\n' "$collected_at"
    printf '%*s\n\n' 72 '' | tr ' ' '='
    printf '%s\n' 'SYSTEM'
    printf '  %-15s %s\n' 'Computer name :' "$computer_name"
    printf '  %-15s %s\n' 'Current user  :' "$current_user"
    printf '  %-15s %s\n' 'Manufacturer  :' "$manufacturer"
    printf '  %-15s %s\n' 'Model         :' "$model"
    printf '  %-15s %s\n\n' 'Serial number :' "$serial_number"
    printf '%s\n' 'OPERATING SYSTEM'
    printf '  %-15s %s\n' 'Name          :' "$os_name"
    printf '  %-15s %s\n' 'Version       :' "$os_version"
    printf '  %-15s %s\n' 'Kernel        :' "$kernel"
    printf '  %-15s %s\n' 'Architecture  :' "$architecture"
    printf '  %-15s %s\n' 'Last boot     :' "$last_boot"
    printf '  %-15s %s\n\n' 'Uptime        :' "$uptime_display"
    printf '%s\n' 'PROCESSOR AND MEMORY'
    printf '  %-15s %s\n' 'Processor     :' "$processor"
    printf '  %-15s %s\n' 'Physical cores:' "$physical_cores"
    printf '  %-15s %s\n' 'Logical CPUs  :' "$logical_processors"
    printf '  %-15s %s GB\n' 'Memory total  :' "$memory_total_gb"
    printf '  %-15s %s GB\n\n' 'Memory free   :' "$memory_available_gb"
    printf '%s\n' 'NETWORK'
    printf '  %-15s %s\n' 'IP addresses  :' "$ip_addresses"
    printf '  %-15s %s\n' 'Gateway       :' "$default_gateway"
    printf '  %-15s %s\n\n' 'DNS servers   :' "$dns_servers"
    printf '%s\n' 'STORAGE'

    local i
    for i in "${!disk_filesystems[@]}"; do
        printf '  %-20s %8s GB total  %8s GB free  %5s used  %s\n' \
            "${disk_filesystems[$i]}" "${disk_total_gb[$i]}" \
            "${disk_free_gb[$i]}" "${disk_use_percent[$i]}" "${disk_mounts[$i]}"
    done
}

render_json() {
    local i separator=''
    printf '{\n'
    printf '  "schemaVersion": "1.0",\n'
    printf '  "collectedAt": "%s",\n' "$(json_escape "$collected_at")"
    printf '  "system": {"computerName": "%s", "currentUser": "%s", "manufacturer": "%s", "model": "%s", "serialNumber": "%s"},\n' \
        "$(json_escape "$computer_name")" "$(json_escape "$current_user")" \
        "$(json_escape "$manufacturer")" "$(json_escape "$model")" "$(json_escape "$serial_number")"
    printf '  "operatingSystem": {"name": "%s", "version": "%s", "kernel": "%s", "architecture": "%s", "lastBootTime": "%s", "uptime": "%s", "uptimeSeconds": "%s"},\n' \
        "$(json_escape "$os_name")" "$(json_escape "$os_version")" "$(json_escape "$kernel")" \
        "$(json_escape "$architecture")" "$(json_escape "$last_boot")" "$(json_escape "$uptime_display")" \
        "$(json_escape "$uptime_seconds")"
    printf '  "hardware": {"processor": "%s", "physicalCores": "%s", "logicalProcessors": "%s"},\n' \
        "$(json_escape "$processor")" "$(json_escape "$physical_cores")" "$(json_escape "$logical_processors")"
    printf '  "memory": {"totalGB": "%s", "availableGB": "%s"},\n' \
        "$(json_escape "$memory_total_gb")" "$(json_escape "$memory_available_gb")"
    printf '  "network": {"ipAddresses": "%s", "defaultGateway": "%s", "dnsServers": "%s"},\n' \
        "$(json_escape "$ip_addresses")" "$(json_escape "$default_gateway")" "$(json_escape "$dns_servers")"
    printf '  "disks": ['
    for i in "${!disk_filesystems[@]}"; do
        printf '%s\n    {"filesystem": "%s", "totalGB": "%s", "usedGB": "%s", "freeGB": "%s", "usedPercent": "%s", "mountPoint": "%s"}' \
            "$separator" "$(json_escape "${disk_filesystems[$i]}")" "${disk_total_gb[$i]}" \
            "${disk_used_gb[$i]}" "${disk_free_gb[$i]}" "${disk_use_percent[$i]}" \
            "$(json_escape "${disk_mounts[$i]}")"
        separator=','
    done
    ((${#disk_filesystems[@]} > 0)) && printf '\n  '
    printf ']\n}\n'
}

render_csv() {
    local disks_summary='' i
    for i in "${!disk_filesystems[@]}"; do
        [[ -n "$disks_summary" ]] && disks_summary+='; '
        disks_summary+="${disk_filesystems[$i]} ${disk_total_gb[$i]}GB total/${disk_free_gb[$i]}GB free at ${disk_mounts[$i]}"
    done

    printf '%s\n' 'CollectedAt,ComputerName,CurrentUser,Manufacturer,Model,SerialNumber,OSName,OSVersion,Kernel,Architecture,LastBootTime,UptimeSeconds,Processor,PhysicalCores,LogicalProcessors,MemoryTotalGB,MemoryAvailableGB,IPAddresses,DefaultGateway,DNSServers,Disks'
    local values=(
        "$collected_at" "$computer_name" "$current_user" "$manufacturer" "$model"
        "$serial_number" "$os_name" "$os_version" "$kernel" "$architecture"
        "$last_boot" "$uptime_seconds" "$processor" "$physical_cores" "$logical_processors"
        "$memory_total_gb" "$memory_available_gb" "$ip_addresses" "$default_gateway"
        "$dns_servers" "$disks_summary"
    )
    local separator=''
    for i in "${!values[@]}"; do
        printf '%s' "$separator"
        csv_escape "${values[$i]}"
        separator=','
    done
    printf '\n'
}

if ((quiet == 0)); then
    render_text
fi

if ((${#export_formats[@]} > 0)); then
    if ! mkdir -p -- "$output_dir"; then
        printf 'Error: unable to create output directory: %s\n' "$output_dir" >&2
        exit 1
    fi

    safe_computer_name=${computer_name//[^A-Za-z0-9._-]/_}
    timestamp=$(date '+%Y%m%d_%H%M%S')
    base_name="system-report_${safe_computer_name}_${timestamp}"
    declare -A written_formats=()

    for format in "${export_formats[@]}"; do
        [[ -n "${written_formats[$format]:-}" ]] && continue
        written_formats[$format]=1
        case "$format" in
            text) path="$output_dir/$base_name.txt"; render_text > "$path" ;;
            json) path="$output_dir/$base_name.json"; render_json > "$path" ;;
            csv)  path="$output_dir/$base_name.csv"; render_csv > "$path" ;;
        esac
        printf 'Saved: %s\n' "$path"
    done
fi

