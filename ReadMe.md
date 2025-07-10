# Pi-hole customdns API Script

Bash script to connect to the Pi-hole HTTP API to add or edit custom DNS entries.

This might be useful when using Pi-hole as a local DNS server for a home lab environment. Can be used in automations to automatically register or unregister DNS names for VMs or containers.

Alternatively, use ansible etc. and directly edit `/etc/pihole/custom.list` on the Pi-hole host.

Use at your own risk.

## New in pihole v6

Authentication changed. You need to either set an password (via all settings or the pihole cli) without 2FA or to create an application password in order for this tool to work.
You need to allow sudo webapi access in order to add or delete entries via the API, see setup (below)

## Usage

### Setup

Create `.env` file, e.g. by executing
```
cp .env.template .env
```
and fill in the parameters that match your setup.

You need to enable sudo webapi acces in order to add or delete entries by setting a checkmark under System > Settings > All settings > Webserver and API > webserver.api.app_sudo. Don't forget to "Save & Apply" by hitting the button at the button right.

### Usage

```
Usage: ./pihole-customdns.sh [--add [--overwrite]] | [--remove] | [--get] <domain> <ip_address>
  --add           Add a custom DNS entry (default action if no flag provided)
  --overwrite     Overwrite an existing entry if the IP doesn't match
  --remove        Remove a custom DNS entry
  --get           List all existing custom DNS entries
  <domain>        Domain name for the custom DNS entry
  <ip_address>    IP address for the custom DNS entry

Examples:
  ./pihole-customdns.sh --add example.com 192.168.1.100
  ./pihole-customdns.sh --add --overwrite example.com 192.168.1.200
  ./pihole-customdns.sh --remove example.com 192.168.1.200
  ./pihole-customdns.sh --get
```

- If there is no entry for `<domain>` yet, the entry will be added.
- If an entry for `<domain>` exist and `--overwrite` is set, the existing entry will be deleted before adding the new entry (the API only provides, add, delete and get operation - no update / edit). 
- In order to delete an entry using `--remove` flag, `<domain>` and `<ip_address` must correspond to confirm the action.
