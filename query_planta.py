from __future__ import annotations

from datetime import date
from pathlib import Path
from typing import Tuple, Union

DateLike = Union[str, date]


SQL_PATH = Path(__file__).resolve().parent / "queries" / "planta.sql"


def carregar_query_planta() -> str:
    """
    Carrega a query SQL da planta a partir do arquivo .sql.
    """
    return SQL_PATH.read_text(encoding="utf-8")


def gerar_relatorio_planta(data: DateLike) -> Tuple[str, tuple]:
    """
    Retorna a query SQL e os parâmetros para execução.

    O parâmetro data deve estar no formato 'YYYY-MM-DD' ou ser um date.
    Passa um objeto date ao pyodbc para o driver SQL Server fazer o bind correto
    (evita erro "Incorrect syntax near 'A'" ao usar string).
    """
    if isinstance(data, str):
        data = date.fromisoformat(data)
    sql = carregar_query_planta()
    return sql, (data,)
