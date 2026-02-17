from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from pathlib import Path
import os
import re


def _env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None or value.strip() == "":
        return default
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"Variavel {name} deve ser inteira. Valor atual: {value}") from exc


def _load_dotenv_if_present(base_dir: Path) -> None:
    env_path = base_dir / ".env"
    if not env_path.exists():
        return

    pattern = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$")
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = pattern.match(line)
        if not match:
            continue
        key, value = match.group(1), match.group(2)
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        if value.startswith("'") and value.endswith("'"):
            value = value[1:-1]
        if key not in os.environ:
            os.environ[key] = value


@dataclass(frozen=True)
class AppConfig:
    server: str
    database: str
    driver: str
    base_folder: Path
    base_consolidado: Path
    log_dir: Path
    dias_retroativos: int
    trusted_connection: bool
    db_user: str | None
    db_password: str | None

    @property
    def conn_str(self) -> str:
        if self.trusted_connection and not self.db_user and not self.db_password:
            return (
                f"DRIVER={{{self.driver}}};"
                f"SERVER={self.server};"
                f"DATABASE={self.database};"
                "Trusted_Connection=yes;"
            )
        if not self.db_user or not self.db_password:
            raise ValueError("db_user/db_password precisam ser definidos quando trusted_connection=False")
        return (
            f"DRIVER={{{self.driver}}};"
            f"SERVER={self.server};"
            f"DATABASE={self.database};"
            f"UID={self.db_user};PWD={self.db_password};"
        )


def _resolve_path(value: str, project_root: Path) -> Path:
    raw = value.strip()
    path = Path(raw)
    if not path.is_absolute():
        path = (project_root / path).resolve()
    return path


def load_config(today: date | None = None) -> AppConfig:
    project_root = Path(__file__).resolve().parent
    _load_dotenv_if_present(project_root)

    base_folder = _resolve_path(
        os.getenv("PLANTA_BASE_FOLDER", r"Y:\reconciliacao\Planta"),
        project_root,
    )
    base_consolidado = _resolve_path(
        os.getenv("PLANTA_BASE_CONSOLIDADO", r"Y:\reconciliacao"),
        project_root,
    )
    log_dir = _resolve_path(
        os.getenv("PLANTA_LOG_DIR", str(base_folder / "logs")),
        project_root,
    )

    trusted_raw = os.getenv("PLANTA_TRUSTED_CONNECTION", "true").strip().lower()
    trusted_connection = trusted_raw in {"1", "true", "yes", "y"}

    base_folder.mkdir(parents=True, exist_ok=True)
    base_consolidado.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)

    return AppConfig(
        server=os.getenv("PLANTA_SQL_SERVER", "brmmicmes02"),
        database=os.getenv("PLANTA_DB", "YamanaMMIC"),
        driver=os.getenv("PLANTA_ODBC_DRIVER", "SQL Server"),
        base_folder=base_folder,
        base_consolidado=base_consolidado,
        log_dir=log_dir,
        dias_retroativos=_env_int("PLANTA_DIAS_RETROATIVOS", 16),
        trusted_connection=trusted_connection,
        db_user=os.getenv("PLANTA_DB_USER"),
        db_password=os.getenv("PLANTA_DB_PASSWORD"),
    )
