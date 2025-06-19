#!/usr/bin/env bash

# Enhanced DNS performance benchmarker
# Includes cache warming, statistics, and parallel testing

# Check for required commands
command -v bc > /dev/null || { echo "error: bc not found. Please install bc."; exit 1; }
command -v drill > /dev/null && dig="drill" || { command -v dig > /dev/null && dig="dig" || { echo "error: dig not found. Please install dnsutils."; exit 1; } }

# Configuration
WARMUP_RUNS=2
TEST_RUNS=3
TIMEOUT=1
PARALLEL_JOBS=5

# Extract nameservers from /etc/resolv.conf
NAMESERVERS=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf)
NAMESERVERS="$NAMESERVERS 127.0.0.1#LocalUnbound"

# Define DNS providers
PROVIDERSV4="
1.1.1.1#Cloudflare
1.1.1.2#CloudflareMalware
tls://one.one.one.one#CloudflareTLS
8.8.8.8#Google
8.8.4.4#GoogleSecondary
9.9.9.9#Quad9
9.9.9.10#Quad9Unsecured
208.67.222.222#OpenDNS
208.67.220.220#OpenDNSSecondary
94.140.14.14#Adguard
94.140.14.15#AdguardFamily
quic://dns.adguard-dns.com#AdguardQuic
76.76.2.0#ControlD
80.80.80.80#Freenom
84.200.69.80#DNS.Watch
216.146.35.35#Dyn
185.228.168.168#CleanBrowsing
185.228.168.10#CleanBrowsingAdult
8.26.56.26#Comodo
tls://dns.nextdns.io#NextDNS
195.46.39.39#SafeDNS
117.50.11.11#OneDNS
223.5.5.5#AliDNS
quic://dns.alidns.com:853#AliQuic
180.76.76.76#BaiduDNS
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
esac

# Domains to test (reduced set for faster testing)
DOMAINS2TEST="google.com amazon.com facebook.com youtube.com reddit.com wikipedia.org twitter.com github.com stackoverflow.com netflix.com spotify.com discord.com instagram.com linkedin.com apple.com microsoft.com"

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

    # Warmup runs
    for ((w=1; w<=WARMUP_RUNS; w++)); do
        for d in $DOMAINS2TEST; do
            $dig +tries=1 +time=$TIMEOUT @$pip $d > /dev/null 2>&1
        done
    done

    # Actual test runs
    for d in $DOMAINS2TEST; do
        local best_time=9999
        for ((r=1; r<=TEST_RUNS; r++)); do
            local ttime=$($dig +tries=1 +time=$TIMEOUT @$pip $d 2>/dev/null | awk '/Query time:/ {print $4}')
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
echo "Testing $totaldomains domains with $TEST_RUNS runs each (after $WARMUP_RUNS warmup runs)"
echo "Timeout: ${TIMEOUT}s per query"
echo ""
printf "%-20s %8s %8s %8s %8s %8s\n" "Provider" "Avg" "Median" "Min" "Max" "Success"
printf "%-20s %8s %8s %8s %8s %8s\n" "--------" "---" "------" "---" "---" "-------"

# Test nameservers first (local resolvers)
for ns in $NAMESERVERS; do
    test_dns_provider "$ns"
done

# Test external providers
echo ""
printf "%-20s %8s %8s %8s %8s %8s\n" "External Providers" "---" "------" "---" "---" "-------"

# Test providers in parallel batches
providers_array=($providerstotest)
for ((i=0; i<${#providers_array[@]}; i+=PARALLEL_JOBS)); do
    batch=("${providers_array[@]:i:PARALLEL_JOBS}")
    for provider in "${batch[@]}"; do
        [ -n "$provider" ] && test_dns_provider "$provider" &
    done
    wait
done

echo ""
echo "Usage: $0 [ipv4|ipv6|all|local] [--full]"
echo "  ipv4: Test IPv4 providers only (default)"
echo "  ipv6: Test IPv6 providers only"
echo "  all:  Test both IPv4 and IPv6 providers"
echo "  --full: Use extended domain list"

exit 0
