#!/usr/bin/env bash

set -u

VERSION="1.0.0"
output_dir="$PWD"
quiet=0
timeout_seconds=3
dns_host="example.com"
internet_ip="1.1.1.1"
web_url="https://example.com"
declare -a export_formats=()
declare -a custom_tcp_targets=()
declare -a categories=()
declare -a checks=()
declare -a targets=()
declare -a statuses=()
declare -a details=()
declare -a latencies=()

usage() {
    cat <<'EOF'
Usage: network-test.sh [options]

Run read-only Linux network diagnostics and show PASS, WARN, and FAIL results.

Options:
  -e, --export FORMAT       Export as text, json, or csv (repeatable)
  -o, --output-dir DIR      Save reports in DIR (default: current directory)
  -t, --timeout SECONDS     Timeout for each network test (default: 3)
      --dns-host HOST       Hostname used for DNS testing (default: example.com)
      --internet-ip IP      IP used for ICMP testing (default: 1.1.1.1)
      --web-url URL         URL used for HTTPS testing (default: https://example.com)
      --tcp HOST:PORT       Add a custom TCP port test (repeatable)
  -q, --quiet               Do not print results to the terminal
  -h, --help                Show this help
  -v, --version             Show the script version

Examples:
  ./network-test.sh
  ./network-test.sh --tcp server.example.com:22 --tcp 192.168.1.50:443
  ./network-test.sh --export text --export json --export csv --output-dir ./reports

Exit codes:
  0  Diagnostics completed with no FAIL results
  1  One or more diagnostics returned FAIL
  2  Invalid command-line option or value
EOF
}

add_export_format() {
    local requested="${1,,}"
    case "$requested" in
        text|json|csv) export_formats+=("$requested") ;;
        *) printf 'Error: unsupported export format: %s\n' "$1" >&2; exit 2 ;;
    esac
}

validate_tcp_target() {
    local value="$1"
    if [[ ! "$value" =~ ^(.+):([0-9]+)$ ]]; then
        printf 'Error: invalid TCP target "%s"; expected HOST:PORT.\n' "$value" >&2
        exit 2
    fi
    local port="${BASH_REMATCH[2]}"
    if ((port < 1 || port > 65535)); then
        printf 'Error: TCP port must be between 1 and 65535: %s\n' "$port" >&2
        exit 2
    fi
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
        -t|--timeout)
            (($# >= 2)) || { printf 'Error: %s requires a value.\n' "$1" >&2; exit 2; }
            [[ "$2" =~ ^[1-9][0-9]*$ ]] || { printf 'Error: timeout must be a positive integer.\n' >&2; exit 2; }
            timeout_seconds="$2"
            shift 2
            ;;
        --dns-host)
            (($# >= 2)) || { printf 'Error: %s requires a value.\n' "$1" >&2; exit 2; }
            dns_host="$2"
            shift 2
            ;;
        --internet-ip)
            (($# >= 2)) || { printf 'Error: %s requires a value.\n' "$1" >&2; exit 2; }
            internet_ip="$2"
            shift 2
            ;;
        --web-url)
            (($# >= 2)) || { printf 'Error: %s requires a value.\n' "$1" >&2; exit 2; }
            web_url="$2"
            shift 2
            ;;
        --tcp)
            (($# >= 2)) || { printf 'Error: %s requires a value.\n' "$1" >&2; exit 2; }
            validate_tcp_target "$2"
            custom_tcp_targets+=("$2")
            shift 2
            ;;
        -q|--quiet) quiet=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
        --) shift; break ;;
        *) printf 'Error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

add_result() {
    categories+=("$1")
    checks+=("$2")
    targets+=("$3")
    statuses+=("$4")
    details+=("$5")
    latencies+=("${6:-}")
}

trim() {
    awk '{$1=$1; print}' <<< "$1"
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

elapsed_ms() {
    local start_ns="$1"
    local end_ns
    end_ns=$(date +%s%N 2>/dev/null || printf '0')
    if [[ "$start_ns" =~ ^[0-9]+$ && "$end_ns" =~ ^[0-9]+$ && "$start_ns" != 0 ]]; then
        printf '%d' "$(((end_ns - start_ns) / 1000000))"
    else
        printf ''
    fi
}

ping_once() {
    local host="$1"
    local output
    if ! command -v ping >/dev/null 2>&1; then
        return 127
    fi
    output=$(ping -c 1 -W "$timeout_seconds" "$host" 2>&1) || return 1
    local latency
    latency=$(sed -n 's/.*time[=<]\([0-9.]*\).*/\1/p' <<< "$output" | head -n 1)
    printf '%s' "$latency"
}

resolve_host() {
    local host="$1"
    if command -v getent >/dev/null 2>&1; then
        getent ahosts "$host" 2>/dev/null | awk '{print $1}' | awk '!seen[$0]++' | paste -sd ' ' -
    elif command -v host >/dev/null 2>&1; then
        host "$host" 2>/dev/null | awk '/has address/ {print $NF}' | paste -sd ' ' -
    elif command -v nslookup >/dev/null 2>&1; then
        nslookup "$host" 2>/dev/null | awk '/^Address: / {print $2}' | paste -sd ' ' -
    else
        return 127
    fi
}

tcp_connect() {
    local host="$1"
    local port="$2"
    if command -v nc >/dev/null 2>&1; then
        nc -z -w "$timeout_seconds" "$host" "$port" >/dev/null 2>&1
        return $?
    fi
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_seconds" bash -c 'exec 3<>/dev/tcp/$1/$2' _ "$host" "$port" >/dev/null 2>&1
        return $?
    fi
    return 127
}

test_tcp_and_record() {
    local category="$1"
    local check_name="$2"
    local host="$3"
    local port="$4"
    local failure_status="$5"
    local start_ns
    start_ns=$(date +%s%N 2>/dev/null || printf '0')
    tcp_connect "$host" "$port"
    local rc=$?
    local latency
    latency=$(elapsed_ms "$start_ns")
    if ((rc == 0)); then
        add_result "$category" "$check_name" "$host:$port" "PASS" "TCP connection succeeded" "$latency"
    elif ((rc == 127)); then
        add_result "$category" "$check_name" "$host:$port" "WARN" "Install nc or timeout to run TCP checks" ""
    else
        add_result "$category" "$check_name" "$host:$port" "$failure_status" "TCP connection timed out or was refused" "$latency"
    fi
}

collected_at=$(date --iso-8601=seconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')
computer_name=$(hostname 2>/dev/null || printf 'unknown-host')

default_interface=""
default_gateway=""
if command -v ip >/dev/null 2>&1; then
    default_route=$(ip -4 route show default 2>/dev/null | head -n 1)
    default_interface=$(awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}' <<< "$default_route")
    default_gateway=$(awk '{for (i=1; i<=NF; i++) if ($i=="via") {print $(i+1); exit}}' <<< "$default_route")
fi

if [[ -n "$default_interface" ]]; then
    operstate="unknown"
    [[ -r "/sys/class/net/$default_interface/operstate" ]] && IFS= read -r operstate < "/sys/class/net/$default_interface/operstate"
    if [[ "$operstate" == "up" || "$operstate" == "unknown" ]]; then
        add_result "Local network" "Default interface" "$default_interface" "PASS" "Interface state: $operstate" ""
    else
        add_result "Local network" "Default interface" "$default_interface" "FAIL" "Interface state: $operstate" ""
    fi
else
    add_result "Local network" "Default interface" "local system" "FAIL" "No IPv4 default interface was detected; install iproute2 if the ip command is missing" ""
fi

local_ipv4=""
if [[ -n "$default_interface" ]] && command -v ip >/dev/null 2>&1; then
    local_ipv4=$(ip -o -4 addr show dev "$default_interface" scope global 2>/dev/null | awk '{print $4}' | paste -sd ' ' -)
fi
if [[ -n "$local_ipv4" ]]; then
    add_result "Local network" "IPv4 configuration" "$default_interface" "PASS" "$local_ipv4" ""
else
    add_result "Local network" "IPv4 configuration" "${default_interface:-local system}" "FAIL" "No global IPv4 address was detected" ""
fi

if [[ -n "$default_gateway" ]]; then
    add_result "Local network" "Default gateway" "$default_gateway" "PASS" "A default IPv4 gateway is configured" ""
    gateway_latency=$(ping_once "$default_gateway")
    gateway_rc=$?
    if ((gateway_rc == 0)); then
        add_result "Local network" "Gateway reachability" "$default_gateway" "PASS" "Gateway replied to ICMP" "$gateway_latency"
    elif ((gateway_rc == 127)); then
        add_result "Local network" "Gateway reachability" "$default_gateway" "WARN" "The ping command is unavailable" ""
    else
        add_result "Local network" "Gateway reachability" "$default_gateway" "WARN" "No ICMP reply; the gateway may block ping" ""
    fi
else
    add_result "Local network" "Default gateway" "local routing table" "WARN" "No IPv4 default gateway was detected" ""
    add_result "Local network" "Gateway reachability" "not available" "WARN" "Skipped because no gateway was detected" ""
fi

dns_servers=""
if [[ -r /etc/resolv.conf ]]; then
    dns_servers=$(awk '/^[[:space:]]*nameserver[[:space:]]+/ {print $2}' /etc/resolv.conf | paste -sd ' ' -)
fi
if [[ -n "$dns_servers" ]]; then
    add_result "DNS" "DNS configuration" "resolver" "PASS" "$dns_servers" ""
else
    add_result "DNS" "DNS configuration" "resolver" "WARN" "No nameserver was found in /etc/resolv.conf" ""
fi

start_ns=$(date +%s%N 2>/dev/null || printf '0')
resolved_addresses=$(resolve_host "$dns_host")
resolve_rc=$?
dns_latency=$(elapsed_ms "$start_ns")
resolved_addresses=$(trim "$resolved_addresses")
if ((resolve_rc == 0)) && [[ -n "$resolved_addresses" ]]; then
    add_result "DNS" "Hostname resolution" "$dns_host" "PASS" "$resolved_addresses" "$dns_latency"
elif ((resolve_rc == 127)); then
    add_result "DNS" "Hostname resolution" "$dns_host" "FAIL" "No supported DNS lookup command was found" ""
else
    add_result "DNS" "Hostname resolution" "$dns_host" "FAIL" "Hostname did not resolve" "$dns_latency"
fi

internet_latency=$(ping_once "$internet_ip")
internet_ping_rc=$?
if ((internet_ping_rc == 0)); then
    add_result "Internet" "Public IP reachability" "$internet_ip" "PASS" "Public IP replied to ICMP" "$internet_latency"
elif ((internet_ping_rc == 127)); then
    add_result "Internet" "Public IP reachability" "$internet_ip" "WARN" "The ping command is unavailable" ""
else
    add_result "Internet" "Public IP reachability" "$internet_ip" "WARN" "No ICMP reply; some networks block ping" ""
fi

web_host=$(sed -E 's#^[A-Za-z]+://##; s#/.*$##; s/:.*$//' <<< "$web_url")
[[ -n "$web_host" ]] || web_host="$dns_host"
test_tcp_and_record "Ports" "HTTP port" "$web_host" "80" "WARN"
test_tcp_and_record "Ports" "HTTPS port" "$web_host" "443" "FAIL"

if [[ -n "$dns_servers" ]]; then
    first_dns=${dns_servers%% *}
    test_tcp_and_record "Ports" "DNS TCP port" "$first_dns" "53" "WARN"
else
    add_result "Ports" "DNS TCP port" "not available" "WARN" "Skipped because no DNS server was detected" ""
fi

if command -v curl >/dev/null 2>&1; then
    start_ns=$(date +%s%N 2>/dev/null || printf '0')
    http_code=$(curl --location --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time "$timeout_seconds" "$web_url" 2>/dev/null)
    curl_rc=$?
    web_latency=$(elapsed_ms "$start_ns")
    if ((curl_rc == 0)) && [[ "$http_code" =~ ^[1-5][0-9][0-9]$ ]]; then
        add_result "Internet" "Web request" "$web_url" "PASS" "HTTP status $http_code" "$web_latency"
    else
        add_result "Internet" "Web request" "$web_url" "FAIL" "HTTPS request failed or timed out" "$web_latency"
    fi
elif command -v wget >/dev/null 2>&1; then
    start_ns=$(date +%s%N 2>/dev/null || printf '0')
    if wget --spider --quiet --timeout="$timeout_seconds" "$web_url"; then
        add_result "Internet" "Web request" "$web_url" "PASS" "HTTPS request succeeded" "$(elapsed_ms "$start_ns")"
    else
        add_result "Internet" "Web request" "$web_url" "FAIL" "HTTPS request failed or timed out" "$(elapsed_ms "$start_ns")"
    fi
else
    add_result "Internet" "Web request" "$web_url" "WARN" "Install curl or wget to run the web request" ""
fi

for tcp_target in "${custom_tcp_targets[@]}"; do
    custom_host="${tcp_target%:*}"
    custom_port="${tcp_target##*:}"
    custom_host="${custom_host#[}"
    custom_host="${custom_host%]}"
    test_tcp_and_record "Custom" "Custom TCP port" "$custom_host" "$custom_port" "FAIL"
done

count_status() {
    local wanted="$1"
    local count=0 status
    for status in "${statuses[@]}"; do
        [[ "$status" == "$wanted" ]] && ((count += 1))
    done
    printf '%d' "$count"
}

pass_count=$(count_status PASS)
warn_count=$(count_status WARN)
fail_count=$(count_status FAIL)

render_plain() {
    printf 'NETWORK TROUBLESHOOTER REPORT\n'
    printf 'Computer: %s\n' "$computer_name"
    printf 'Generated: %s\n' "$collected_at"
    printf 'Summary: %s PASS, %s WARN, %s FAIL\n' "$pass_count" "$warn_count" "$fail_count"
    printf '%*s\n' 96 '' | tr ' ' '='
    printf '%-6s  %-18s  %-24s  %-22s  %s\n' 'STATUS' 'CATEGORY' 'CHECK' 'TARGET' 'DETAILS'
    printf '%*s\n' 96 '' | tr ' ' '-'
    local i latency_text
    for i in "${!checks[@]}"; do
        latency_text=""
        [[ -n "${latencies[$i]}" ]] && latency_text=" (${latencies[$i]} ms)"
        printf '%-6s  %-18s  %-24s  %-22s  %s%s\n' \
            "${statuses[$i]}" "${categories[$i]}" "${checks[$i]}" \
            "${targets[$i]}" "${details[$i]}" "$latency_text"
    done
}

render_terminal() {
    local use_color=0
    [[ -t 1 && -z "${NO_COLOR:-}" ]] && use_color=1
    printf 'NETWORK TROUBLESHOOTER\n'
    printf 'Computer: %s | Generated: %s\n\n' "$computer_name" "$collected_at"
    local i color reset latency_text
    for i in "${!checks[@]}"; do
        color=""; reset=""
        if ((use_color)); then
            case "${statuses[$i]}" in
                PASS) color=$'\033[32m' ;;
                WARN) color=$'\033[33m' ;;
                FAIL) color=$'\033[31m' ;;
            esac
            reset=$'\033[0m'
        fi
        latency_text=""
        [[ -n "${latencies[$i]}" ]] && latency_text=" | ${latencies[$i]} ms"
        printf '%s[%-4s]%s %-24s | %-22s | %s%s\n' \
            "$color" "${statuses[$i]}" "$reset" "${checks[$i]}" \
            "${targets[$i]}" "${details[$i]}" "$latency_text"
    done
    printf '\nSummary: %s PASS, %s WARN, %s FAIL\n' "$pass_count" "$warn_count" "$fail_count"
}

render_json() {
    printf '{\n'
    printf '  "tool": "network-troubleshooter",\n'
    printf '  "version": "%s",\n' "$(json_escape "$VERSION")"
    printf '  "computer_name": "%s",\n' "$(json_escape "$computer_name")"
    printf '  "generated_at": "%s",\n' "$(json_escape "$collected_at")"
    printf '  "summary": {"pass": %d, "warn": %d, "fail": %d},\n' "$pass_count" "$warn_count" "$fail_count"
    printf '  "results": [\n'
    local i comma latency_json
    for i in "${!checks[@]}"; do
        comma=','
        ((i == ${#checks[@]} - 1)) && comma=''
        if [[ -n "${latencies[$i]}" ]]; then latency_json="${latencies[$i]}"; else latency_json='null'; fi
        printf '    {"category": "%s", "check": "%s", "target": "%s", "status": "%s", "details": "%s", "latency_ms": %s}%s\n' \
            "$(json_escape "${categories[$i]}")" "$(json_escape "${checks[$i]}")" \
            "$(json_escape "${targets[$i]}")" "$(json_escape "${statuses[$i]}")" \
            "$(json_escape "${details[$i]}")" "$latency_json" "$comma"
    done
    printf '  ]\n}\n'
}

render_csv() {
    printf 'Category,Check,Target,Status,Details,LatencyMs\n'
    local i
    for i in "${!checks[@]}"; do
        printf '%s,%s,%s,%s,%s,%s\n' \
            "$(csv_escape "${categories[$i]}")" "$(csv_escape "${checks[$i]}")" \
            "$(csv_escape "${targets[$i]}")" "$(csv_escape "${statuses[$i]}")" \
            "$(csv_escape "${details[$i]}")" "$(csv_escape "${latencies[$i]}")"
    done
}

if ((quiet == 0)); then
    render_terminal
fi

if ((${#export_formats[@]} > 0)); then
    if ! mkdir -p -- "$output_dir"; then
        printf 'Error: could not create output directory: %s\n' "$output_dir" >&2
        exit 2
    fi
    timestamp=$(date '+%Y%m%d_%H%M%S')
    safe_name=$(tr -cd 'A-Za-z0-9._-' <<< "$computer_name")
    [[ -n "$safe_name" ]] || safe_name='unknown-host'
    declare -A written_formats=()
    for format in "${export_formats[@]}"; do
        [[ -n "${written_formats[$format]:-}" ]] && continue
        written_formats[$format]=1
        extension="$format"
        [[ "$format" == "text" ]] && extension="txt"
        report_path="$output_dir/network-report_${safe_name}_${timestamp}.$extension"
        case "$format" in
            text) render_plain > "$report_path" ;;
            json) render_json > "$report_path" ;;
            csv) render_csv > "$report_path" ;;
        esac
        printf 'Saved %s report: %s\n' "${format^^}" "$report_path"
    done
fi

((fail_count == 0))

