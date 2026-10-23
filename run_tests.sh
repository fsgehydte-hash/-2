#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
python3 sqlite_model/test_model.py
python3 static_sql_checks.py
python3 app_static_checks.py
