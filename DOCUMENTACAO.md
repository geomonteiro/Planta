# ETL Mina Planta - Documentacao

## Visao geral
Este ETL extrai dados do SQL Server, gera arquivos diarios (bruto e tratado) e consolida em um unico Excel.

Objetivos da refatoracao:
- Separar responsabilidades (SRP)
- Melhorar testabilidade e manutencao
- Remover interpolacao de SQL com f-string
- Tornar consolidacao deterministica
- Configuracao via variaveis de ambiente

## Estrutura
- `main.py`: orquestracao do processo
- `config.py`: configuracao central (env vars)
- `db.py`: conexao com SQL Server
- `query_planta.py`: carrega SQL e fornece parametros
- `queries/planta.sql`: SQL principal (parametrizado)
- `etl/extract.py`: execucao da query e DataFrame bruto
- `etl/transform.py`: tratamento e schema
- `etl/load.py`: persistencia dos dados
- `etl/consolidate.py`: consolidacao deterministica
- `report_diario_planta.py`: wrapper para compatibilidade

## Como executar
```bash
python main.py
```
Ou:
```bash
python report_diario_planta.py
```

## Argumentos
- `--start-date` e `--end-date`: intervalo explicito (dd.mm.yyyy ou yyyy-mm-dd)
- `--days`: periodo retroativo em dias (inclui hoje)
- `--force`: sobrescreve arquivos existentes

## Variaveis de ambiente
- `PLANTA_SQL_SERVER` (default: `brmmicmes02`)
- `PLANTA_DB` (default: `YamanaMMIC`)
- `PLANTA_ODBC_DRIVER` (default: `SQL Server`)
- `PLANTA_BASE_FOLDER` (default: `Y:\reconciliacao\Planta`)
- `PLANTA_BASE_CONSOLIDADO` (default: `Y:\reconciliacao`)
- `PLANTA_DIAS_RETROATIVOS` (default: `16`)
- `PLANTA_TRUSTED_CONNECTION` (default: `true`)
- `PLANTA_DB_USER` / `PLANTA_DB_PASSWORD` (usados quando `PLANTA_TRUSTED_CONNECTION=false`)
- `PLANTA_STRICT_SCHEMA` (default: `true`)
- `PLANTA_LOG_LEVEL` (default: `INFO`)
- `PLANTA_LOG_DIR` (default: `Y:\reconciliacao\Planta\logs`)

Observacoes:
- Caminhos relativos no `.env` sao resolvidos a partir da raiz do projeto.
- Se `PLANTA_BASE_FOLDER` ou `PLANTA_BASE_CONSOLIDADO` nao existirem, serao criados automaticamente.

## Regras de consolidacao
- Consolida apenas datas <= (hoje - 1)
- Em datas repetidas, prioriza valores nao zero
- Ordem deterministica: arquivo com `mtime` mais recente tem prioridade

## Decisoes de design (SOLID + Clean Code)
- SRP: modulo por responsabilidade (config, db, extract, transform, load, consolidate)
- OCP: novas consultas podem ser adicionadas sem alterar o core
- LSP/ISP: funcoes operam sobre DataFrame padrao
- DIP: `main` depende de modulos de alto nivel, nao de detalhes

## Mudancas principais
- SQL movida para `queries/planta.sql`
- Query parametrizada (sem f-string)
- Consolidacao deterministica
- Logging estruturado

## Logging
- Terminal + arquivos em `PLANTA_LOG_DIR`
- Rotacao por tamanho (10 MB) em `etl-planta-size.log`
- Rotacao diaria (mantem 10 dias) em `etl-planta-daily.log`

## Observacoes
- `PLANTA_STRICT_SCHEMA=true` falha o processo se colunas obrigatorias estiverem ausentes
- Se desejar permitir schema parcial, use `PLANTA_STRICT_SCHEMA=false`
