from __future__ import annotations

import pyodbc

from config import AppConfig


def create_connection(config: AppConfig) -> pyodbc.Connection:
    return pyodbc.connect(config.conn_str)
