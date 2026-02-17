from __future__ import annotations

import argparse
import logging
from logging.handlers import RotatingFileHandler, TimedRotatingFileHandler
import os
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd

from config import load_config
from db import create_connection
from etl.consolidate import consolidar_arquivos_tratados
from etl.extract import gerar_dataframe_bruto
from etl.load import gravar_dataframe_excel
from etl.transform import tratar_dataframe
from query_planta import gerar_relatorio_planta


def _setup_logging(log_dir: Path) -> logging.Logger:
    log_dir.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("etl-planta")

    if logger.handlers:
        return logger

    level = os.getenv("PLANTA_LOG_LEVEL", "INFO").upper()
    logger.setLevel(level)

    formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")

    console_handler = logging.StreamHandler()
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)

    size_handler = RotatingFileHandler(
        log_dir / "etl-planta-size.log",
        maxBytes=10 * 1024 * 1024,
        backupCount=10,
        encoding="utf-8",
    )
    size_handler.setLevel(level)
    size_handler.setFormatter(formatter)

    time_handler = TimedRotatingFileHandler(
        log_dir / "etl-planta-daily.log",
        when="D",
        interval=1,
        backupCount=10,
        encoding="utf-8",
        utc=False,
    )
    time_handler.setLevel(level)
    time_handler.setFormatter(formatter)

    logger.addHandler(console_handler)
    logger.addHandler(size_handler)
    logger.addHandler(time_handler)

    return logger


def _parse_date(value: str) -> datetime.date:
    for fmt in ("%d.%m.%Y", "%Y-%m-%d"):
        try:
            return datetime.strptime(value, fmt).date()
        except ValueError:
            continue
    raise ValueError("Formato invalido de data. Use dd.mm.yyyy ou yyyy-mm-dd.")


def _gerar_intervalo_datas(inicio: datetime.date, fim: datetime.date) -> list[str]:
    if fim < inicio:
        raise ValueError("Data fim deve ser >= data inicio.")
    total = (fim - inicio).days
    return [
        (inicio + timedelta(days=i)).strftime("%d.%m.%Y")
        for i in range(total + 1)
    ]


def converter_data_formato(data_str: str) -> str:
    data_obj = datetime.strptime(data_str, "%d.%m.%Y")
    return data_obj.strftime("%Y-%m-%d")


def obter_data_limite_processamento() -> datetime.date:
    return (datetime.now() - timedelta(days=1)).date()


def _strict_schema_enabled() -> bool:
    raw = os.getenv("PLANTA_STRICT_SCHEMA", "true").strip().lower()
    return raw in {"1", "true", "yes", "y"}


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="ETL Mina Planta")
    parser.add_argument(
        "--start-date",
        help="Data de inicio (dd.mm.yyyy ou yyyy-mm-dd)",
    )
    parser.add_argument(
        "--end-date",
        help="Data fim (dd.mm.yyyy ou yyyy-mm-dd)",
    )
    parser.add_argument(
        "--days",
        type=int,
        help="Periodo retroativo em dias (inclui hoje)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Sobrescreve arquivos existentes",
    )
    return parser.parse_args()


def run(args: argparse.Namespace | None = None) -> int:
    if args is None:
        args = _parse_args()

    config = load_config()
    logger = _setup_logging(config.log_dir)
    data_limite = obter_data_limite_processamento()
    strict_schema = _strict_schema_enabled()

    if args.days is not None and (args.start_date or args.end_date):
        raise ValueError("Use --days ou --start-date/--end-date, nao ambos.")

    if (args.start_date and not args.end_date) or (args.end_date and not args.start_date):
        raise ValueError("Informe --start-date e --end-date juntos.")

    if args.days is not None and args.days < 0:
        raise ValueError("--days deve ser >= 0.")

    today = datetime.now().date()

    if args.start_date and args.end_date:
        inicio = _parse_date(args.start_date)
        fim = _parse_date(args.end_date)
    elif args.days is not None:
        inicio = today - timedelta(days=args.days)
        fim = today
    else:
        inicio = today - timedelta(days=config.dias_retroativos)
        fim = today

    if fim > today:
        logger.warning("Data fim esta no futuro. Ajustando para hoje.")
        fim = today
    if args.start_date or args.end_date or args.days is not None:
        data_limite = fim

    logger.info("Iniciando processamento - Data limite: %s", data_limite)
    logger.info("Intervalo solicitado: %s a %s", inicio, fim)
    logger.info("Base folder: %s", config.base_folder)
    logger.info("Consolidado: %s", config.base_consolidado)
    logger.info("Strict schema: %s", strict_schema)

    arquivos_diarios = _gerar_intervalo_datas(inicio, fim)

    arquivos_para_processar = []
    for arquivo in arquivos_diarios:
        data_arquivo = datetime.strptime(arquivo, "%d.%m.%Y").date()
        if data_arquivo <= data_limite:
            arquivos_para_processar.append(arquivo)

    logger.info("Total de arquivos a processar: %d", len(arquivos_para_processar))

    with create_connection(config) as conn:
        logger.info("Conexao com o banco estabelecida")

        for arquivo in arquivos_para_processar:
            try:
                logger.info("Processando arquivo: %s", arquivo)
                data_formatada = converter_data_formato(arquivo)

                query_sql, params = gerar_relatorio_planta(data_formatada)
                df_bruto = gerar_dataframe_bruto(conn, query_sql, params)

                if df_bruto is None or df_bruto.empty:
                    logger.warning("DataFrame vazio para %s", arquivo)
                    continue

                caminho_bruto = config.base_folder / "diario" / f"{arquivo}.xlsx"
                wrote = gravar_dataframe_excel(
                    df_bruto, caminho_bruto, overwrite=args.force
                )
                if not wrote:
                    logger.info("Arquivo bruto existente (skip): %s", caminho_bruto)

                df_tratado = tratar_dataframe(df_bruto, strict=strict_schema)
                caminho_tratado = config.base_folder / "tratado" / f"{arquivo}.xlsx"
                wrote = gravar_dataframe_excel(
                    df_tratado, caminho_tratado, overwrite=args.force
                )
                if not wrote:
                    logger.info("Arquivo tratado existente (skip): %s", caminho_tratado)

                logger.info(
                    "Salvo bruto (%s) e tratado (%s)",
                    caminho_bruto,
                    caminho_tratado,
                )
            except Exception:
                logger.exception("Erro ao processar %s", arquivo)

    logger.info("Iniciando consolidacao dos arquivos tratados")
    pasta_tratado = config.base_folder / "tratado"
    df_consolidado = consolidar_arquivos_tratados(pasta_tratado, data_limite)

    if df_consolidado.empty:
        logger.error("Nenhum dado foi consolidado")
        return 1

    caminho_consolidado = config.base_consolidado / "consolidado_planta.xlsx"
    df_consolidado["Data"] = pd.to_datetime(df_consolidado["Data"])
    wrote = gravar_dataframe_excel(
        df_consolidado, caminho_consolidado, overwrite=args.force
    )
    if not wrote:
        logger.info("Consolidado existente (skip): %s", caminho_consolidado)
        return 0

    logger.info("Consolidado salvo: %s", caminho_consolidado)
    logger.info("Shape consolidado: %s", df_consolidado.shape)
    logger.info(
        "Periodo consolidado: %s a %s",
        df_consolidado["Data"].min(),
        df_consolidado["Data"].max(),
    )

    return 0


def cli() -> int:
    return run(_parse_args())


if __name__ == "__main__":
    raise SystemExit(cli())
