from __future__ import annotations

from datetime import date, datetime
from pathlib import Path
from typing import Iterable

import pandas as pd


def _parse_date_from_filename(path: Path) -> date:
    return datetime.strptime(path.stem, "%d.%m.%Y").date()


def _pick_first_non_zero(series: pd.Series):
    non_zero = series[(series != 0) & (~series.isna())]
    if len(non_zero) > 0:
        return non_zero.iloc[0]
    non_null = series.dropna()
    if len(non_null) > 0:
        return non_null.iloc[0]
    return 0


def consolidar_arquivos_tratados(pasta_tratado: Path, data_limite: date) -> pd.DataFrame:
    """
    Consolida todos os arquivos da pasta tratado em um unico DataFrame.
    Regras:
    1. Processa apenas datas <= data_limite
    2. Para datas repetidas, prioriza valores nao zero
    3. Prioridade deterministica: arquivo mais recente (mtime) primeiro
    """
    if not pasta_tratado.exists():
        return pd.DataFrame()

    arquivos = list(pasta_tratado.glob("*.xlsx"))
    if not arquivos:
        return pd.DataFrame()

    registros = []
    for arquivo in arquivos:
        try:
            data_arquivo = _parse_date_from_filename(arquivo)
        except ValueError:
            continue

        if data_arquivo > data_limite:
            continue

        df_arquivo = pd.read_excel(arquivo)
        if df_arquivo.empty:
            continue

        if "Data" not in df_arquivo.columns:
            df_arquivo["Data"] = data_arquivo.strftime("%d.%m.%Y")

        df_arquivo["_source_mtime"] = arquivo.stat().st_mtime
        df_arquivo["_source_name"] = arquivo.name
        registros.append(df_arquivo)

    if not registros:
        return pd.DataFrame()

    df_consolidado = pd.concat(registros, ignore_index=True)

    df_consolidado["Data_dt"] = pd.to_datetime(
        df_consolidado["Data"], errors="coerce", dayfirst=True
    )
    df_consolidado = df_consolidado[df_consolidado["Data_dt"].notna()]
    df_consolidado = df_consolidado[df_consolidado["Data_dt"].dt.date <= data_limite]

    df_consolidado = df_consolidado.sort_values(
        ["Data_dt", "_source_mtime", "_source_name"],
        ascending=[True, False, False],
    )

    colunas_dados = [
        col
        for col in df_consolidado.columns
        if col not in {"Data", "Data_dt", "_source_mtime", "_source_name"}
    ]

    def consolidar_grupo(grupo: pd.DataFrame) -> pd.Series:
        row = {"Data": grupo["Data_dt"].iloc[0]}
        for col in colunas_dados:
            row[col] = _pick_first_non_zero(grupo[col])
        return pd.Series(row)

    df_final = df_consolidado.groupby("Data_dt", as_index=False).apply(consolidar_grupo)
    df_final = df_final.reset_index(drop=True)
    return df_final
