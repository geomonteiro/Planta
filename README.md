# ETL Mina Planta

Scripts para extracao, tratamento e consolidacao de dados do SQL Server em arquivos Excel.

## Execucao
```bash
python main.py
```

Atalho compatibilidade:
```bash
python report_diario_planta.py
```

## Argumentos
- `--start-date` e `--end-date`: intervalo explicito (dd.mm.yyyy ou yyyy-mm-dd)
- `--days`: periodo retroativo em dias (inclui hoje). Ex: `--days 7`
- `--force`: sobrescreve arquivos existentes

Exemplos:
```bash
python main.py --start-date 2025-10-01 --end-date 2025-10-10
python main.py --days 7
python main.py --days 3 --force
```

## Configuracao (env vars)
- Se existir um arquivo `.env` na raiz do projeto, ele sera carregado automaticamente.
- Caminhos relativos em `.env` sao resolvidos a partir da raiz do projeto.
- As pastas `PLANTA_BASE_FOLDER` e `PLANTA_BASE_CONSOLIDADO` sao criadas automaticamente se nao existirem.
- `PLANTA_SQL_SERVER` (default `brmmicmes02`)
- `PLANTA_DB` (default `YamanaMMIC`)
- `PLANTA_ODBC_DRIVER` (default `SQL Server`)
- `PLANTA_BASE_FOLDER` (default `Y:\reconciliacao\Planta`)
- `PLANTA_BASE_CONSOLIDADO` (default `Y:\reconciliacao`)
- `PLANTA_DIAS_RETROATIVOS` (default `16`)
- `PLANTA_TRUSTED_CONNECTION` (default `true`)
- `PLANTA_DB_USER` / `PLANTA_DB_PASSWORD` (quando `PLANTA_TRUSTED_CONNECTION=false`)
- `PLANTA_STRICT_SCHEMA` (default `true`)
- `PLANTA_LOG_LEVEL` (default `INFO`)
- `PLANTA_LOG_DIR` (default `Y:\reconciliacao\Planta\logs`)

## Troubleshooting
- Erro de conexao ODBC: verifique `PLANTA_ODBC_DRIVER` e se o driver esta instalado.
- Erro de autenticacao: defina `PLANTA_TRUSTED_CONNECTION=false` e informe `PLANTA_DB_USER` e `PLANTA_DB_PASSWORD`.
- DataFrame vazio: confirme se ha dados para a data e se o SQL foi retornado corretamente.
- Erro de schema ausente: desabilite com `PLANTA_STRICT_SCHEMA=false` ou revise a query.
- Consolidado vazio: confirme arquivos em `PLANTA_BASE_FOLDER\\tratado` e datas <= hoje - 1.
- Logs: sao gravados em arquivo e terminal. Veja `PLANTA_LOG_DIR` para os arquivos de log.
