# OpenVPN / Easy-RSA Certificate Monitor for Zabbix 7.0

Kit reutilizável para monitorar certificados X.509 de clientes OpenVPN/Easy-RSA usando Zabbix Agent 2.

## O que monitora

- total de certificados em `pki/issued`;
- certificados válidos, expirados e revogados;
- certificados que vencem em 60, 30, 15 e 7 dias;
- dias restantes por certificado;
- data de expiração, serial, status e caminho do arquivo;
- erros de leitura do coletor;
- quantidade de expirados antigos retirados do discovery;
- quantidade de revogados retirados do discovery.

## Política de limpeza do monitoramento

O coletor **não apaga certificados nem altera a PKI**.

Por padrão:

- certificado válido: monitorado;
- expirado entre 0 e 30 dias: continua no Zabbix e mantém o alerta;
- expirado há mais de 30 dias: permanece no Easy-RSA, mas deixa de entrar no LLD;
- revogado: permanece no Easy-RSA, mas deixa de entrar no LLD.

O template usa `lifetime: 7d`, portanto recursos que desaparecerem do discovery são removidos pelo Zabbix após o período definido na regra LLD.

O prazo de 30 dias pode ser alterado em:

```bash
/etc/zabbix/openvpn-cert-monitor.conf
```

Exemplo:

```bash
EXPIRED_KEEP_DAYS=30
```

## Requisitos

- Linux
- OpenVPN
- Easy-RSA
- OpenSSL
- Zabbix Agent 2
- Zabbix Server 7.0
- `sudo`
- `jq` recomendado para testes

## Arquivos

```text
openvpn-cert-monitor.sh
openvpn-cert-monitor.conf.example
zabbix_agent2_openvpn-cert-monitor.conf
sudoers_openvpn-cert-monitor
template_openvpn_certificates_zabbix_7.0.yaml
install.sh
uninstall.sh
README.md
CHANGELOG.md
```

## Instalação

Clone ou copie este diretório para o servidor que contém a PKI Easy-RSA.

Execute:

```bash
chmod +x install.sh
sudo ./install.sh
```

O instalador cria:

```text
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh
/etc/zabbix/openvpn-cert-monitor.conf
/etc/zabbix/zabbix_agent2.d/openvpn-cert-monitor.conf
/etc/sudoers.d/zabbix-openvpn-cert-monitor
```

e reinicia o `zabbix-agent2`.

## Configuração

A configuração padrão considera a PKI em:

```text
/etc/openvpn/easy-rsa/pki
```

Para outro caminho, edite:

```bash
vi /etc/zabbix/openvpn-cert-monitor.conf
```

Exemplo:

```bash
PKI_DIR="/etc/openvpn/easy-rsa/pki"
EXPIRED_KEEP_DAYS=30
```

## Testes

Teste o coletor diretamente:

```bash
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh | jq '.summary'
```

Teste como o usuário do agente:

```bash
sudo -u zabbix /usr/local/libexec/zabbix/openvpn-cert-monitor.sh | jq '.summary'
```

Liste certificados que ainda estão expirados e visíveis no discovery:

```bash
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh | \
jq '.certificates[] | select(.status=="EXPIRED") | {name,days_left,status}'
```

Nenhum certificado com `days_left < -30` deve aparecer com a configuração padrão.

Confirme que certificados revogados foram retirados do discovery:

```bash
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh | \
jq '.certificates[] | select(.status=="REVOKED")'
```

O retorno esperado é vazio.

## Zabbix

Importe:

```text
template_openvpn_certificates_zabbix_7.0.yaml
```

Depois vincule o template:

```text
OpenVPN certificates by Zabbix agent 2
```

ao host que executa o Easy-RSA.

O item mestre é:

```text
openvpn.certificates.get
```

A coleta padrão do template é controlada por:

```text
{$OPENVPN.CERT.INTERVAL}
```

## Quando um certificado é renovado ou recriado

O coletor identifica cada certificado pelo serial usado no LLD. Um certificado recriado com novo serial será descoberto como um novo recurso.

Certificados antigos revogados ou expirados além do período configurado deixam automaticamente de participar do discovery.

## Segurança

O Zabbix não recebe nenhuma chave privada.

O coletor lê somente metadados públicos dos certificados `.crt` e o estado registrado em `pki/index.txt`.

A regra `sudoers` permite ao usuário `zabbix` executar somente:

```text
/usr/local/libexec/zabbix/openvpn-cert-monitor.sh
```

## Desinstalação

```bash
sudo ./uninstall.sh
```

A configuração `/etc/zabbix/openvpn-cert-monitor.conf` é preservada.
