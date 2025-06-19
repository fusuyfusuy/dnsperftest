#!/usr/bin/env bash

# Enhanced DNS performance benchmarker
# Includes cache warming, statistics, and parallel testing

# Check for required commands
command -v bc > /dev/null || { echo "error: bc not found. Please install bc."; exit 1; }
command -v drill > /dev/null && dig="drill" || { command -v dig > /dev/null && dig="dig" || { echo "error: dig not found. Please install dnsutils."; exit 1; } }

# Configuration - FAST MODE
WARMUP_RUNS=0          # Skip warmup for speed
TEST_RUNS=1            # Single run per domain
TIMEOUT=1              # 1 second timeout max
PARALLEL_JOBS=10       # More parallel jobs
SHOW_PROGRESS=true

# Extract nameservers from /etc/resolv.conf and add local Unbound
NAMESERVERS=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf)
NAMESERVERS="$NAMESERVERS 127.0.0.1#LocalUnbound"

# Define DNS providers
PROVIDERSV4="
1.1.1.1#Cloudflare
8.8.8.8#Google
9.9.9.9#Quad9
208.67.222.222#OpenDNS
94.140.14.14#Adguard
76.76.2.0#ControlD
84.200.69.80#DNS.Watch
216.146.35.35#Dyn
"

PROVIDERSV6="
2606:4700:4700::1111#CloudflareV6
2606:4700:4700::1001#CloudflareMalwareV6
2001:4860:4860::8888#GoogleV6
2001:4860:4860::8844#GoogleSecondaryV6
2620:fe::fe#Quad9V6
2620:119:35::35#OpenDNSV6
2a10:50c0::ad1:ff#AdguardV6
"

# Test for IPv6 support
if $dig +short -6 @2606:4700:4700::1111 cloudflare.com > /dev/null 2>&1; then
    hasipv6=true
else
    hasipv6=false
fi

# Determine providers to test
providerstotest=$PROVIDERSV4
case "$1" in
    ipv6)
        [ "$hasipv6" != "true" ] && { echo "error: IPv6 support not found."; exit 1; }
        providerstotest=$PROVIDERSV6
        ;;
    all)
        [ "$hasipv6" = "true" ] && providerstotest="$PROVIDERSV4 $PROVIDERSV6"
        ;;
    local)
        providerstotest="127.0.0.1#LocalUnbound"
        ;;
esac

# Domains to test (reduced set for faster testing)
DOMAINS2TEST="google.com amazon.com facebook.com youtube.com reddit.com wikipedia.org twitter.com github.com stackoverflow.com netflix.com spotify.com instagram.com linkedin.com apple.com microsoft.com"

# Extended domain list (use with --full flag)
DOMAINS2TEST_FULL="google.com amazon.com facebook.com www.youtube.com www.reddit.com wikipedia.org twitter.com www.tokopedia.com whatsapp.com tiktok.com instagram.com linkedin.com pinterest.com snapchat.com discord.com twitch.tv spotify.com netflix.com hulu.com disney.com apple.com microsoft.com github.com stackoverflow.com medium.com wordpress.com blogger.com tumblr.com vimeo.com dailymotion.com soundcloud.com dropbox.com onedrive.live.com drive.google.com icloud.com zoom.us slack.com teams.microsoft.com telegram.org signal.org paypal.com stripe.com square.com coinbase.com binance.com kraken.com shopify.com ebay.com etsy.com alibaba.com aliexpress.com booking.com airbnb.com expedia.com uber.com lyft.com cnn.com bbc.com reuters.com bloomberg.com techcrunch.com theverge.com arstechnica.com wired.com steam.com epicgames.com oracle.com intel.com amd.com nvidia.com samsung.com sony.com canon.com"

# Use full domain list if --full flag is provided
[ "$2" = "--full" ] || [ "$1" = "--full" ] && DOMAINS2TEST=$DOMAINS2TEST_FULL

# Function to test DNS provider
test_dns_provider() {
    local provider=$1
    local pip=${provider%%#*}
    local pname=${provider##*#}
    local times=()
    local failed=0
    local total_time=0
    local is_parallel=${2:-false}

    # Handle port in IP address
    local dig_target="@$pip"
    if [[ "$pip" == *":"* ]]; then
        local ip=${pip%%:*}
        local port=${pip##*:}
        dig_target="@$ip -p $port"
    fi

    # Warmup runs
    for ((w=1; w<=WARMUP_RUNS; w++)); do
        for d in $DOMAINS2TEST; do
            $dig +tries=1 +time=$TIMEOUT $dig_target $d > /dev/null 2>&1
        done
    done

    # Actual test runs
    local domain_count=0
    local total_domains=$(wc -w <<< "$DOMAINS2TEST")

    for d in $DOMAINS2TEST; do
        ((domain_count++))

        local best_time=9999
        for ((r=1; r<=TEST_RUNS; r++)); do
            local ttime=$($dig +tries=1 +time=$TIMEOUT $dig_target $d 2>/dev/null | awk '/Query time:/ {print $4}')
            if [[ -n "$ttime" && "$ttime" -lt "$best_time" ]]; then
                best_time=$ttime
            fi
        done

        if [[ "$best_time" -eq 9999 ]]; then
            failed=$((failed + 1))
            best_time=1000
        fi

        times+=($best_time)
        total_time=$((total_time + best_time))
    done

    # Calculate statistics
    local count=${#times[@]}
    local avg=$(bc <<< "scale=2; $total_time/$count")

    # Sort times for median calculation
    IFS=$'\n' sorted=($(sort -n <<<"${times[*]}"))
    unset IFS

    local median
    if [[ $((count % 2)) -eq 1 ]]; then
        median=${sorted[$((count/2))]}
    else
        median=$(bc <<< "scale=1; (${sorted[$((count/2-1))]} + ${sorted[$((count/2))]}) / 2")
    fi

    local min=${sorted[0]}
    local max=${sorted[$((count-1))]}
    local success_rate=$(bc <<< "scale=1; ($count - $failed) * 100 / $count")

    printf "%-20s %8s %8s %8s %8s %8s%%\n" "$pname" "${avg}ms" "${median}ms" "${min}ms" "${max}ms" "$success_rate"
}

# Display header
totaldomains=$(wc -w <<< "$DOMAINS2TEST")
total_nameservers=$(wc -w <<< "$NAMESERVERS")
total_external=0
[[ -n "$providerstotest" ]] && total_external=$(echo "$providerstotest" | wc -w)

# Calculate estimated time (much faster now)
estimated_time_per_provider=$((totaldomains * TIMEOUT / 2))  # Optimistic estimate
total_time_local=$((total_nameservers * estimated_time_per_provider))
total_time_external=$((total_external * estimated_time_per_provider / PARALLEL_JOBS))
estimated_total=$((total_time_local + total_time_external))

echo "⚡ FAST DNS Performance Benchmarker"
echo "=================================="
echo "📊 Testing $totaldomains domains with single run (no warmup for speed)"
echo "⏱️  Timeout: ${TIMEOUT}s per query"
echo "🖥️  Local resolvers: $total_nameservers"
echo "🌐 External providers: $total_external"
echo "🚀 Estimated time: ~${estimated_total}s"
echo ""
printf "%-20s %8s %8s %8s %8s %8s\n" "Provider" "Avg" "Median" "Min" "Max" "Success"
printf "%-20s %8s %8s %8s %8s %8s\n" "--------" "---" "------" "---" "---" "-------"

# Test nameservers first (local resolvers) - with live progress
if [[ -n "$NAMESERVERS" ]]; then
    echo ""
    echo "🔄 Testing local resolvers..."
    for ns in $NAMESERVERS; do
        test_dns_provider "$ns" "false"
    done
else
    echo ""
    echo "⚠️  No local resolvers found"
fi

# Test external providers (if any)
if [[ -n "$providerstotest" ]]; then
    echo ""
    printf "%-20s %8s %8s %8s %8s %8s\n" "External Providers" "---" "------" "---" "---" "-------"

    # Test providers in parallel batches
    providers_array=($providerstotest)
    total_providers=${#providers_array[@]}
    tested_providers=0

    echo "🔄 Testing $total_providers external providers in parallel batches..."

    for ((i=0; i<${#providers_array[@]}; i+=PARALLEL_JOBS)); do
        batch=("${providers_array[@]:i:PARALLEL_JOBS}")
        batch_size=${#batch[@]}

        echo -n "   Batch $((i/PARALLEL_JOBS + 1)): testing ${batch_size} providers... "

        # Create temp files for parallel results
        temp_dir=$(mktemp -d)

        # Start parallel tests
        for j in "${!batch[@]}"; do
            provider="${batch[j]}"
            if [ -n "$provider" ]; then
                (
                    result=$(test_dns_provider "$provider" "true" 2>/dev/null)
                    echo "$result" > "$temp_dir/result_$j"
                ) &
            fi
        done

        # Show spinner while waiting
        spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        while [[ $(jobs -r | wc -l) -gt 0 ]]; do
            for char in $(echo "$spin_chars" | grep -o .); do
                printf "\r   Batch $((i/PARALLEL_JOBS + 1)): testing ${batch_size} providers... %s" "$char"
                sleep 0.1
                [[ $(jobs -r | wc -l) -eq 0 ]] && break 2
            done
        done

        wait  # Ensure all background jobs complete
        printf "\r   Batch $((i/PARALLEL_JOBS + 1)): testing ${batch_size} providers... ✅\n"

        # Display results after spinner completes
        for j in "${!batch[@]}"; do
            if [ -f "$temp_dir/result_$j" ]; then
                cat "$temp_dir/result_$j"
            fi
        done

        rm -rf "$temp_dir"
        tested_providers=$((tested_providers + batch_size))
    done

    echo "✅ Testing complete! Tested $tested_providers providers."
else
    echo ""
    echo "ℹ️  Local-only mode: skipping external providers"
fi

echo ""
echo "📋 Usage: $0 [ipv4|ipv6|all|local] [--full]"
echo "  ipv4: Test IPv4 providers only (default)"
echo "  ipv6: Test IPv6 providers only"
echo "  all:  Test both IPv4 and IPv6 providers"
echo "  local: Test only local Unbound server"
echo "  --full: Use extended domain list (16 domains vs 5)"
echo ""
echo "⚡ FAST MODE Features:"
echo "  • No warmup runs for maximum speed"
echo "  • Single test run per domain"
echo "  • 1 second timeout"
echo "  • Parallel testing (10 concurrent)"
echo "  • Optimized provider list"
echo "  • Results in ~10-30 seconds"

exit 0
