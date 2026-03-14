#!/usr/bin/env python3
"""
import_off_dach.py

Streams the OpenFoodFacts CSV export and upserts DACH products
(Germany, Austria, Switzerland) into the global_product_catalog table
in Supabase.

Usage:
    python3 scripts/import_off_dach.py
    python3 scripts/import_off_dach.py --dry-run --limit 1000
    python3 scripts/import_off_dach.py --since 2025-01-01

Requirements:
    pip install supabase requests

Environment Variables (never commit these):
    SUPABASE_URL            – your project URL, e.g. https://xxxx.supabase.co
    SUPABASE_SERVICE_ROLE_KEY – service-role key with write access

Security:
    The service-role key grants full database access. Load it only from
    environment variables, never from source code or committed files.
"""

import argparse
import csv
import gzip
import io
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone
from typing import Optional

# OFF CSV enthält sehr lange Felder (z.B. ingredients_text) — Limit auf 10 MB erhöhen
csv.field_size_limit(10 * 1024 * 1024)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

OFF_CSV_URL = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
DACH_COUNTRY_TAGS = {"en:germany", "en:austria", "en:switzerland"}
BATCH_SIZE = 500
MIN_SCANS = 1  # Eliminates spam/test products

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import DACH products from OpenFoodFacts into Supabase.")
    parser.add_argument("--dry-run", action="store_true", help="Parse and filter but do not write to Supabase.")
    parser.add_argument("--limit", type=int, default=0, help="Stop after this many accepted rows (0 = no limit).")
    parser.add_argument(
        "--since",
        type=str,
        default="",
        help="Only import products modified after this date (YYYY-MM-DD). Uses last_modified_t column.",
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def load_supabase_client():
    """Initialise the Supabase client from environment variables."""
    try:
        from supabase import create_client
    except ImportError:
        print("ERROR: supabase-py not installed. Run: pip install supabase", file=sys.stderr)
        sys.exit(1)

    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        print(
            "ERROR: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.",
            file=sys.stderr,
        )
        sys.exit(1)
    return create_client(url, key)


def is_dach(row: dict) -> bool:
    """Return True if the product is sold in Germany, Austria or Switzerland."""
    tags = row.get("countries_tags", "")
    return any(tag in tags for tag in DACH_COUNTRY_TAGS)


def has_scans(row: dict) -> bool:
    """Return True if the product has been scanned at least MIN_SCANS times."""
    try:
        return int(row.get("unique_scans_n", 0)) >= MIN_SCANS
    except (ValueError, TypeError):
        return False


def is_valid_code(row: dict) -> bool:
    """Return True if the barcode is non-empty and numeric."""
    code = row.get("code", "").strip()
    return bool(code) and code.isdigit()


def has_name(row: dict) -> bool:
    """Return True if the product name is non-empty."""
    return bool(row.get("product_name", "").strip())


def since_timestamp(since_str: str) -> Optional[int]:
    """Convert a YYYY-MM-DD string to a Unix timestamp, or None."""
    if not since_str:
        return None
    dt = datetime.strptime(since_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    return int(dt.timestamp())


def map_row(row: dict) -> dict:
    """Map a CSV row to the global_product_catalog schema."""
    # brands is a comma-separated list; use first brand only
    brands_raw = row.get("brands", "").strip()
    brand = brands_raw.split(",")[0].strip() if brands_raw else None

    # categories_de is a comma-separated list; use first category
    categories_raw = row.get("categories_de", "").strip()
    category = categories_raw.split(",")[0].strip() if categories_raw else None

    try:
        scans_n = int(row.get("unique_scans_n", 0))
    except (ValueError, TypeError):
        scans_n = 0

    return {
        "code": row["code"].strip(),
        "name": row["product_name"].strip(),
        "brand": brand or None,
        "category": category or None,
        "measure": row.get("quantity", "").strip() or None,
        "image_url": row.get("image_url", "").strip() or None,
        "scans_n": scans_n,
    }


def upsert_batch(client, batch: list[dict], dry_run: bool) -> int:
    """Upsert a batch of rows. Returns number of rows upserted.
    Deduplicates within the batch by code (last-wins) to avoid Postgres
    'ON CONFLICT DO UPDATE command cannot affect row a second time' error.
    """
    # Keep only the last occurrence of each code within this batch
    deduped: dict[str, dict] = {}
    for row in batch:
        deduped[row["code"]] = row
    unique_batch = list(deduped.values())
    if dry_run:
        return len(unique_batch)
    client.table("global_product_catalog").upsert(unique_batch, on_conflict="code").execute()
    return len(unique_batch)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    args = parse_args()
    since_ts = since_timestamp(args.since)
    client = None if args.dry_run else load_supabase_client()

    print(f"Downloading & streaming OpenFoodFacts CSV from {OFF_CSV_URL} …")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}", flush=True)

    batch: list[dict] = []
    total_read = 0
    total_accepted = 0
    total_upserted = 0
    start = time.time()

    with urllib.request.urlopen(OFF_CSV_URL) as response:
        with gzip.open(response, "rt", encoding="utf-8", errors="replace") as f:
            reader = csv.DictReader(f, delimiter="\t")

            for row in reader:
                total_read += 1

                # Incremental filter: skip rows not modified since --since
                if since_ts is not None:
                    try:
                        modified = int(row.get("last_modified_t", 0))
                        if modified < since_ts:
                            continue
                    except (ValueError, TypeError):
                        pass

                # Quality filters
                if not is_valid_code(row):
                    continue
                if not has_name(row):
                    continue
                if not is_dach(row):
                    continue
                if not has_scans(row):
                    continue

                batch.append(map_row(row))
                total_accepted += 1

                if len(batch) >= BATCH_SIZE:
                    total_upserted += upsert_batch(client, batch, args.dry_run)
                    batch = []
                    elapsed = time.time() - start
                    print(
                        f"  rows read: {total_read:,} | accepted: {total_accepted:,} | "
                        f"upserted: {total_upserted:,} | {elapsed:.0f}s",
                        flush=True,
                    )

                if args.limit and total_accepted >= args.limit:
                    print(f"Limit of {args.limit} rows reached. Stopping.")
                    break

            # Flush remaining rows
            if batch:
                total_upserted += upsert_batch(client, batch, args.dry_run)

    elapsed = time.time() - start
    print(
        f"\nDone. Rows read: {total_read:,} | Accepted: {total_accepted:,} | "
        f"Upserted: {total_upserted:,} | Time: {elapsed:.1f}s"
    )


if __name__ == "__main__":
    main()
