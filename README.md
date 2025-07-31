# FCM-IP

A Google FCM service IP optimization tool that finds the best performing IPs and assigns them to FCM domains.

## Description

This tool optimizes Google Firebase Cloud Messaging (FCM) connectivity by testing and selecting the fastest IP addresses for FCM domains. It generates configuration files compatible with AdGuardHome or `/etc/hosts` for improved messaging performance.

## Features

- FCM domain optimization  
- AdGuardHome configuration output
- `/etc/hosts` file generation

## Installation & Usage

### Options

| Option | Description |
|--------|-------------|
| `-4` | IPv4 only mode |
| `-host` | Output in hosts file format instead of AdGuardHome format |
| `-h` | Show help message |

### Quick Run
```bash
# Default run (AdGuard format)
curl -fsSL https://raw.githubusercontent.com/vrichv/fcm-ip/main/mtalk.sh | bash

# IPv4 only mode
curl -fsSL https://raw.githubusercontent.com/vrichv/fcm-ip/main/mtalk.sh | bash -s -- -4

```

### Usage Examples
```bash
> ./mtalk.sh
Testing IPv4 addresses...
Testing IPv6 addresses...
=== For AdGuardHome ===
||mtalk.google.com^$dnsrewrite=2404:6800:4003:c1a::bc
||mtalk4.google.com^$dnsrewrite=74.125.200.188
||alt1-mtalk.google.com^$dnsrewrite=2404:6800:4008:c15::bc
||alt2-mtalk.google.com^$dnsrewrite=142.250.0.188
||alt3-mtalk.google.com^$dnsrewrite=2607:f8b0:400e:c0c::bc
||alt4-mtalk.google.com^$dnsrewrite=74.125.71.188
||alt5-mtalk.google.com^$dnsrewrite=2a00:1450:400c:c0a::bc
||alt6-mtalk.google.com^$dnsrewrite=74.125.200.188
||alt7-mtalk.google.com^$dnsrewrite=2404:6800:4003:c04::bc
||alt8-mtalk.google.com^$dnsrewrite=74.125.71.188


=== Final Ping Results (sorted by domain priority) ===
mtalk.google.com          2404:6800:4003:c1a::bc                   (avg: 55.186ms)
mtalk4.google.com         74.125.200.188                           (avg: 209.520ms)
alt1-mtalk.google.com     2404:6800:4008:c15::bc                   (avg: 81.463ms)
alt2-mtalk.google.com     142.250.0.188                            (avg: 318.822ms)
alt3-mtalk.google.com     2607:f8b0:400e:c0c::bc                   (avg: 191.544ms)
alt4-mtalk.google.com     74.125.71.188                            (avg: 244.042ms)
alt5-mtalk.google.com     2a00:1450:400c:c0a::bc                   (avg: 210.587ms)
alt6-mtalk.google.com     74.125.200.188                           (avg: 209.520ms)
alt7-mtalk.google.com     2404:6800:4003:c04::bc                   (avg: 57.608ms)
alt8-mtalk.google.com     74.125.71.188                            (avg: 244.042ms)

# IPv4 only with hosts format
> ./mtalk.sh -4 -host

# Show help
> ./mtalk.sh -h
```


## Output

The tool generates optimized configurations for:
- **AdGuardHome**: DNS rewrites for FCM domains
- **Hosts file**: Direct IP mappings for `/etc/hosts`

## License

This project is open source and available under the MIT License.

