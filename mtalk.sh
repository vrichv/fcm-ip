#!/bin/bash

# IPv4 and IPv6 lists
IPV4_LIST="74.125.200.188 74.125.71.188 64.233.188.188 108.177.97.188 108.177.15.188 74.125.23.188 74.125.23.188 142.251.2.188 108.177.97.188 142.251.8.188 142.250.0.188"
IPV6_LIST="2404:6800:4008:c19::bc 2404:6800:4008:c15::bc 2404:6800:4003:c1a::bc 2404:6800:4008:c01::bc 2404:6800:4003:c04::bc 2800:3f0:4003:c03::bc 2404:6800:4008:c06::bc 2a00:1450:400c:c09::bc 2a00:1450:400c:c0a::bc 2607:f8b0:4004:c21::bc 2404:6800:4003:c05::bc 2607:f8b0:4023:c03::bc 2607:f8b0:400e:c0c::bc 2404:6800:4008:c13::bc 2a00:1450:400c:c06::bc 2800:3f0:4003:c0f::bc"

# Domain assignments
IPV6_DOMAINS="mtalk.google.com alt7-mtalk.google.com alt1-mtalk.google.com alt3-mtalk.google.com alt5-mtalk.google.com"
IPV4_DOMAINS="mtalk4.google.com alt8-mtalk.google.com alt2-mtalk.google.com alt6-mtalk.google.com alt4-mtalk.google.com"

# Global priority domains order (optimized - defined once)
PRIORITY_DOMAINS="mtalk.google.com mtalk4.google.com alt1-mtalk.google.com alt2-mtalk.google.com alt3-mtalk.google.com alt4-mtalk.google.com alt5-mtalk.google.com alt6-mtalk.google.com alt7-mtalk.google.com alt8-mtalk.google.com"

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Google FCM service's IP optimization tool - finds the best performing IPs and assigns them to FCM domains.

OPTIONS:
    -4          IPv4 only mode
    -host       Output in hosts file format instead of AdGuard format
    -h          Show this help message

OUTPUT FORMATS:
    Default (AdGuard): ||domain^$dnsrewrite=IP
    Hosts (-host):     IP domain

EOF
}

# Parse command line arguments
IPV4_ONLY=0
HOSTS_FORMAT=0

for arg in "$@"; do
    case $arg in
        -4)
            IPV4_ONLY=1
            ;;
        -host)
            HOSTS_FORMAT=1
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

# Function to ping and get average latency
ping_ip() {
    local ip=$1
    local result
    
    if echo "$ip" | grep -q ":"; then
        # IPv6
        result=$(ping6 -c 5 -W 2 "$ip" 2>/dev/null | grep "avg" | cut -d'/' -f5)
    else
        # IPv4
        result=$(ping -c 5 -W 2 "$ip" 2>/dev/null | grep "avg" | cut -d'/' -f5)
    fi
    
    if [ -n "$result" ] && [ "$result" != "0.000" ]; then
        echo "$ip $result"
    fi
}

# Function to test IPs concurrently
test_ips() {
    local ip_list="$1"
    local temp_file="/tmp/ping_results_$$"
    
    # Clear temp file
    > "$temp_file"
    
    # Start concurrent pings
    for ip in $ip_list; do
        ping_ip "$ip" >> "$temp_file" &
    done
    
    # Wait for all pings to complete
    wait
    
    # Sort by latency and return results
    if [ -s "$temp_file" ]; then
        sort -k2 -n "$temp_file"
    fi
    
    rm -f "$temp_file"
}

echo "Testing IPv4 addresses..."
IPV4_RESULTS=$(test_ips "$IPV4_LIST")

if [ "$IPV4_ONLY" -eq 0 ]; then
    echo "Testing IPv6 addresses..."
    IPV6_RESULTS=$(test_ips "$IPV6_LIST")
fi

# Function to assign domains to IPs
assign_domains() {
    local results="$1"
    local domains="$2"
    local assignments=""
    
    # Convert results to arrays - skip empty lines
    local ips=""
    
    # Extract IPs from results (results format: "ip latency")
    echo "$results" | while read -r ip latency; do
        if [ -n "$ip" ] && [ -n "$latency" ]; then
            echo "$ip"
        fi
    done > "/tmp/ips_$$"
    
    ips=$(cat "/tmp/ips_$$" | tr '\n' ' ')
    rm -f "/tmp/ips_$$"
    
    # Assign each domain to the corresponding best IP (1st domain = best IP, 2nd domain = 2nd best IP, etc.)
    local domain_index=0
    for domain in $domains; do
        domain_index=$((domain_index + 1))
        
        # Get the IP at this position
        local current_ip=$(echo $ips | cut -d' ' -f$domain_index)
        
        # If we run out of IPs, loop back to the beginning
        if [ -z "$current_ip" ]; then
            local total_ips=$(echo $ips | wc -w)
            if [ "$total_ips" -gt 0 ]; then
                local loop_index=$(((domain_index - 1) % total_ips + 1))
                current_ip=$(echo $ips | cut -d' ' -f$loop_index)
            fi
        fi
        
        if [ -n "$current_ip" ]; then
            if [ -z "$assignments" ]; then
                assignments="$domain $current_ip"
            else
                assignments="$assignments\n$domain $current_ip"
            fi
        fi
    done
    
    echo -e "$assignments"
}

# Assign domains to best IPs
if [ -n "$IPV4_RESULTS" ]; then
    IPV4_ASSIGNMENTS=$(assign_domains "$IPV4_RESULTS" "$IPV4_DOMAINS")
fi

# For IPv6 domains: use IPv6 results if available, otherwise use IPv4 results (for -4 mode)
if [ "$IPV4_ONLY" -eq 1 ]; then
    # In IPv4-only mode, assign IPv4 IPs to IPv6 domains too, but mtalk.google.com gets best IP
    if [ -n "$IPV4_RESULTS" ]; then
        IPV6_ASSIGNMENTS=$(assign_domains "$IPV4_RESULTS" "$IPV6_DOMAINS")
    fi
elif [ -n "$IPV6_RESULTS" ]; then
    IPV6_ASSIGNMENTS=$(assign_domains "$IPV6_RESULTS" "$IPV6_DOMAINS")
fi

# Function to get latency for an IP from results
get_latency() {
    local target_ip="$1"
    local results="$2"
    
    while read -r ip latency; do
        if [ "$ip" = "$target_ip" ]; then
            echo "$latency"
            return
        fi
    done << EOF
$results
EOF
}

# Function to print final results sorted by domain priority
print_final_results() {
    echo ""
    echo "=== Final Ping Results (sorted by domain priority) ==="
    
    # Combine all assignments into a temp file for better handling
    local temp_assignments="/tmp/assignments_$$"
    > "$temp_assignments"
    
    if [ -n "$IPV4_ASSIGNMENTS" ]; then
        echo -e "$IPV4_ASSIGNMENTS" >> "$temp_assignments"
    fi
    if [ -n "$IPV6_ASSIGNMENTS" ]; then
        echo -e "$IPV6_ASSIGNMENTS" >> "$temp_assignments"
    fi
    
    # Print results in priority order using global PRIORITY_DOMAINS
    for priority_domain in $PRIORITY_DOMAINS; do
        # Find matching assignment
        local found_line=$(grep "^$priority_domain " "$temp_assignments" 2>/dev/null)
        if [ -n "$found_line" ]; then
            local domain=$(echo "$found_line" | cut -d' ' -f1)
            local ip=$(echo "$found_line" | cut -d' ' -f2)
            
            if [ -n "$ip" ]; then
                # Get latency for this IP
                local latency=""
                if echo "$ip" | grep -q ":"; then
                    # IPv6 - but in -4 mode, IPv6 domains might have IPv4 IPs
                    if [ "$IPV4_ONLY" -eq 1 ]; then
                        latency=$(get_latency "$ip" "$IPV4_RESULTS")
                    else
                        latency=$(get_latency "$ip" "$IPV6_RESULTS")
                    fi
                else
                    # IPv4
                    latency=$(get_latency "$ip" "$IPV4_RESULTS")
                fi
                
                if [ -n "$latency" ]; then
                    printf "%-25s %-40s (avg: %sms)\n" "$domain" "$ip" "$latency"
                else
                    printf "%-25s %-40s (no latency data)\n" "$domain" "$ip"
                fi
            fi
        fi
    done
    
    rm -f "$temp_assignments"
}

# Function to output results in priority order
output_priority_results() {
    local format="$1"  # "hosts" or "adguard"
    
    # Combine all assignments into a temp file for better handling
    local temp_assignments="/tmp/output_assignments_$$"
    > "$temp_assignments"
    
    if [ -n "$IPV4_ASSIGNMENTS" ]; then
        echo -e "$IPV4_ASSIGNMENTS" >> "$temp_assignments"
    fi
    if [ -n "$IPV6_ASSIGNMENTS" ]; then
        echo -e "$IPV6_ASSIGNMENTS" >> "$temp_assignments"
    fi
    
    # Output results in priority order using global PRIORITY_DOMAINS
    for priority_domain in $PRIORITY_DOMAINS; do
        # Find matching assignment
        local found_line=$(grep "^$priority_domain " "$temp_assignments" 2>/dev/null)
        if [ -n "$found_line" ]; then
            local domain=$(echo "$found_line" | cut -d' ' -f1)
            local ip=$(echo "$found_line" | cut -d' ' -f2)
            
            if [ -n "$ip" ]; then
                if [ "$format" = "hosts" ]; then
                    echo "$ip $domain"
                else
                    echo "||$domain^\$dnsrewrite=$ip"
                fi
            fi
        fi
    done
    
    rm -f "$temp_assignments"
}

# Output results
if [ "$HOSTS_FORMAT" -eq 1 ]; then
    # Hosts file format
    echo "=== For /etc/hosts ==="
    output_priority_results "hosts"
else
    # AdGuard format
    echo "=== For AdGuardHome ==="
    output_priority_results "adguard"
fi

# Print final ping results summary
print_final_results