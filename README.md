# Nmapper.sh - lightweight nmap scanning script 

A smart Bash wrapper around Nmap that performs fast, parallel TCP and UDP scanning with organized output.

## Features

- Full TCP port discovery (`-p-`) + detailed scan with version detection and scripts (`-sCV -A` or lighter `-sCV`)
- Parallel UDP scan on the top N most common ports (default: 1000)
- Aggressive timing for faster scans (`-T4 --min-rate 500`)
- All results saved in a timestamped folder with normal, grepable, and XML output
- Command-line options and interactive mode
- Host reachability check and input validation
- Comprehensive logging

## Requirements

- Linux system with `nmap` installed
- `sudo` privileges (required for raw packet scans)

## Usage

chmod +x nmapper.sh
./nmapper.sh [options] [target]

## Options

```
-u N, --udp-ports N    Scan top N UDP ports (default: 1000)
--quick                 Quick TCP scan (skip heavy -A: no OS detection or traceroute)
-h, --help            Show help
```

## Examples

```Bash
./nmapper.sh 192.168.1.10                  # Standard scan on IP
./nmapper.sh -u 3000 10.0.0.5              # Scan top 3000 UDP ports
./nmapper.sh --quick scanme.nmap.org       # Quick mode on a hostname
./nmapper.sh                               # Interactive prompt for target
```
### Output
Results are saved in a directory like:
```
textnmap_results_20251218_143022_192_168_1_10/
├── 192.168.1.10_tcp_open_ports.txt
├── 192.168.1.10_tcp_open_ports.grepable
├── 192.168.1.10_tcp_detailed.nmap      (or _tcp_quick.nmap)
├── 192.168.1.10_tcp_detailed.gnmap
├── 192.168.1.10_tcp_detailed.xml
├── 192.168.1.10_udp_top1000.nmap
├── 192.168.1.10_udp_top1000.gnmap
├── 192.168.1.10_udp_top1000.xml
└── scan.log                            # Full log of everything
```
Legal Notice
Only scan systems you own or have explicit written permission to test. Unauthorized scanning may violate laws such as the Computer Fraud and Abuse Act (US) or similar regulations in other countries.
Enjoy responsible scanning!
