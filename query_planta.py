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
    A data é passada como string no formato ISO para compatibilidade com
    o driver ODBC SQL Server (binding de tipo date não é suportado por alguns drivers).
    """
    if isinstance(data, date):
        data = data.isoformat()
    sql = carregar_query_planta()
    return sql, (str(data),)
