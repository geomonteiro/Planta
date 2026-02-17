from __future__ import annotations

from typing import Iterable

import pandas as pd


REQUIRED_COLUMNS = [
    "PeriodIndex",
    "AlimentacaoPlantaReal",
    "ProdutividadePlantaReal",
    "TeorAlimentacaoCobreReal",
    "TeorAlimentacaoOuroReal",
    "RecuperacaoCobreReal",
    "RecuperacaoOuroReal",
    "TeorAlimentacaoPiritaReal",
]


RENAME_MAP = {
    "PeriodIndex": "Data",
    "AlimentacaoPlantaReal": "Alimentação Planta",
    "ProdutividadePlantaReal": "Produtividade",
    "TeorAlimentacaoCobreReal": "Teor Cobre",
    "TeorAlimentacaoOuroReal": "Teor Ouro",
    "RecuperacaoCobreReal": "Recuperação Cobre",
    "RecuperacaoOuroReal": "Recuperação Ouro",
    "TeorAlimentacaoPiritaReal": "Teor Pirita",
}


def tratar_dataframe(df_bruto: pd.DataFrame, *, strict: bool = True) -> pd.DataFrame:
    """
    Aplica tratamento no DataFrame bruto.
    """
    df_tratado = df_bruto.copy()

    missing = [col for col in REQUIRED_COLUMNS if col not in df_tratado.columns]
    if missing and strict:
        raise ValueError(f"Colunas ausentes no DataFrame bruto: {missing}")

    colunas_existentes = [col for col in REQUIRED_COLUMNS if col in df_tratado.columns]
    df_tratado = df_tratado[colunas_existentes]

    if "AlimentacaoPlantaReal" in df_tratado.columns:
        condicao = (df_tratado["AlimentacaoPlantaReal"].isna()) | (
            df_tratado["AlimentacaoPlantaReal"] == 0
        )
        colunas_para_zerar = [col for col in colunas_existentes if col != "PeriodIndex"]
        df_tratado.loc[condicao, colunas_para_zerar] = 0

    df_tratado = df_tratado.rename(columns=RENAME_MAP)
    return df_tratado
