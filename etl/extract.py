from __future__ import annotations

from typing import Tuple

import pandas as pd
import pyodbc


def gerar_dataframe_bruto(conn, query_sql: str, params: Tuple) -> pd.DataFrame | None:
    """
    Executa uma consulta SQL e retorna o primeiro result set como DataFrame.
    Usa setinputsizes para o parâmetro de data (VARCHAR) e evitar erro
    "Recurso opcional não implementado" em alguns drivers ODBC SQL Server.
    """
    cur = conn.cursor()
    # Um parâmetro: data no formato 'YYYY-MM-DD' (10 caracteres)
    if params:
        cur.setinputsizes([(pyodbc.SQL_VARCHAR, 10)])
    cur.execute(query_sql, params)

    df = None
    while True:
        if cur.description:
            rows = cur.fetchall()
            cols = [d[0] for d in cur.description]
            df = pd.DataFrame.from_records(rows, columns=cols)
            break

        if not cur.nextset():
            break

    cur.close()
    return df
