#!/bin/bash

set -euo pipefail

# Default settings
UDP_PORTS=1000
QUICK_MODE=false
TIMING="-T4 --min-rate 500 --max-retries 2"

# Help function
show_help() {
    echo "Usage: $0 [options] [target]"
    echo ""
    echo "Options:"
    echo "  -u N, --udp-ports N    Scan top N UDP ports (default: 1000)"
    echo "  --quick                Quick TCP scan (skip heavy -A: no OS detection/traceroute)"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.10"
    echo "  $0 -u 3000 10.0.0.5"
    echo "  $0 --quick 192.168.1.100"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--udp-ports)
            UDP_PORTS="$2"
            shift 2
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Prompt for target if not provided
if [[ -z "${TARGET:-}" ]]; then
    read -p "Enter the target IP address or hostname: " TARGET
fi

if [[ -z "$TARGET" ]]; then
    echo "Error: No target provided."
    exit 1
fi

# Basic validation (IP or hostname)
if ! [[ $TARGET =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && \
   ! [[ $TARGET =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
    echo "Error: '$TARGET' does not appear to be a valid IP address or hostname."
    exit 1
fi

# Create output directory
OUTPUT_DIR="nmap_results_$(date +%Y%m%d_%H%M%S)_${TARGET//./_}"
mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/scan.log"

echo "Target: $TARGET" | tee "$LOG_FILE"
echo "Output directory: $OUTPUT_DIR" | tee -a "$LOG_FILE"
echo "UDP ports to scan: top $UDP_PORTS" | tee -a "$LOG_FILE"
echo "Quick mode: $QUICK_MODE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Quick reachability check
echo "Checking host reachability (ping)..."
if ping -c 1 -W 2 "$TARGET" &> /dev/null; then
    echo "Host is reachable via ICMP." | tee -a "$LOG_FILE"
else
    echo "Warning: Host not responding to ping (may block ICMP). Continuing..." | tee -a "$LOG_FILE"
fi

# Start UDP scan immediately (maximum parallelism)
echo "Starting UDP scan (top $UDP_PORTS ports) in background..."
sudo nmap -sU -sV --top-ports "$UDP_PORTS" $TIMING "$TARGET" \
    -oA "$OUTPUT_DIR/${TARGET}_udp_top${UDP_PORTS}" >> "$LOG_FILE" 2>&1 &
UDP_PID=$!

# 1. TCP port discovery
echo "1. Discovering all open TCP ports..."
sudo nmap -sS -p- --open $TIMING "$TARGET" \
    -oN "$OUTPUT_DIR/${TARGET}_tcp_open_ports.txt" \
    -oG "$OUTPUT_DIR/${TARGET}_tcp_open_ports.grepable" >> "$LOG_FILE" 2>&1

# Extract open ports
PORTS_FILE="$OUTPUT_DIR/${TARGET}_tcp_open_ports.grepable"
PORTS=$(grep -oE '[0-9]+/open' "$PORTS_FILE" | cut -d '/' -f 1 | tr '\n' ',' | sed 's/,$//')

OPEN_COUNT=$(echo "$PORTS" | tr ',' '\n' | grep -c . || echo 0)

if [[ $OPEN_COUNT -eq 0 ]]; then
    echo "No open TCP ports found. Skipping detailed TCP scan." | tee -a "$LOG_FILE"
    touch "$OUTPUT_DIR/${TARGET}_tcp_detailed.nmap"
    echo "No open TCP ports" > "$OUTPUT_DIR/${TARGET}_tcp_detailed.nmap"
    TCP_OUTPUT="${TARGET}_tcp_detailed"
else
    echo "Found $OPEN_COUNT open TCP port(s): $PORTS" | tee -a "$LOG_FILE"
    
    # 2. Detailed TCP scan
    echo "2. Performing detailed TCP scan on open ports..."
    if [[ "$QUICK_MODE" == true ]]; then
        sudo nmap -sCV -p "$PORTS" $TIMING "$TARGET" \
            -oA "$OUTPUT_DIR/${TARGET}_tcp_quick" >> "$LOG_FILE" 2>&1
        TCP_OUTPUT="${TARGET}_tcp_quick"
    else
        sudo nmap -sCV -A -p "$PORTS" $TIMING "$TARGET" \
            -oA "$OUTPUT_DIR/${TARGET}_tcp_detailed" >> "$LOG_FILE" 2>&1
        TCP_OUTPUT="${TARGET}_tcp_detailed"
    fi
fi

# Wait for UDP scan to finish
echo "Waiting for UDP scan to complete..."
wait $UDP_PID || {
    echo "UDP scan failed or was interrupted." | tee -a "$LOG_FILE"
}

echo ""
echo "All scans complete!"
echo ""
echo "Results are in: $OUTPUT_DIR"
echo "Summary:"
echo "  • TCP open ports list: ${TARGET}_tcp_open_ports.txt"
if [[ $OPEN_COUNT -gt 0 ]]; then
    echo "  • TCP detailed scan:   $TCP_OUTPUT.nmap (and .gnmap, .xml)"
else
    echo "  • TCP detailed scan:   Skipped (no open ports)"
fi
echo "  • UDP scan (top $UDP_PORTS): ${TARGET}_udp_top${UDP_PORTS}.nmap (and .gnmap, .xml)"
echo "  • Full log:            scan.log"
echo ""

echo "     XML files can be viewed nicely with tools like 'nmap-bootstrap.xsl' or converted to HTML."
