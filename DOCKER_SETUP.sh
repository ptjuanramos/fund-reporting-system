#!/bin/bash
# ============================================================
# Prerequisites:
#     docker run -d --name oracle-fund-db \
#       -p 1521:1521 \
#       -e ORACLE_PWD=FundAdmin#2024 \
#       -v ~/oracle-fund-data:/opt/oracle/oradata \
#       container-registry.oracle.com/database/free:latest
# ============================================================

set -euo pipefail

# ── config ────────────────────────────────────────────────────
CONTAINER="oracle-fund-db"
SYS_PWD="FundAdmin#2024"
FUND_PWD="FundAdmin#2024"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_CREATE_USER="$SCRIPT_DIR/00_create_user.sql"
SQL_SCHEMA="$SCRIPT_DIR/01_fund_reporting_schema.sql"

# ── colours ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
step()    { echo -e "${BLUE}[STEP]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── helpers ───────────────────────────────────────────────────
run_sql_file() {
  # run_sql_file <connect_string> <local_sql_file> <label>
  local connect_str="$1"
  local local_file="$2"
  local label="$3"
  local remote="/tmp/$(basename "$local_file")"

  info "  Copying $label to container..."
  docker cp "$local_file" "$CONTAINER:$remote"

  info "  Executing $label..."
  docker exec -i "$CONTAINER" sqlplus -S -L "$connect_str" < "$local_file"


  info "  $label — done."
}

# ── pre-flight checks ─────────────────────────────────────────
echo ""
step "Pre-flight checks"

command -v docker &>/dev/null || die "Docker not found in PATH."

[[ -f "$SQL_CREATE_USER" ]] \
  || die "Missing: $SQL_CREATE_USER"
[[ -f "$SQL_SCHEMA" ]] \
  || die "Missing: $SQL_SCHEMA"

STATUS=$(docker inspect --format='{{.State.Health.Status}}' \
           "$CONTAINER" 2>/dev/null || echo "missing")

if [[ "$STATUS" != "healthy" ]]; then
  echo ""
  warn "Container '$CONTAINER' is not healthy (status: $STATUS)."
  echo ""
  echo "  Start it first:"
  echo "    docker run -d --name oracle-fund-db \\"
  echo "      -p 1521:1521 \\"
  echo "      -e ORACLE_PWD=FundAdmin#2024 \\"
  echo "      -v ~/oracle-fund-data:/opt/oracle/oradata \\"
  echo "      container-registry.oracle.com/database/free:latest"
  echo ""
  echo "  Then wait for (healthy):"
  echo "    watch docker ps --filter name=oracle-fund-db"
  echo ""
  die "Aborting."
fi

info "Container '$CONTAINER' is healthy."

# ── step 1: create fund_admin user ────────────────────────────
echo ""
step "Step 1/2 — Creating fund_admin user (connecting as sys sysdba)"

# NOTE: The password contains '#' which is special in bash.
# Wrapping in single quotes makes it safe for the shell.
# SQLPlus receives it literally.
run_sql_file \
  'sys/'"${SYS_PWD}"'@FREE as sysdba' \
  "$SQL_CREATE_USER" \
  "00_create_user.sql"

# ── step 2: schema + seed data ────────────────────────────────
echo ""
step "Step 2/2 — Running schema + seed (connecting as fund_admin)"
info "  This inserts 90 days of positions, prices, fx rates and"
info "  benchmark values — expect ~30-60 seconds."

run_sql_file \
  'fund_admin/'"${FUND_PWD}"'@FREEPDB1' \
  "$SQL_SCHEMA" \
  "01_fund_reporting_schema.sql"

# ── done ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo "  Interactive SQLPlus:"
echo "    docker exec -it $CONTAINER \\"
echo "      sqlplus fund_admin/\"${FUND_PWD}\"@FREEPDB1"
echo ""
echo "  JDBC URL:"
echo "    jdbc:oracle:thin:@//localhost:1521/FREEPDB1"
echo ""
echo "  SQL Developer / DBeaver:"
echo "    Host:         localhost"
echo "    Port:         1521"
echo "    Service name: FREEPDB1"
echo "    User:         fund_admin"
echo "    Password:     ${FUND_PWD}"
echo ""
