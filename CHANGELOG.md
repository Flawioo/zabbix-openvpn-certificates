# Changelog

## 7.0-1 - 2026-09-13

- keeps expired certificates in discovery for up to 30 days;
- automatically excludes certificates expired for more than 30 days from LLD;
- automatically excludes revoked certificates from LLD;
- does not remove or modify Easy-RSA PKI files;
- adds `ignored_old_expired` and `ignored_revoked` to the summary;
- adds Zabbix items for the new counters;
- adds external configuration for `PKI_DIR` and `EXPIRED_KEEP_DAYS`;
- adds installation and testing documentation;
- adds bilingual documentation with English as the default README and Brazilian Portuguese as `README.pt-BR.md`.

## 7.0-0

- initial OpenVPN/Easy-RSA monitoring version using Zabbix Agent 2;
- JSON master item;
- aggregated certificate metrics;
- per-certificate LLD discovery;
- alerts for 60/30/15/7 days and expired certificates.
