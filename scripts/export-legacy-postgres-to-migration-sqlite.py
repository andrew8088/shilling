#!/usr/bin/env python3
"""Export legacy Postgres finance data into a deterministic migration SQLite DB.

The output SQLite file contains two layers:
- raw_* tables: source-fidelity snapshots from legacy Postgres
- target_* tables: transformed rows shaped for Shilling import
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import sqlite3
import subprocess
import sys
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any


UUID_NAMESPACE = uuid.UUID("9d95f0f7-f43f-4b42-910f-7156379b4c80")


@dataclass
class SourceTransaction:
    transaction_id: str
    kind: str
    category_id: str | None
    merchant_id: str | None
    transaction_created_at: str
    transaction_updated_at: str
    entry_id: str
    account_id: str
    account_classification: str
    amount: Decimal
    currency: str | None
    transaction_date: date | None
    name: str
    notes: str | None
    import_id: str | None
    entry_created_at: str
    entry_updated_at: str
    excluded: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export legacy Postgres data to a migration SQLite database."
    )
    parser.add_argument(
        "--source-db",
        default="maybe_2026_03_03",
        help="Postgres DB name/connection for psql (default: maybe_2026_03_03).",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Path to output SQLite file.",
    )
    parser.add_argument(
        "--family-id",
        help="Legacy family UUID to export. Auto-detected when omitted.",
    )
    parser.add_argument(
        "--psql-bin",
        default="psql",
        help="psql binary path/name (default: psql).",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite output file if it exists.",
    )
    return parser.parse_args()


def sql_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def none_if_empty(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed if trimmed else None


def parse_date(value: str | None) -> date | None:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        return None


def parse_decimal(value: str, *, context: str) -> Decimal:
    try:
        return Decimal(value)
    except (InvalidOperation, TypeError) as exc:
        raise ValueError(f"Invalid decimal for {context}: {value!r}") from exc


def decimal_string(value: Decimal) -> str:
    return format(value.quantize(Decimal("0.0001")), "f")


def uuid_for(kind: str, *parts: str) -> str:
    joined = "|".join((kind, *parts))
    return str(uuid.uuid5(UUID_NAMESPACE, joined))


def opposite_entry_type(entry_type: str) -> str:
    return "debit" if entry_type == "credit" else "credit"


def entry_type_for_source_amount(amount: Decimal) -> str | None:
    if amount > 0:
        return "credit"
    if amount < 0:
        return "debit"
    return None


def psql_copy_rows(psql_bin: str, source_db: str, query: str) -> list[dict[str, str]]:
    cmd = [
        psql_bin,
        source_db,
        "-v",
        "ON_ERROR_STOP=1",
        "-P",
        "pager=off",
        "-c",
        f"\\copy ({query}) TO STDOUT WITH CSV HEADER",
    ]
    completed = subprocess.run(
        cmd,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        stderr = completed.stderr.strip()
        stdout = completed.stdout.strip()
        payload = stderr or stdout or "unknown psql failure"
        raise RuntimeError(f"psql copy failed: {payload}")

    content = completed.stdout
    reader = csv.DictReader(io.StringIO(content))
    return list(reader)


def canonical_pair(tx_a: str, tx_b: str) -> tuple[str, str]:
    return (tx_a, tx_b) if tx_a < tx_b else (tx_b, tx_a)


def pick_family_id(psql_bin: str, source_db: str, explicit_family_id: str | None) -> str:
    rows = psql_copy_rows(
        psql_bin,
        source_db,
        "SELECT DISTINCT family_id::text AS family_id FROM accounts ORDER BY family_id",
    )
    family_ids = [row["family_id"] for row in rows if row["family_id"]]
    if not family_ids:
        raise RuntimeError("No family_id values found in source accounts table.")

    if explicit_family_id:
        if explicit_family_id not in family_ids:
            raise RuntimeError(
                f"--family-id {explicit_family_id} not found. Available: {', '.join(family_ids)}"
            )
        return explicit_family_id

    if len(family_ids) > 1:
        raise RuntimeError(
            "Multiple family IDs found. Re-run with --family-id. "
            f"Available: {', '.join(family_ids)}"
        )
    return family_ids[0]


def fetch_source_rows(psql_bin: str, source_db: str, family_id: str) -> dict[str, list[dict[str, str]]]:
    family = sql_quote(family_id)

    queries: dict[str, str] = {
        "accounts": f"""
            SELECT
                id::text AS id,
                family_id::text AS family_id,
                COALESCE(name, '') AS name,
                COALESCE(classification, '') AS classification,
                COALESCE(status, '') AS status,
                created_at::text AS created_at,
                updated_at::text AS updated_at,
                COALESCE(subtype, '') AS subtype,
                COALESCE(currency, '') AS currency
            FROM accounts
            WHERE family_id = {family}
            ORDER BY created_at, id
        """,
        "categories": f"""
            SELECT
                id::text AS id,
                family_id::text AS family_id,
                COALESCE(name, '') AS name,
                COALESCE(classification, '') AS classification,
                COALESCE(color, '') AS color,
                COALESCE(parent_id::text, '') AS parent_id,
                created_at::text AS created_at,
                updated_at::text AS updated_at
            FROM categories
            WHERE family_id = {family}
            ORDER BY created_at, id
        """,
        "transactions": f"""
            SELECT
                t.id::text AS transaction_id,
                COALESCE(t.kind, '') AS kind,
                COALESCE(t.category_id::text, '') AS category_id,
                COALESCE(t.merchant_id::text, '') AS merchant_id,
                t.created_at::text AS transaction_created_at,
                t.updated_at::text AS transaction_updated_at,
                e.id::text AS entry_id,
                e.account_id::text AS account_id,
                COALESCE(a.classification, '') AS account_classification,
                e.amount::text AS amount,
                COALESCE(e.currency, '') AS currency,
                COALESCE(e.date::text, '') AS date,
                COALESCE(e.name, '') AS name,
                COALESCE(e.notes, '') AS notes,
                COALESCE(e.import_id::text, '') AS import_id,
                e.created_at::text AS entry_created_at,
                e.updated_at::text AS entry_updated_at,
                COALESCE(e.excluded::text, 'false') AS excluded
            FROM transactions t
            JOIN entries e
                ON e.entryable_type = 'Transaction'
               AND e.entryable_id = t.id
            JOIN accounts a
                ON a.id = e.account_id
            WHERE a.family_id = {family}
            ORDER BY t.id, e.created_at, e.id
        """,
        "transfers": f"""
            SELECT DISTINCT
                tr.id::text AS id,
                tr.inflow_transaction_id::text AS inflow_transaction_id,
                tr.outflow_transaction_id::text AS outflow_transaction_id,
                COALESCE(tr.status, '') AS status,
                COALESCE(tr.notes, '') AS notes,
                tr.created_at::text AS created_at,
                tr.updated_at::text AS updated_at
            FROM transfers tr
            JOIN entries ei
                ON ei.entryable_type = 'Transaction'
               AND ei.entryable_id = tr.inflow_transaction_id
            JOIN accounts ai
                ON ai.id = ei.account_id
            JOIN entries eo
                ON eo.entryable_type = 'Transaction'
               AND eo.entryable_id = tr.outflow_transaction_id
            JOIN accounts ao
                ON ao.id = eo.account_id
            WHERE ai.family_id = {family}
              AND ao.family_id = {family}
            ORDER BY created_at, id
        """,
        "rejected_transfers": f"""
            SELECT DISTINCT
                rt.id::text AS id,
                rt.inflow_transaction_id::text AS inflow_transaction_id,
                rt.outflow_transaction_id::text AS outflow_transaction_id,
                rt.created_at::text AS created_at,
                rt.updated_at::text AS updated_at
            FROM rejected_transfers rt
            JOIN entries ei
                ON ei.entryable_type = 'Transaction'
               AND ei.entryable_id = rt.inflow_transaction_id
            JOIN accounts ai
                ON ai.id = ei.account_id
            JOIN entries eo
                ON eo.entryable_type = 'Transaction'
               AND eo.entryable_id = rt.outflow_transaction_id
            JOIN accounts ao
                ON ao.id = eo.account_id
            WHERE ai.family_id = {family}
              AND ao.family_id = {family}
            ORDER BY created_at, id
        """,
        "budgets": f"""
            SELECT
                b.id::text AS budget_id,
                b.start_date::text AS start_date,
                b.end_date::text AS end_date,
                COALESCE(b.budgeted_spending::text, '') AS budgeted_spending,
                COALESCE(b.expected_income::text, '') AS expected_income,
                COALESCE(b.currency, '') AS currency,
                b.created_at::text AS created_at,
                b.updated_at::text AS updated_at
            FROM budgets b
            WHERE b.family_id = {family}
            ORDER BY b.start_date, b.id
        """,
        "budget_categories": f"""
            SELECT
                bc.id::text AS id,
                bc.budget_id::text AS budget_id,
                bc.category_id::text AS category_id,
                bc.budgeted_spending::text AS budgeted_spending,
                COALESCE(bc.currency, '') AS currency,
                bc.created_at::text AS created_at,
                bc.updated_at::text AS updated_at
            FROM budget_categories bc
            JOIN budgets b
                ON b.id = bc.budget_id
            WHERE b.family_id = {family}
            ORDER BY bc.created_at, bc.id
        """,
        "imports": f"""
            SELECT
                i.id::text AS id,
                COALESCE(i.status, '') AS status,
                COALESCE(i.type, '') AS type,
                COALESCE(i.account_id::text, '') AS account_id,
                COALESCE(i.date_format, '') AS date_format,
                COALESCE(i.signage_convention, '') AS signage_convention,
                COALESCE(i.amount_type_strategy, '') AS amount_type_strategy,
                COUNT(ir.id)::text AS row_count,
                i.created_at::text AS created_at,
                i.updated_at::text AS updated_at
            FROM imports i
            LEFT JOIN import_rows ir
                ON ir.import_id = i.id
            WHERE i.family_id = {family}
            GROUP BY
                i.id,
                i.status,
                i.type,
                i.account_id,
                i.date_format,
                i.signage_convention,
                i.amount_type_strategy,
                i.created_at,
                i.updated_at
            ORDER BY i.created_at, i.id
        """,
        "import_rows": f"""
            SELECT
                ir.id::text AS id,
                ir.import_id::text AS import_id,
                COALESCE(ir.account, '') AS account,
                COALESCE(ir.date, '') AS date,
                COALESCE(ir.qty, '') AS qty,
                COALESCE(ir.ticker, '') AS ticker,
                COALESCE(ir.price, '') AS price,
                COALESCE(ir.amount, '') AS amount,
                COALESCE(ir.currency, '') AS currency,
                COALESCE(ir.name, '') AS name,
                COALESCE(ir.category, '') AS category,
                COALESCE(ir.tags, '') AS tags,
                COALESCE(ir.entity_type, '') AS entity_type,
                COALESCE(ir.notes, '') AS notes,
                COALESCE(ir.exchange_operating_mic, '') AS exchange_operating_mic,
                ir.created_at::text AS created_at,
                ir.updated_at::text AS updated_at
            FROM import_rows ir
            JOIN imports i
                ON i.id = ir.import_id
            WHERE i.family_id = {family}
            ORDER BY ir.created_at, ir.id
        """,
    }

    results: dict[str, list[dict[str, str]]] = {}
    for key, query in queries.items():
        results[key] = psql_copy_rows(psql_bin, source_db, query)
    return results


def build_source_transactions(
    raw_transaction_rows: list[dict[str, str]],
    warnings: list[dict[str, str]],
) -> dict[str, SourceTransaction]:
    transactions: dict[str, SourceTransaction] = {}

    for row in raw_transaction_rows:
        tx_id = row["transaction_id"]
        if tx_id in transactions:
            warnings.append(
                {
                    "code": "duplicate_source_transaction_entry",
                    "message": "Transaction had multiple legacy entries; kept earliest row.",
                    "payload": json.dumps({"transaction_id": tx_id, "discarded_entry_id": row["entry_id"]}),
                }
            )
            continue

        try:
            amount = parse_decimal(row["amount"], context=f"transaction {tx_id}")
        except ValueError as exc:
            warnings.append(
                {
                    "code": "invalid_source_amount",
                    "message": str(exc),
                    "payload": json.dumps({"transaction_id": tx_id, "entry_id": row["entry_id"]}),
                }
            )
            continue

        tx = SourceTransaction(
            transaction_id=tx_id,
            kind=row["kind"],
            category_id=none_if_empty(row["category_id"]),
            merchant_id=none_if_empty(row["merchant_id"]),
            transaction_created_at=row["transaction_created_at"],
            transaction_updated_at=row["transaction_updated_at"],
            entry_id=row["entry_id"],
            account_id=row["account_id"],
            account_classification=(none_if_empty(row["account_classification"]) or "asset"),
            amount=amount,
            currency=none_if_empty(row["currency"]),
            transaction_date=parse_date(row["date"]),
            name=row["name"],
            notes=none_if_empty(row["notes"]),
            import_id=none_if_empty(row["import_id"]),
            entry_created_at=row["entry_created_at"],
            entry_updated_at=row["entry_updated_at"],
            excluded=row["excluded"].lower() == "true",
        )
        transactions[tx_id] = tx

    return transactions


def should_pair_pending_transfer(out_tx: SourceTransaction, in_tx: SourceTransaction) -> bool:
    if out_tx.kind != "funds_movement" or in_tx.kind != "funds_movement":
        return False
    if out_tx.category_id is not None or in_tx.category_id is not None:
        return False
    if out_tx.transaction_date is None or in_tx.transaction_date is None:
        return False
    if abs((out_tx.transaction_date - in_tx.transaction_date).days) > 3:
        return False
    return out_tx.amount == -in_tx.amount


def create_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        PRAGMA foreign_keys = ON;

        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE warnings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            message TEXT NOT NULL,
            payload TEXT
        );

        CREATE TABLE raw_accounts (
            id TEXT PRIMARY KEY,
            family_id TEXT NOT NULL,
            name TEXT,
            classification TEXT,
            status TEXT,
            created_at TEXT,
            updated_at TEXT,
            subtype TEXT,
            currency TEXT
        );

        CREATE TABLE raw_categories (
            id TEXT PRIMARY KEY,
            family_id TEXT NOT NULL,
            name TEXT NOT NULL,
            classification TEXT NOT NULL,
            color TEXT,
            parent_id TEXT,
            created_at TEXT,
            updated_at TEXT
        );

        CREATE TABLE raw_transactions (
            transaction_id TEXT NOT NULL,
            kind TEXT,
            category_id TEXT,
            merchant_id TEXT,
            transaction_created_at TEXT,
            transaction_updated_at TEXT,
            entry_id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            account_classification TEXT,
            amount TEXT NOT NULL,
            currency TEXT,
            date TEXT,
            name TEXT,
            notes TEXT,
            import_id TEXT,
            entry_created_at TEXT,
            entry_updated_at TEXT,
            excluded INTEGER NOT NULL
        );

        CREATE TABLE raw_transfers (
            id TEXT PRIMARY KEY,
            inflow_transaction_id TEXT NOT NULL,
            outflow_transaction_id TEXT NOT NULL,
            status TEXT NOT NULL,
            notes TEXT,
            created_at TEXT,
            updated_at TEXT
        );

        CREATE TABLE raw_rejected_transfers (
            id TEXT PRIMARY KEY,
            inflow_transaction_id TEXT NOT NULL,
            outflow_transaction_id TEXT NOT NULL,
            created_at TEXT,
            updated_at TEXT
        );

        CREATE TABLE raw_budgets (
            budget_id TEXT PRIMARY KEY,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            budgeted_spending TEXT,
            expected_income TEXT,
            currency TEXT,
            created_at TEXT,
            updated_at TEXT
        );

        CREATE TABLE raw_budget_categories (
            id TEXT PRIMARY KEY,
            budget_id TEXT NOT NULL,
            category_id TEXT NOT NULL,
            budgeted_spending TEXT NOT NULL,
            currency TEXT,
            created_at TEXT,
            updated_at TEXT
        );

        CREATE TABLE raw_imports (
            id TEXT PRIMARY KEY,
            status TEXT,
            type TEXT,
            account_id TEXT,
            date_format TEXT,
            signage_convention TEXT,
            amount_type_strategy TEXT,
            row_count INTEGER NOT NULL,
            created_at TEXT,
            updated_at TEXT
        );

        CREATE TABLE raw_import_rows (
            id TEXT PRIMARY KEY,
            import_id TEXT NOT NULL,
            account TEXT,
            date TEXT,
            qty TEXT,
            ticker TEXT,
            price TEXT,
            amount TEXT,
            currency TEXT,
            name TEXT,
            category TEXT,
            tags TEXT,
            entity_type TEXT,
            notes TEXT,
            exchange_operating_mic TEXT,
            created_at TEXT,
            updated_at TEXT
        );

        CREATE TABLE target_accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            account_type TEXT NOT NULL,
            is_archived INTEGER NOT NULL,
            notes TEXT,
            created_at TEXT,
            source_kind TEXT NOT NULL,
            source_id TEXT
        );

        CREATE TABLE target_import_records (
            id TEXT PRIMARY KEY,
            file_name TEXT NOT NULL,
            imported_at TEXT NOT NULL,
            row_count INTEGER NOT NULL,
            source_import_id TEXT NOT NULL,
            source_status TEXT
        );

        CREATE TABLE target_transactions (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            payee TEXT NOT NULL,
            notes TEXT,
            import_record_id TEXT,
            created_at TEXT,
            source_mode TEXT NOT NULL,
            source_transaction_ids TEXT NOT NULL,
            source_transfer_status TEXT,
            FOREIGN KEY(import_record_id) REFERENCES target_import_records(id)
        );

        CREATE TABLE target_entries (
            id TEXT PRIMARY KEY,
            transaction_id TEXT NOT NULL,
            account_id TEXT NOT NULL,
            amount TEXT NOT NULL,
            entry_type TEXT NOT NULL CHECK(entry_type IN ('debit', 'credit')),
            memo TEXT,
            source_entry_id TEXT,
            FOREIGN KEY(transaction_id) REFERENCES target_transactions(id) ON DELETE CASCADE,
            FOREIGN KEY(account_id) REFERENCES target_accounts(id)
        );

        CREATE TABLE target_budgets (
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            amount TEXT NOT NULL,
            source_budget_category_id TEXT NOT NULL,
            currency TEXT,
            FOREIGN KEY(account_id) REFERENCES target_accounts(id)
        );

        CREATE TABLE map_source_account_to_target_account (
            source_account_id TEXT PRIMARY KEY,
            target_account_id TEXT NOT NULL,
            FOREIGN KEY(target_account_id) REFERENCES target_accounts(id)
        );

        CREATE TABLE map_source_category_to_target_account (
            source_category_id TEXT PRIMARY KEY,
            target_account_id TEXT NOT NULL,
            FOREIGN KEY(target_account_id) REFERENCES target_accounts(id)
        );

        CREATE TABLE map_source_transaction_to_target_transaction (
            source_transaction_id TEXT NOT NULL,
            target_transaction_id TEXT NOT NULL,
            role TEXT NOT NULL,
            PRIMARY KEY(source_transaction_id, target_transaction_id),
            FOREIGN KEY(target_transaction_id) REFERENCES target_transactions(id)
        );

        CREATE TABLE map_source_import_to_target_import_record (
            source_import_id TEXT PRIMARY KEY,
            target_import_record_id TEXT NOT NULL,
            FOREIGN KEY(target_import_record_id) REFERENCES target_import_records(id)
        );

        CREATE INDEX idx_target_entries_transaction_id ON target_entries(transaction_id);
        CREATE INDEX idx_target_transactions_import_record_id ON target_transactions(import_record_id);
        CREATE INDEX idx_target_budgets_year_month ON target_budgets(year, month);
        """
    )


def insert_many(
    conn: sqlite3.Connection,
    table: str,
    columns: list[str],
    rows: list[dict[str, Any]],
) -> None:
    if not rows:
        return
    placeholders = ", ".join(["?"] * len(columns))
    sql = f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({placeholders})"
    values = [tuple(row.get(column) for column in columns) for row in rows]
    conn.executemany(sql, values)


def validate_target_invariants(conn: sqlite3.Connection) -> list[str]:
    failures: list[str] = []

    tx_without_two_entries = conn.execute(
        """
        SELECT transaction_id, COUNT(*) AS n
        FROM target_entries
        GROUP BY transaction_id
        HAVING n != 2
        """
    ).fetchall()
    if tx_without_two_entries:
        failures.append(f"{len(tx_without_two_entries)} transaction(s) do not have exactly 2 entries.")

    bad_debit_credit_counts = conn.execute(
        """
        SELECT
            transaction_id,
            SUM(CASE WHEN entry_type = 'debit' THEN 1 ELSE 0 END) AS debit_count,
            SUM(CASE WHEN entry_type = 'credit' THEN 1 ELSE 0 END) AS credit_count
        FROM target_entries
        GROUP BY transaction_id
        HAVING debit_count != 1 OR credit_count != 1
        """
    ).fetchall()
    if bad_debit_credit_counts:
        failures.append(f"{len(bad_debit_credit_counts)} transaction(s) do not have one debit and one credit.")

    unbalanced = conn.execute(
        """
        SELECT
            transaction_id
        FROM (
            SELECT
                transaction_id,
                SUM(CASE WHEN entry_type = 'debit' THEN CAST(amount AS REAL) ELSE 0 END) AS debit_sum,
                SUM(CASE WHEN entry_type = 'credit' THEN CAST(amount AS REAL) ELSE 0 END) AS credit_sum
            FROM target_entries
            GROUP BY transaction_id
        )
        WHERE ABS(debit_sum - credit_sum) > 0.0001
        """
    ).fetchall()
    if unbalanced:
        failures.append(f"{len(unbalanced)} transaction(s) are not balanced.")

    orphan_tx_map_rows = conn.execute(
        """
        SELECT COUNT(*)
        FROM map_source_transaction_to_target_transaction m
        LEFT JOIN target_transactions t ON t.id = m.target_transaction_id
        WHERE t.id IS NULL
        """
    ).fetchone()[0]
    if orphan_tx_map_rows:
        failures.append(f"{orphan_tx_map_rows} source->target transaction mapping row(s) are orphaned.")

    return failures


def choose_import_record_id(
    import_ids: list[str | None],
    known_import_ids: set[str],
    warnings: list[dict[str, str]],
    warning_payload: dict[str, Any],
) -> str | None:
    resolved = {value for value in import_ids if value}
    if not resolved:
        return None
    if len(resolved) > 1:
        warnings.append(
            {
                "code": "conflicting_import_ids_for_paired_transfer",
                "message": "Transfer pair had different source import IDs; import link dropped.",
                "payload": json.dumps({**warning_payload, "import_ids": sorted(resolved)}),
            }
        )
        return None
    candidate = next(iter(resolved))
    if candidate not in known_import_ids:
        warnings.append(
            {
                "code": "missing_import_record_reference",
                "message": "Source import ID missing from exported imports; import link dropped.",
                "payload": json.dumps({**warning_payload, "import_id": candidate}),
            }
        )
        return None
    return candidate


def main() -> int:
    args = parse_args()
    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if output_path.exists() and not args.overwrite:
        print(
            f"Output exists: {output_path}. Pass --overwrite to replace it.",
            file=sys.stderr,
        )
        return 2
    if output_path.exists() and args.overwrite:
        output_path.unlink()

    warnings: list[dict[str, str]] = []

    try:
        family_id = pick_family_id(args.psql_bin, args.source_db, args.family_id)
        source = fetch_source_rows(args.psql_bin, args.source_db, family_id)
    except Exception as exc:  # pragma: no cover - command failure path
        print(f"Failed to fetch source data: {exc}", file=sys.stderr)
        return 1

    source_accounts = source["accounts"]
    source_categories = source["categories"]
    source_transaction_rows = source["transactions"]
    source_transfers = source["transfers"]
    source_rejected_transfers = source["rejected_transfers"]
    source_budgets = source["budgets"]
    source_budget_categories = source["budget_categories"]
    source_imports = source["imports"]
    source_import_rows = source["import_rows"]

    source_transactions = build_source_transactions(source_transaction_rows, warnings)
    category_by_id = {row["id"]: row for row in source_categories}
    budget_by_id = {row["budget_id"]: row for row in source_budgets}
    known_import_ids = {row["id"] for row in source_imports}

    suspense_account_id = uuid_for("system-account", "legacy-import-suspense")

    target_accounts: list[dict[str, Any]] = []
    map_source_account_rows: list[dict[str, Any]] = []
    map_source_category_rows: list[dict[str, Any]] = []

    for row in source_accounts:
        classification = (row["classification"] or "").strip().lower()
        if classification not in {"asset", "liability"}:
            warnings.append(
                {
                    "code": "unknown_account_classification",
                    "message": "Unknown account classification; defaulted to asset.",
                    "payload": json.dumps({"account_id": row["id"], "classification": classification}),
                }
            )
            classification = "asset"

        target_accounts.append(
            {
                "id": row["id"],
                "name": row["name"] or f"Legacy Account {row['id']}",
                "account_type": classification,
                "is_archived": 1 if row["status"] == "disabled" else 0,
                "notes": json.dumps(
                    {
                        "legacy_source": "accounts",
                        "legacy_id": row["id"],
                        "legacy_subtype": none_if_empty(row["subtype"]),
                        "legacy_currency": none_if_empty(row["currency"]),
                    }
                ),
                "created_at": row["created_at"],
                "source_kind": "account",
                "source_id": row["id"],
            }
        )
        map_source_account_rows.append(
            {
                "source_account_id": row["id"],
                "target_account_id": row["id"],
            }
        )

    for row in source_categories:
        classification = (row["classification"] or "").strip().lower()
        if classification not in {"expense", "income"}:
            warnings.append(
                {
                    "code": "unknown_category_classification",
                    "message": "Unknown category classification; defaulted to expense.",
                    "payload": json.dumps({"category_id": row["id"], "classification": classification}),
                }
            )
            classification = "expense"

        category_account_id = uuid_for("category-account", row["id"])
        target_accounts.append(
            {
                "id": category_account_id,
                "name": f"Category: {row['name']}",
                "account_type": classification,
                "is_archived": 0,
                "notes": json.dumps(
                    {
                        "legacy_source": "categories",
                        "legacy_id": row["id"],
                        "legacy_color": none_if_empty(row["color"]),
                        "legacy_parent_id": none_if_empty(row["parent_id"]),
                    }
                ),
                "created_at": row["created_at"],
                "source_kind": "category",
                "source_id": row["id"],
            }
        )
        map_source_category_rows.append(
            {
                "source_category_id": row["id"],
                "target_account_id": category_account_id,
            }
        )

    target_accounts.append(
        {
            "id": suspense_account_id,
            "name": "Legacy Import Suspense",
            "account_type": "equity",
            "is_archived": 0,
            "notes": json.dumps(
                {
                    "legacy_source": "system",
                    "purpose": "fallback contra account when no category mapping exists",
                }
            ),
            "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            "source_kind": "system",
            "source_id": "legacy-import-suspense",
        }
    )

    category_to_target_account = {
        row["source_category_id"]: row["target_account_id"]
        for row in map_source_category_rows
    }

    target_import_records: list[dict[str, Any]] = []
    map_source_import_rows: list[dict[str, Any]] = []
    for row in source_imports:
        row_count = int(row["row_count"])
        target_import_records.append(
            {
                "id": row["id"],
                "file_name": f"legacy-import-{row['id']}.csv",
                "imported_at": row["created_at"],
                "row_count": row_count,
                "source_import_id": row["id"],
                "source_status": none_if_empty(row["status"]),
            }
        )
        map_source_import_rows.append(
            {
                "source_import_id": row["id"],
                "target_import_record_id": row["id"],
            }
        )

    target_transactions: list[dict[str, Any]] = []
    target_entries: list[dict[str, Any]] = []
    map_source_transaction_rows: list[dict[str, Any]] = []
    consumed_transactions: set[str] = set()

    rejected_pairs = {
        canonical_pair(row["inflow_transaction_id"], row["outflow_transaction_id"])
        for row in source_rejected_transfers
    }

    transfer_rows_sorted = sorted(
        source_transfers,
        key=lambda row: (row["created_at"], row["id"]),
    )

    for transfer_row in transfer_rows_sorted:
        inflow_id = transfer_row["inflow_transaction_id"]
        outflow_id = transfer_row["outflow_transaction_id"]
        pair = canonical_pair(inflow_id, outflow_id)

        if pair in rejected_pairs:
            warnings.append(
                {
                    "code": "transfer_rejected_override",
                    "message": "Transfer pair exists in rejected_transfers; kept as independent transactions.",
                    "payload": json.dumps(
                        {"transfer_id": transfer_row["id"], "inflow_transaction_id": inflow_id, "outflow_transaction_id": outflow_id}
                    ),
                }
            )
            continue

        inflow_tx = source_transactions.get(inflow_id)
        outflow_tx = source_transactions.get(outflow_id)
        if inflow_tx is None or outflow_tx is None:
            warnings.append(
                {
                    "code": "transfer_missing_source_transaction",
                    "message": "Transfer references missing source transaction; pair skipped.",
                    "payload": json.dumps(
                        {
                            "transfer_id": transfer_row["id"],
                            "inflow_exists": inflow_tx is not None,
                            "outflow_exists": outflow_tx is not None,
                        }
                    ),
                }
            )
            continue

        if inflow_id in consumed_transactions or outflow_id in consumed_transactions:
            warnings.append(
                {
                    "code": "transfer_already_consumed_transaction",
                    "message": "Transfer references a transaction already consumed by another pair; pair skipped.",
                    "payload": json.dumps({"transfer_id": transfer_row["id"], "inflow_transaction_id": inflow_id, "outflow_transaction_id": outflow_id}),
                }
            )
            continue

        status = (transfer_row["status"] or "").lower()
        pair_allowed = status == "confirmed" or (
            status == "pending" and should_pair_pending_transfer(outflow_tx, inflow_tx)
        )
        if not pair_allowed:
            continue

        outflow_entry_type = entry_type_for_source_amount(outflow_tx.amount)
        inflow_entry_type = entry_type_for_source_amount(inflow_tx.amount)
        if outflow_entry_type is None or inflow_entry_type is None:
            warnings.append(
                {
                    "code": "transfer_zero_amount",
                    "message": "Transfer side had zero amount; pair skipped.",
                    "payload": json.dumps({"transfer_id": transfer_row["id"]}),
                }
            )
            continue

        if outflow_entry_type == inflow_entry_type:
            warnings.append(
                {
                    "code": "transfer_same_entry_type",
                    "message": "Transfer sides mapped to same entry type; forcing opposite type for inflow side.",
                    "payload": json.dumps(
                        {
                            "transfer_id": transfer_row["id"],
                            "outflow_entry_type": outflow_entry_type,
                            "inflow_entry_type": inflow_entry_type,
                        }
                    ),
                }
            )
            inflow_entry_type = opposite_entry_type(outflow_entry_type)

        out_amount = abs(outflow_tx.amount)
        in_amount = abs(inflow_tx.amount)
        if out_amount != in_amount:
            warnings.append(
                {
                    "code": "transfer_amount_mismatch",
                    "message": "Transfer absolute amounts differ; used outflow absolute amount.",
                    "payload": json.dumps(
                        {
                            "transfer_id": transfer_row["id"],
                            "out_amount": decimal_string(out_amount),
                            "in_amount": decimal_string(in_amount),
                        }
                    ),
                }
            )
        amount = out_amount

        chosen_date = max(
            [d for d in (outflow_tx.transaction_date, inflow_tx.transaction_date) if d is not None],
            default=None,
        )
        transaction_date_str = (
            chosen_date.isoformat()
            if chosen_date is not None
            else outflow_tx.transaction_created_at.split(" ")[0]
        )
        payee = (outflow_tx.name or "").strip() or (inflow_tx.name or "").strip() or "Transfer"
        import_record_id = choose_import_record_id(
            [outflow_tx.import_id, inflow_tx.import_id],
            known_import_ids,
            warnings,
            {"transfer_id": transfer_row["id"]},
        )
        target_tx_id = uuid_for("paired-transfer-transaction", pair[0], pair[1])

        note_parts = []
        if outflow_tx.notes:
            note_parts.append(outflow_tx.notes)
        if inflow_tx.notes and inflow_tx.notes != outflow_tx.notes:
            note_parts.append(inflow_tx.notes)
        if none_if_empty(transfer_row["notes"]):
            note_parts.append(transfer_row["notes"])
        note_parts.append(
            json.dumps(
                {
                    "legacy_source": "transfers",
                    "legacy_transfer_id": transfer_row["id"],
                    "legacy_status": status,
                    "source_outflow_transaction_id": outflow_id,
                    "source_inflow_transaction_id": inflow_id,
                }
            )
        )

        target_transactions.append(
            {
                "id": target_tx_id,
                "date": transaction_date_str,
                "payee": payee,
                "notes": " | ".join(note_parts),
                "import_record_id": import_record_id,
                "created_at": max(outflow_tx.transaction_created_at, inflow_tx.transaction_created_at),
                "source_mode": "paired_transfer",
                "source_transaction_ids": f"{outflow_id},{inflow_id}",
                "source_transfer_status": status,
            }
        )

        target_entries.append(
            {
                "id": uuid_for("paired-transfer-entry-outflow", target_tx_id),
                "transaction_id": target_tx_id,
                "account_id": outflow_tx.account_id,
                "amount": decimal_string(amount),
                "entry_type": outflow_entry_type,
                "memo": none_if_empty(outflow_tx.name),
                "source_entry_id": outflow_tx.entry_id,
            }
        )
        target_entries.append(
            {
                "id": uuid_for("paired-transfer-entry-inflow", target_tx_id),
                "transaction_id": target_tx_id,
                "account_id": inflow_tx.account_id,
                "amount": decimal_string(amount),
                "entry_type": inflow_entry_type,
                "memo": none_if_empty(inflow_tx.name),
                "source_entry_id": inflow_tx.entry_id,
            }
        )

        map_source_transaction_rows.append(
            {
                "source_transaction_id": outflow_id,
                "target_transaction_id": target_tx_id,
                "role": "paired_transfer_outflow",
            }
        )
        map_source_transaction_rows.append(
            {
                "source_transaction_id": inflow_id,
                "target_transaction_id": target_tx_id,
                "role": "paired_transfer_inflow",
            }
        )
        consumed_transactions.add(outflow_id)
        consumed_transactions.add(inflow_id)

    for tx in sorted(source_transactions.values(), key=lambda row: (row.transaction_created_at, row.transaction_id)):
        if tx.transaction_id in consumed_transactions:
            continue
        entry_type = entry_type_for_source_amount(tx.amount)
        if entry_type is None:
            warnings.append(
                {
                    "code": "transaction_zero_amount",
                    "message": "Source transaction had zero amount and was skipped.",
                    "payload": json.dumps({"transaction_id": tx.transaction_id}),
                }
            )
            continue

        amount = abs(tx.amount)
        contra_account_id: str
        if tx.category_id and tx.category_id in category_to_target_account:
            contra_account_id = category_to_target_account[tx.category_id]
        else:
            contra_account_id = suspense_account_id
            if tx.category_id:
                warnings.append(
                    {
                        "code": "transaction_missing_category_mapping",
                        "message": "Category mapping missing; used suspense account.",
                        "payload": json.dumps({"transaction_id": tx.transaction_id, "category_id": tx.category_id}),
                    }
                )

        transaction_date = (
            tx.transaction_date.isoformat()
            if tx.transaction_date is not None
            else tx.transaction_created_at.split(" ")[0]
        )
        payee = tx.name.strip() or "Legacy Transaction"
        import_record_id = choose_import_record_id(
            [tx.import_id],
            known_import_ids,
            warnings,
            {"transaction_id": tx.transaction_id},
        )

        metadata_note = json.dumps(
            {
                "legacy_source": "transactions",
                "legacy_transaction_id": tx.transaction_id,
                "legacy_entry_id": tx.entry_id,
                "legacy_kind": tx.kind,
                "legacy_category_id": tx.category_id,
                "legacy_merchant_id": tx.merchant_id,
                "legacy_excluded": tx.excluded,
            }
        )
        notes = " | ".join(part for part in [tx.notes, metadata_note] if part)

        target_transactions.append(
            {
                "id": tx.transaction_id,
                "date": transaction_date,
                "payee": payee,
                "notes": notes,
                "import_record_id": import_record_id,
                "created_at": tx.transaction_created_at,
                "source_mode": "single_transaction",
                "source_transaction_ids": tx.transaction_id,
                "source_transfer_status": None,
            }
        )

        target_entries.append(
            {
                "id": uuid_for("single-transaction-primary-entry", tx.transaction_id),
                "transaction_id": tx.transaction_id,
                "account_id": tx.account_id,
                "amount": decimal_string(amount),
                "entry_type": entry_type,
                "memo": none_if_empty(tx.notes),
                "source_entry_id": tx.entry_id,
            }
        )
        target_entries.append(
            {
                "id": uuid_for("single-transaction-contra-entry", tx.transaction_id),
                "transaction_id": tx.transaction_id,
                "account_id": contra_account_id,
                "amount": decimal_string(amount),
                "entry_type": opposite_entry_type(entry_type),
                "memo": None,
                "source_entry_id": None,
            }
        )
        map_source_transaction_rows.append(
            {
                "source_transaction_id": tx.transaction_id,
                "target_transaction_id": tx.transaction_id,
                "role": "single_transaction",
            }
        )

    target_budgets: list[dict[str, Any]] = []
    for row in source_budget_categories:
        category_id = row["category_id"]
        category = category_by_id.get(category_id)
        if category is None:
            warnings.append(
                {
                    "code": "budget_missing_category",
                    "message": "Budget category references missing category; row skipped.",
                    "payload": json.dumps({"budget_category_id": row["id"], "category_id": category_id}),
                }
            )
            continue
        classification = category["classification"].lower()
        if classification != "expense":
            warnings.append(
                {
                    "code": "budget_non_expense_category",
                    "message": "Budget category is not expense; row skipped.",
                    "payload": json.dumps(
                        {
                            "budget_category_id": row["id"],
                            "category_id": category_id,
                            "classification": classification,
                        }
                    ),
                }
            )
            continue
        account_id = category_to_target_account.get(category_id)
        if account_id is None:
            warnings.append(
                {
                    "code": "budget_missing_category_mapping",
                    "message": "Budget category has no mapped target account; row skipped.",
                    "payload": json.dumps({"budget_category_id": row["id"], "category_id": category_id}),
                }
            )
            continue

        budget_row = budget_by_id.get(row["budget_id"])
        if budget_row is None:
            warnings.append(
                {
                    "code": "budget_missing_budget_parent",
                    "message": "Budget category references missing budget row; row skipped.",
                    "payload": json.dumps({"budget_category_id": row["id"], "budget_id": row["budget_id"]}),
                }
            )
            continue

        start_date = parse_date(budget_row["start_date"])
        if start_date is None:
            warnings.append(
                {
                    "code": "budget_invalid_start_date",
                    "message": "Budget start_date is invalid; row skipped.",
                    "payload": json.dumps({"budget_category_id": row["id"], "start_date": budget_row["start_date"]}),
                }
            )
            continue

        try:
            amount = parse_decimal(row["budgeted_spending"], context=f"budget_category {row['id']}")
        except ValueError as exc:
            warnings.append(
                {
                    "code": "budget_invalid_amount",
                    "message": str(exc),
                    "payload": json.dumps({"budget_category_id": row["id"]}),
                }
            )
            continue

        target_budgets.append(
            {
                "id": row["id"],
                "account_id": account_id,
                "year": start_date.year,
                "month": start_date.month,
                "amount": decimal_string(abs(amount)),
                "source_budget_category_id": row["id"],
                "currency": none_if_empty(row["currency"]),
            }
        )

    conn = sqlite3.connect(output_path)
    try:
        conn.execute("PRAGMA journal_mode = WAL;")
        conn.execute("PRAGMA synchronous = NORMAL;")
        conn.execute("BEGIN")
        create_schema(conn)

        insert_many(
            conn,
            "metadata",
            ["key", "value"],
            [
                {"key": "source_db", "value": args.source_db},
                {"key": "family_id", "value": family_id},
                {"key": "exported_at_utc", "value": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")},
                {"key": "script_version", "value": "1"},
            ],
        )

        insert_many(
            conn,
            "raw_accounts",
            ["id", "family_id", "name", "classification", "status", "created_at", "updated_at", "subtype", "currency"],
            [
                {
                    "id": row["id"],
                    "family_id": row["family_id"],
                    "name": none_if_empty(row["name"]),
                    "classification": none_if_empty(row["classification"]),
                    "status": none_if_empty(row["status"]),
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                    "subtype": none_if_empty(row["subtype"]),
                    "currency": none_if_empty(row["currency"]),
                }
                for row in source_accounts
            ],
        )
        insert_many(
            conn,
            "raw_categories",
            ["id", "family_id", "name", "classification", "color", "parent_id", "created_at", "updated_at"],
            [
                {
                    "id": row["id"],
                    "family_id": row["family_id"],
                    "name": row["name"],
                    "classification": row["classification"],
                    "color": none_if_empty(row["color"]),
                    "parent_id": none_if_empty(row["parent_id"]),
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
                for row in source_categories
            ],
        )
        insert_many(
            conn,
            "raw_transactions",
            [
                "transaction_id",
                "kind",
                "category_id",
                "merchant_id",
                "transaction_created_at",
                "transaction_updated_at",
                "entry_id",
                "account_id",
                "account_classification",
                "amount",
                "currency",
                "date",
                "name",
                "notes",
                "import_id",
                "entry_created_at",
                "entry_updated_at",
                "excluded",
            ],
            [
                {
                    "transaction_id": row["transaction_id"],
                    "kind": none_if_empty(row["kind"]),
                    "category_id": none_if_empty(row["category_id"]),
                    "merchant_id": none_if_empty(row["merchant_id"]),
                    "transaction_created_at": row["transaction_created_at"],
                    "transaction_updated_at": row["transaction_updated_at"],
                    "entry_id": row["entry_id"],
                    "account_id": row["account_id"],
                    "account_classification": none_if_empty(row["account_classification"]),
                    "amount": row["amount"],
                    "currency": none_if_empty(row["currency"]),
                    "date": none_if_empty(row["date"]),
                    "name": none_if_empty(row["name"]),
                    "notes": none_if_empty(row["notes"]),
                    "import_id": none_if_empty(row["import_id"]),
                    "entry_created_at": row["entry_created_at"],
                    "entry_updated_at": row["entry_updated_at"],
                    "excluded": 1 if row["excluded"].lower() == "true" else 0,
                }
                for row in source_transaction_rows
            ],
        )
        insert_many(
            conn,
            "raw_transfers",
            ["id", "inflow_transaction_id", "outflow_transaction_id", "status", "notes", "created_at", "updated_at"],
            [
                {
                    "id": row["id"],
                    "inflow_transaction_id": row["inflow_transaction_id"],
                    "outflow_transaction_id": row["outflow_transaction_id"],
                    "status": row["status"],
                    "notes": none_if_empty(row["notes"]),
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
                for row in source_transfers
            ],
        )
        insert_many(
            conn,
            "raw_rejected_transfers",
            ["id", "inflow_transaction_id", "outflow_transaction_id", "created_at", "updated_at"],
            [
                {
                    "id": row["id"],
                    "inflow_transaction_id": row["inflow_transaction_id"],
                    "outflow_transaction_id": row["outflow_transaction_id"],
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
                for row in source_rejected_transfers
            ],
        )
        insert_many(
            conn,
            "raw_budgets",
            ["budget_id", "start_date", "end_date", "budgeted_spending", "expected_income", "currency", "created_at", "updated_at"],
            [
                {
                    "budget_id": row["budget_id"],
                    "start_date": row["start_date"],
                    "end_date": row["end_date"],
                    "budgeted_spending": none_if_empty(row["budgeted_spending"]),
                    "expected_income": none_if_empty(row["expected_income"]),
                    "currency": none_if_empty(row["currency"]),
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
                for row in source_budgets
            ],
        )
        insert_many(
            conn,
            "raw_budget_categories",
            ["id", "budget_id", "category_id", "budgeted_spending", "currency", "created_at", "updated_at"],
            [
                {
                    "id": row["id"],
                    "budget_id": row["budget_id"],
                    "category_id": row["category_id"],
                    "budgeted_spending": row["budgeted_spending"],
                    "currency": none_if_empty(row["currency"]),
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
                for row in source_budget_categories
            ],
        )
        insert_many(
            conn,
            "raw_imports",
            ["id", "status", "type", "account_id", "date_format", "signage_convention", "amount_type_strategy", "row_count", "created_at", "updated_at"],
            [
                {
                    "id": row["id"],
                    "status": none_if_empty(row["status"]),
                    "type": none_if_empty(row["type"]),
                    "account_id": none_if_empty(row["account_id"]),
                    "date_format": none_if_empty(row["date_format"]),
                    "signage_convention": none_if_empty(row["signage_convention"]),
                    "amount_type_strategy": none_if_empty(row["amount_type_strategy"]),
                    "row_count": int(row["row_count"]),
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
                for row in source_imports
            ],
        )
        insert_many(
            conn,
            "raw_import_rows",
            [
                "id",
                "import_id",
                "account",
                "date",
                "qty",
                "ticker",
                "price",
                "amount",
                "currency",
                "name",
                "category",
                "tags",
                "entity_type",
                "notes",
                "exchange_operating_mic",
                "created_at",
                "updated_at",
            ],
            [
                {
                    "id": row["id"],
                    "import_id": row["import_id"],
                    "account": none_if_empty(row["account"]),
                    "date": none_if_empty(row["date"]),
                    "qty": none_if_empty(row["qty"]),
                    "ticker": none_if_empty(row["ticker"]),
                    "price": none_if_empty(row["price"]),
                    "amount": none_if_empty(row["amount"]),
                    "currency": none_if_empty(row["currency"]),
                    "name": none_if_empty(row["name"]),
                    "category": none_if_empty(row["category"]),
                    "tags": none_if_empty(row["tags"]),
                    "entity_type": none_if_empty(row["entity_type"]),
                    "notes": none_if_empty(row["notes"]),
                    "exchange_operating_mic": none_if_empty(row["exchange_operating_mic"]),
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
                for row in source_import_rows
            ],
        )

        insert_many(
            conn,
            "target_accounts",
            ["id", "name", "account_type", "is_archived", "notes", "created_at", "source_kind", "source_id"],
            target_accounts,
        )
        insert_many(
            conn,
            "target_import_records",
            ["id", "file_name", "imported_at", "row_count", "source_import_id", "source_status"],
            target_import_records,
        )
        insert_many(
            conn,
            "target_transactions",
            [
                "id",
                "date",
                "payee",
                "notes",
                "import_record_id",
                "created_at",
                "source_mode",
                "source_transaction_ids",
                "source_transfer_status",
            ],
            target_transactions,
        )
        insert_many(
            conn,
            "target_entries",
            ["id", "transaction_id", "account_id", "amount", "entry_type", "memo", "source_entry_id"],
            target_entries,
        )
        insert_many(
            conn,
            "target_budgets",
            ["id", "account_id", "year", "month", "amount", "source_budget_category_id", "currency"],
            target_budgets,
        )
        insert_many(
            conn,
            "map_source_account_to_target_account",
            ["source_account_id", "target_account_id"],
            map_source_account_rows,
        )
        insert_many(
            conn,
            "map_source_category_to_target_account",
            ["source_category_id", "target_account_id"],
            map_source_category_rows,
        )
        insert_many(
            conn,
            "map_source_transaction_to_target_transaction",
            ["source_transaction_id", "target_transaction_id", "role"],
            map_source_transaction_rows,
        )
        insert_many(
            conn,
            "map_source_import_to_target_import_record",
            ["source_import_id", "target_import_record_id"],
            map_source_import_rows,
        )
        insert_many(
            conn,
            "warnings",
            ["code", "message", "payload"],
            warnings,
        )

        invariant_failures = validate_target_invariants(conn)
        if invariant_failures:
            raise RuntimeError("Invariant validation failed: " + " ".join(invariant_failures))

        conn.commit()
    except Exception:
        conn.rollback()
        conn.close()
        if output_path.exists():
            output_path.unlink()
        raise
    finally:
        if conn:
            conn.close()

    print("Export completed.")
    print(f"  Source DB: {args.source_db}")
    print(f"  Family ID: {family_id}")
    print(f"  Output: {output_path}")

    summary_tables = [
        "raw_accounts",
        "raw_categories",
        "raw_transactions",
        "raw_transfers",
        "raw_rejected_transfers",
        "raw_budgets",
        "raw_budget_categories",
        "raw_imports",
        "raw_import_rows",
        "target_accounts",
        "target_import_records",
        "target_transactions",
        "target_entries",
        "target_budgets",
        "warnings",
    ]

    summary_conn = sqlite3.connect(output_path)
    try:
        for table in summary_tables:
            count = summary_conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            print(f"  {table}: {count}")
    finally:
        summary_conn.close()

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # pragma: no cover - CLI failure path
        print(f"Export failed: {exc}", file=sys.stderr)
        sys.exit(1)
