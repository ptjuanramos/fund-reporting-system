#!/bin/bash

set -euo pipefail

# ── config ────────────────────────────────────────────────────
CONTAINER="oracle-fund-db"
SYS_PWD="${ORACLE_PWD:-FundAdmin#2024}"
FUND_PWD="${ORACLE_PWD:-FundAdmin#2024}"

# ── colours ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
step() { echo -e "${BLUE}[STEP]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── detect mode ───────────────────────────────────────────────
# If sqlplus exists AND docker is absent → we are inside the container
if command -v sqlplus &>/dev/null && ! command -v docker &>/dev/null; then
  MODE="container"
else
  MODE="host"
fi

info "Mode: $MODE"

# ── resolve SQL file paths ────────────────────────────────────
if [[ "$MODE" == "container" ]]; then
  SCRIPT_DIR="/opt/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

SQL_CREATE_USER="$SCRIPT_DIR/00_create_user.sql"
SQL_SCHEMA="$SCRIPT_DIR/01_fund_reporting_schema.sql"

[[ -f "$SQL_CREATE_USER" ]] || die "Missing: $SQL_CREATE_USER"
[[ -f "$SQL_SCHEMA"      ]] || die "Missing: $SQL_SCHEMA"

# ── connection strings ────────────────────────────────────────
# In container mode we must use the full host:port/service
# because sqlplus is NOT on the Oracle host — it is on db-init,
# which reaches Oracle over the fund-net Docker network.
# In host mode we pipe through docker exec so Oracle resolves
# FREE/FREEPDB1 locally inside its own container.
if [[ "$MODE" == "container" ]]; then
  CONN_SYS="sys/${SYS_PWD}@//oracle-fund-db:1521/FREE as sysdba"
  CONN_FUND="fund_admin/${FUND_PWD}@//oracle-fund-db:1521/FREEPDB1"
else
  CONN_SYS="sys/${SYS_PWD}@FREE as sysdba"
  CONN_FUND="fund_admin/${FUND_PWD}@FREEPDB1"
fi

# ── run_sql ───────────────────────────────────────────────────
run_sql() {
  local connect_str="$1"
  local sql_file="$2"
  local label="$3"

  info "  Executing $label..."

  if [[ "$MODE" == "container" ]]; then
    sqlplus -S -L "$connect_str" < "$sql_file"
  else
    docker exec -i "$CONTAINER" sqlplus -S -L "$connect_str" < "$sql_file"
  fi

  info "  $label — done."
}

# ── pre-flight (host mode only) ───────────────────────────────
if [[ "$MODE" == "host" ]]; then
  step "Pre-flight checks"
  command -v docker &>/dev/null || die "Docker not found in PATH."

  STATUS=$(docker inspect --format='{{.State.Health.Status}}' \
             "$CONTAINER" 2>/dev/null || echo "missing")

  if [[ "$STATUS" != "healthy" ]]; then
    warn "Container '$CONTAINER' is not healthy (status: $STATUS)."
    echo "  Run:  docker compose up -d oracle-fund-db"
    echo "  Wait: watch docker ps --filter name=oracle-fund-db"
    die "Aborting."
  fi
  info "Container is healthy."
fi

# ── step 1 ────────────────────────────────────────────────────
echo ""
step "Step 1/2 — Creating fund_admin user (sys sysdba)"
run_sql "$CONN_SYS" "$SQL_CREATE_USER" "00_create_user.sql"

# ── step 2 ────────────────────────────────────────────────────
echo ""
step "Step 2/2 — Schema + seed data (~30-60s)"
run_sql "$CONN_FUND" "$SQL_SCHEMA" "01_fund_reporting_schema.sql"

# ── done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  Connect locally:"
echo "    sqlplus fund_admin/\"${FUND_PWD}\"@//localhost:1521/FREEPDB1"
echo ""
echo "  JDBC URL:"
echo "    jdbc:oracle:thin:@//localhost:1521/FREEPDB1"
echo ""