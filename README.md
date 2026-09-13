# OpenVPN / Easy-RSA Certificate Monitor for Zabbix 7.0

Kit reutilizável para monitorar certificados X.509 de clientes OpenVPN/Easy-RSA usando Zabbix Agent 2.

## O que monitora

- total de certificados em `pki/issued`;
- certificados válidos, expirados e revogados;
- certificados que vencem em 60, 30, 15 e 7 dias;
- dias restantes por certificado;
- data de expiração, serial e status;
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

O template usa `lifetime: 7d`, portanto recursos que desaparecerem do discovery são removidos pelo Zabbix após esse período.

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
README.md
CHANGELOG.md
```

## Instalação

Clone o repositório no servidor que contém a PKI Easy-RSA:

```bash
git clone https://github.com/Flawioo/zabbix-openvpn-certificates.git
cd zabbix-openvpn-certificates
```

Instale o coletor:

```bash
install -d -m 0755 /usr/local/libexec/zabbix
install -m 0755 openvpn-cert-monitor.sh /usr/local/libexec/zabbix/openvpn-cert-monitor.sh
```

Instale a configuração:

```bash
cp openvpn-cert-monitor.conf.example /etc/zabbix/openvpn-cert-monitor.conf
```

Instale o UserParameter:

```bash
cp zabbix_agent2_openvpn-cert-monitor.conf /etc/zabbix/zabbix_agent2.d/openvpn-cert-monitor.conf
```

Instale a regra sudoers e valide:

```bash
cp sudoers_openvpn-cert-monitor /etc/sudoers.d/zabbix-openvpn-cert-monitor
chmod 440 /etc/sudoers.d/zabbix-openvpn-cert-monitor
visudo -cf /etc/sudoers.d/zabbix-openvpn-cert-monitor
```

Reinicie o agente:

```bash
systemctl restart zabbix-agent2
```

## Configuração

A configuração padrão considera a PKI em:

```text
/etc/openvpn/easy-rsa/pki
```

Para outro caminho ou para alterar a retenção de expirados, edite:

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

Liste certificados expirados que ainda permanecem no discovery:

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
