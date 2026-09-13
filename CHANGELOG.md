# Changelog

## 7.0-1 - 2026-09-13

- mantém certificados expirados no discovery por até 30 dias;
- exclui automaticamente do LLD certificados expirados há mais de 30 dias;
- exclui automaticamente do LLD certificados revogados;
- não remove nem altera arquivos da PKI Easy-RSA;
- adiciona `ignored_old_expired` e `ignored_revoked` ao resumo;
- adiciona itens Zabbix para os novos contadores;
- inclui configuração externa para `PKI_DIR` e `EXPIRED_KEEP_DAYS`;
- inclui documentação de instalação e testes.

## 7.0-0

- versão inicial do monitoramento OpenVPN/Easy-RSA por Zabbix Agent 2;
- item mestre JSON;
- métricas agregadas;
- discovery LLD por certificado;
- alertas por 60/30/15/7 dias e certificado expirado.
