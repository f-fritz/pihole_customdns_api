# Pi-hole customdns API Script

Bash script to connect to the Pi-hole HTTP API to add or edit customdns entries.

This might be useful when using Pi-hole as a local DNS server for a home lab environment. Can be used in automations to automatically register DNS names for VMs or containers.

Alternatively, use ansible etc. and directly edit `/etc/pihole/custom.list` on the Pi-hole host.

Use at your own risk.

## Usage

### Setup

Create `.env` file, e.g. by executing
```
cp .env.template .env
```
and fill in the parameters that match your setup. The API token ca be obtained via
- Web Admin > Settings (Sidebar) > API (Tab) > Show API token (Button)
- `cat /etc/pihole/setupVars.conf | grep WEBPASSWORD` on the Pi-hole host

### Usage

```
./pihole-customdns.sh <domain> <ip_address>
```

- If there is no entry for `<domain>` yet, the entry will be added.
- If an entry for `<domain>` exist, the existing entry will be deleted before adding the new entry (the API only provides, add, delete and get operation - no update / edit). 
