# OpenVPN / Easy-RSA Certificate Monitor for Zabbix 7.0

**English** | [Português (Brasil)](README.pt-BR.md)

Reusable monitoring kit for OpenVPN/Easy-RSA X.509 certificates using Zabbix Agent 2.

## What it monitors

- total certificates in `pki/issued`;
- valid, expired, and revoked certificates;
- certificates expiring within 60, 30, 15, and 7 days;
- remaining days per certificate;
- expiration date, serial number, and status;
- collector read/parsing errors;
- number of old expired certificates excluded from discovery;
- number of revoked certificates excluded from discovery.

## Monitoring cleanup policy

The collector **does not delete certificates and does not modify the PKI**.

By default:

- valid certificate: monitored normally;
- expired for 0 to 30 days: remains in Zabbix and keeps the alert active;
- expired for more than 30 days: remains in Easy-RSA but is excluded from LLD;
- revoked: remains in Easy-RSA but is excluded from LLD.

The template uses `lifetime: 7d`, so resources that disappear from discovery are removed by Zabbix after that period.

## Requirements

- Linux
- OpenVPN
- Easy-RSA
- OpenSSL
- Zabbix Agent 2
- Zabbix Server 7.0
- `sudo`
- `jq` recommended for testing

## Files

```text
openvpn-cert-monitor.sh
openvpn-cert-monitor.conf.example
zabbix_agent2_openvpn-cert-monitor.conf
sudoers_openvpn-cert-monitor
template_openvpn_certificates_zabbix_7.0.yaml
README.md
README.pt-BR.md
CHANGELOG.md
```

## Installation

Clone the repository on the server that stores the Easy-RSA PKI:

```bash
git clone https://github.com/Flawioo/zabbix-openvpn-certificates.git
cd zabbix-openvpn-certificates
```

Install the collector:

```bash
install -d -m 0755 /usr/local/libexec/zabbix
install -m 0755 openvpn-cert-monitor.sh /usr/local/libexec/zabbix/openvpn-cert-monitor.sh
```

Install the configuration file:

```bash
cp openvpn-cert-monitor.conf.example /etc/zabbix/openvpn-cert-monitor.conf
```

Install the UserParameter:

```bash
cp zabbix_agent2_openvpn-cert-monitor.conf /etc/zabbix/zabbix_agent2.d/openvpn-cert-monitor.conf
```

Install and validate the sudoers rule:

```bash
cp sudoers_openvpn-cert-monitor /etc/sudoers.d/zabbix-openvpn-cert-monitor
chmod 440 /etc/sudoers.d/zabbix-openvpn-cert-monitor
visudo -cf /etc/sudoers.d/zabbix-openvpn-cert-monitor
```

Restart the agent:

```bash
systemctl restart zabbix-agent2
```

## Configuration

The default PKI path is:

```text
/etc/openvpn/easy-rsa/pki
```

To use a different path or change expired-certificate retention, edit:

```bash
vi /etc/zabbix/openvpn-cert-monitor.conf
```

Example:

```bash
PKI_DIR="/etc/openvpn/easy-rsa/pki"
EXPIRED_KEEP_DAYS=30
```

## Testing

Test the collector directly:

```bash
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh | jq '.summary'
```

Test it as the Zabbix agent user:

```bash
sudo -u zabbix /usr/local/libexec/zabbix/openvpn-cert-monitor.sh | jq '.summary'
```

List expired certificates that are still present in discovery:

```bash
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh | \
jq '.certificates[] | select(.status=="EXPIRED") | {name,days_left,status}'
```

With the default configuration, no certificate with `days_left < -30` should appear.

Confirm that revoked certificates are excluded from discovery:

```bash
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh | \
jq '.certificates[] | select(.status=="REVOKED")'
```

The expected output is empty.

## Zabbix

Import:

```text
template_openvpn_certificates_zabbix_7.0.yaml
```

Then link the template:

```text
OpenVPN certificates by Zabbix agent 2
```

to the host running Easy-RSA.

The master item is:

```text
openvpn.certificates.get
```

The default collection interval is controlled by:

```text
{$OPENVPN.CERT.INTERVAL}
```

## When a certificate is renewed or recreated

The collector identifies each certificate by the serial number used in LLD. A recreated certificate with a new serial number is discovered as a new resource.

Old revoked certificates, or expired certificates beyond the configured retention period, automatically stop participating in discovery.

## Security

Zabbix never receives private keys.

The collector reads only public metadata from `.crt` files and certificate state from `pki/index.txt`.

The sudoers rule allows the `zabbix` user to execute only:

```text
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh
```
