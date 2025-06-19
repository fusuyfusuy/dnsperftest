# DNS Performance Benchmarker

A comprehensive shell script to benchmark DNS resolver performance from your location with advanced features like cache warming, statistical analysis, and parallel testing.

## Features

- **Cache Warming**: Performs warmup runs before testing for accurate results
- **Multiple Test Runs**: Executes multiple queries per domain and reports best times
- **Comprehensive Statistics**: Shows average, median, min, max, and success rates
- **Parallel Testing**: Tests multiple providers simultaneously for faster execution
- **Flexible Modes**: Support for IPv4, IPv6, local-only, or combined testing
- **Extended Domain Lists**: Choose between quick test or comprehensive domain coverage
- **Local Resolver Support**: Automatically detects and tests your local Unbound/Pi-hole setup

## Quick Start

```bash
git clone https://github.com/your-repo/dns-benchmarker
cd dns-benchmarker
chmod +x dns-bench.sh
./dns-bench.sh
```

## Requirements

Install required dependencies:

**Ubuntu/Debian:**
```bash
sudo apt-get install bc dnsutils
```

**RHEL/CentOS/Fedora:**
```bash
sudo dnf install bc dnsutils
```

**macOS:**
```bash
brew install bc bind
```

## Usage

### Basic Testing
```bash
./dns-bench.sh                    # Test IPv4 providers with core domains
./dns-bench.sh --full            # Test IPv4 providers with extended domain list
```

### Advanced Testing
```bash
./dns-bench.sh ipv6              # Test IPv6 providers only
./dns-bench.sh all               # Test both IPv4 and IPv6 providers
./dns-bench.sh local             # Test only local DNS server (Unbound/Pi-hole)
./dns-bench.sh all --full        # Comprehensive test with all domains
```

## Sample Output

```
Testing 16 domains with 3 runs each (after 2 warmup runs)
Timeout: 3s per query

Provider             Avg      Median   Min      Max      Success
--------             ---      ------   ---      ---      -------
LocalUnbound         2.1ms    2ms      1ms      6ms      100.0%
System DNS           8.4ms    7ms      4ms      18ms     100.0%

External Providers   ---      ------   ---      ---      -------
Cloudflare           18.2ms   17ms     12ms     28ms     100.0%
Google               19.8ms   18ms     14ms     32ms     100.0%
Quad9                22.1ms   21ms     16ms     45ms     100.0%
OpenDNS              25.4ms   24ms     18ms     58ms     98.5%
AdGuard              45.2ms   43ms     28ms     89ms     100.0%
NextDNS              28.7ms   27ms     19ms     65ms     100.0%
```

## Understanding Results

### Performance Metrics
- **Avg**: Average response time across all queries
- **Median**: Middle value (shows consistency better than average)
- **Min**: Fastest response time recorded
- **Max**: Slowest response time recorded  
- **Success**: Percentage of successful queries

### Performance Targets
- **Cached queries**: 0-5ms (excellent)
- **Local recursive (cold cache)**: 20-100ms (good)
- **External providers**: 10-50ms (acceptable)
- **Success rate**: 100% (ideal), 95%+ (acceptable)

## Tested DNS Providers

### Public DNS Providers
- **Cloudflare**: 1.1.1.1, 1.1.1.2 (malware blocking)
- **Google**: 8.8.8.8, 8.8.4.4
- **Quad9**: 9.9.9.9, 9.9.9.10 (security filtering)
- **OpenDNS**: 208.67.222.222, 208.67.220.220
- **AdGuard**: 176.103.130.132, 176.103.130.134 (ad blocking)
- **NextDNS**: 45.90.28.202
- **CleanBrowsing**: 185.228.168.168, 185.228.168.169
- **ControlD**: 76.76.2.0
- **AliDNS**: 223.5.5.5
- **Baidu**: 180.76.76.76

### Local Resolvers
- System DNS (from /etc/resolv.conf)
- Local Unbound (127.0.0.1:5335)
- Pi-hole or other local resolvers

## Test Domains

### Core Domain List (Default)
High-traffic domains for quick testing:
```
google.com, amazon.com, facebook.com, youtube.com, reddit.com,
wikipedia.org, twitter.com, github.com, stackoverflow.com,
netflix.com, spotify.com, discord.com, instagram.com,
linkedin.com, apple.com, microsoft.com
```

### Extended Domain List (--full flag)
100+ domains covering:
- **Social Media**: Instagram, TikTok, Snapchat, Discord, Twitch
- **Streaming**: Netflix, Hulu, Disney+, Spotify, SoundCloud  
- **E-commerce**: Amazon, eBay, Shopify, Alibaba, Etsy
- **Technology**: GitHub, Microsoft, Apple, Adobe, Unity
- **Productivity**: Zoom, Slack, Google Drive, Dropbox
- **Finance**: PayPal, Stripe, Coinbase, Binance
- **News**: CNN, BBC, Reuters, Bloomberg, TechCrunch
- **Gaming**: Steam, Epic Games, Origin, GOG
- **Cloud Services**: AWS, Azure, GCP endpoints
- **International**: Baidu, Yandex, VK, Naver, Kakao

## Configuration

### Script Parameters
```bash
WARMUP_RUNS=2          # Cache warming iterations
TEST_RUNS=3            # Test iterations per domain
TIMEOUT=3              # Query timeout in seconds
PARALLEL_JOBS=5        # Concurrent provider tests
```

### Adding Custom DNS Providers
Edit the script to add your own DNS servers:
```bash
PROVIDERSV4="
1.2.3.4#MyCustomDNS
$PROVIDERSV4
"
```

## Performance Optimization Tips

1. **Run multiple times** to see cache warming effects
2. **Local recursive resolvers** (Unbound) should show fastest times for cached queries
3. **Compare median vs average** - small difference indicates consistency
4. **Monitor success rates** - anything below 95% indicates reliability issues
5. **Use --full flag** for comprehensive testing when evaluating DNS providers

## Troubleshooting

### Common Issues

**Permission denied:**
```bash
chmod +x dns-bench.sh
```

**Command not found (bc or dig):**
Install dependencies as shown in Requirements section.

**IPv6 not supported:**
Script automatically detects IPv6 support. Use `ipv4` mode if IPv6 is unavailable.

**Timeout errors:**
Increase `TIMEOUT` value in script for slow networks.

## Why This Matters

DNS is the foundation of internet performance. A fast, reliable DNS resolver can:
- Reduce web page load times by 50-200ms per domain lookup
- Improve browsing responsiveness 
- Provide better privacy (local recursive resolvers)
- Offer content filtering (malware/ad blocking DNS)
- Reduce dependence on third-party DNS logging

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT License - feel free to modify and distribute.

## Credits

Enhanced version based on the original DNS performance test script, with significant improvements for accuracy, feature set, and usability.

Perfect for:
- Network administrators evaluating DNS infrastructure
- Privacy-conscious users setting up local resolvers
- Performance optimization enthusiasts
- Anyone wanting to benchmark their DNS setup properly
