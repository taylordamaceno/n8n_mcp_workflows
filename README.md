# MCP n8n + Cursor + Codex

## Visao geral
Este repositorio centraliza a configuracao do Model Context Protocol (MCP) para integrar o Cursor e o Codex com uma instancia do n8n. A ideia e simplificar o onboarding do time: um unico guia cobre desde a subida do n8n ate a conexao com os clientes MCP. Alem disso, o projeto serve como base versionada para documentacao, regras operacionais e scripts auxiliares.

## Sobre o repositorio
- Funciona como uma colecao de scripts, manifestos MCP e regras compartilhadas voltadas ao uso do n8n via Cursor e Codex.
- Os arquivos foram pensados para serem clonados e adaptados rapidamente por qualquer membro da equipe.
- Todo o conteudo evita expor segredos reais; mantenha a mesma abordagem ao contribuir.

## Requisitos minimos
- Cursor com suporte a MCP habilitado.
- Codex CLI instalado (caso utilize o fluxo por terminal).
- Node.js 18 ou superior para executar o pacote `n8n-mcp` via `npx` ou instalacao global.
- Instancia do n8n acessivel, com URL base e chave de API valida.
- Permissao para definir variaveis de ambiente locais e editar o arquivo `~/.bashrc` (ou equivalente).

## Estrutura do projeto
- `.cursor/mcp.json`: configuracao do servidor MCP consumida pelo Cursor (nao versionado; exemplo abaixo).
- `rules/n8n-mcp.mdc`: instrucoes opcionais para guiar o agente MCP em ambos os clientes.
- `docker-compose.yml`: exemplo de stack local para n8n com volumes e definicoes padrao.
- `setup_n8n.sh`: script de bootstrap em ambiente Linux com Nginx, Lets Encrypt e Basic Auth.

## Variaveis de ambiente
Defina as variaveis antes de abrir Cursor ou Codex para evitar expor chaves em arquivos.

```bash
export N8N_API_URL="https://seu-n8n.example.com"
export N8N_API_KEY="SEU_TOKEN_GERADO_NO_N8N"
```

- Ajuste os valores acima para cada ambiente (producao, homologacao, local).
- Armazene segredos em cofres ou gerenciadores adequados; nunca commite valores reais.
- Adicione ao shell RC (por exemplo `~/.bashrc`) apenas se o computador for pessoal e as variaveis forem protegidas.

## Configuracao no Cursor
1. Garanta que o workspace possui uma pasta `.cursor/` (nao versionada). Adicione ao `.gitignore` se ainda nao estiver:
   ```bash
   echo ".cursor/mcp.json" >> .gitignore
   ```
2. Crie o arquivo `.cursor/mcp.json` apontando para o servidor `n8n-mcp`:
   ```bash
   cat > .cursor/mcp.json <<'EOF'
   {
     "mcpServers": {
       "n8n-mcp": {
         "command": "npx",
         "args": ["n8n-mcp"],
         "env": {
           "MCP_MODE": "stdio",
           "LOG_LEVEL": "error",
           "DISABLE_CONSOLE_OUTPUT": "true",
           "N8N_API_URL": "${N8N_API_URL}",
           "N8N_API_KEY": "${N8N_API_KEY}"
         }
       }
     }
   }
   EOF
   ```
3. Abra o Cursor no repositorio e, em `Settings > MCP`, confirme que o servidor `n8n-mcp` aparece na lista.
4. Teste com um prompt simples, como: `Use o provedor n8n-mcp para listar workflows disponiveis.`
5. Se precisar depurar, altere `LOG_LEVEL` para `info` e consulte o painel MCP do Cursor.

## Configuracao no Codex
1. Com as variaveis de ambiente definidas, registre o servidor MCP:
   ```bash
   codex mcp add n8n-mcp \
     --env MCP_MODE=stdio \
     --env LOG_LEVEL=error \
     --env DISABLE_CONSOLE_OUTPUT=true \
     --env N8N_API_URL=$N8N_API_URL \
     --env N8N_API_KEY=$N8N_API_KEY \
     -- npx n8n-mcp
   ```
2. Verifique o cadastro:
   ```bash
   codex mcp list
   ```
3. Para usar o arquivo de regras deste repositorio, ajuste o caminho conforme sua maquina:
   ```bash
   codex --cd /home/taylao/n8n_mcp_workflows \
     --config experimental_instructions_file='"/home/taylao/n8n_mcp_workflows/rules/n8n-mcp.mdc"'
   ```
4. Para tornar permanente, edite `~/.codex/config.toml` e defina:
   ```toml
   experimental_instructions_file = "/home/taylao/n8n_mcp_workflows/rules/n8n-mcp.mdc"
   ```
5. Execute um comando simples (por exemplo `tools_documentation()`) para validar a comunicacao com o MCP.

## Regras compartilhadas (`rules/n8n-mcp.mdc`)
O arquivo `.mdc` contem diretrizes operacionais (nomenclatura de workflows, validacoes, tags). Copie ou referencie esse arquivo em cada maquina para padronizar interacoes. Atualize o conteudo conforme o time evoluir as convencoes.

## Provisionamento do n8n
- Use `docker-compose.yml` para subir rapidamente um n8n local com volumes em `/home/taylao/mcpn8n/local_n8n/`.
- Execute `setup_n8n.sh` em servidores Linux caso precise de uma instalacao com Nginx, HTTPS (Lets Encrypt) e protecao Basic Auth.
- Sempre substitua `DOMAIN`, `EMAIL` e credenciais do script pelos valores reais do ambiente antes de rodar.

## Como subir o n8n
### Ambiente local com Docker Compose
1. Ajuste os volumes ou variaveis dentro de `docker-compose.yml` conforme seu diretorio.
2. Suba o container:
   ```bash
   docker compose up -d
   ```
3. Acompanhe os logs para confirmar que a aplicacao iniciou sem erros:
   ```bash
   docker compose logs -f n8n
   ```
4. Quando precisar desligar:
   ```bash
   docker compose down
   ```

### Servidor Linux (Nginx + HTTPS)
1. Abra `setup_n8n.sh` e personalize `DOMAIN`, `EMAIL` e `BASIC_USER` com seus valores.
2. Execute o script como root ou via `sudo`:
   ```bash
   sudo bash setup_n8n.sh
   ```
3. O script cria diretórios em `/opt/n8n`, sobe o container, configura Nginx com Basic Auth e solicita certificados Lets Encrypt automaticamente.
4. Ao final, valide os testes sugeridos impressos no terminal (redirecionamento HTTP/HTTPS, autenticacao e logs do container).

## Boas praticas de seguranca
- Nunca registre `N8N_API_KEY`, senhas ou tokens em arquivos versionados.
- Utilize variaveis de ambiente ou cofres (por exemplo, 1Password, Vault, Secrets Manager) para segredos.
- Revogue chaves antigas no painel do n8n quando nao forem mais utilizadas.
- Restrinja o acesso ao servidor (firewall, VPN) e mantenha logs auditaveis.

## Troubleshooting
- `curl -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_API_URL/rest/workflows"` testa conectividade direto na API.
- Se o Cursor ou Codex nao listar o servidor, confirme o caminho do workspace e a sintaxe JSON do `mcp.json`.
- Erros de autenticacao geralmente indicam chave invalida ou variavel nao carregada no shell atual.
- Ajuste `LOG_LEVEL` para `info` no comando/arquivo e observe os logs emitidos pelo `n8n-mcp`.

## Checklist rapido
- [ ] Variaveis `N8N_API_URL` e `N8N_API_KEY` exportadas apenas no ambiente local.
- [ ] `.cursor/mcp.json` criado e ignorado pelo Git.
- [ ] `codex mcp add n8n-mcp` executado (se usar Codex).
- [ ] Arquivo `rules/n8n-mcp.mdc` referenciado nas ferramentas.
- [ ] Nenhuma chave ou senha real armazenada neste repositorio.


