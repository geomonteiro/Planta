from __future__ import annotations

from pathlib import Path

import pandas as pd


def gravar_dataframe_excel(
    df: pd.DataFrame, caminho_arquivo: Path, *, overwrite: bool = False
) -> bool:
    """
    Salva o DataFrame em um arquivo Excel.
    """
    caminho_arquivo.parent.mkdir(parents=True, exist_ok=True)
    if caminho_arquivo.exists() and not overwrite:
        return False
    df.to_excel(caminho_arquivo, index=False)
    return True
