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
    O literal da data é injetado na SQL (sem usar parâmetros) para evitar
    o erro "Incorrect syntax near 'A'" com batches no driver ODBC SQL Server.
    """
    if isinstance(data, date):
        data = data.isoformat()
    data_str = str(data)
    # Garante formato YYYY-MM-DD (seguro para injetar como literal)
    if len(data_str) != 10 or data_str[4] != "-" or data_str[7] != "-" or not data_str.replace("-", "").isdigit():
        raise ValueError(f"Data deve estar no formato YYYY-MM-DD: {data_str!r}")
    sql = carregar_query_planta()
    # Substitui o único ? pelo literal da data (evita bug de binding em batch)
    sql = sql.replace("SET @Date = ?", f"SET @Date = '{data_str}'", 1)
    return sql, ()
