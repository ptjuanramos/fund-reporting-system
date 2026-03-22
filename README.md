# fund-reporting-system
Learning purposes only (Databricks and core DBMS concepts)


# ────────────────────────────────────────────────────────────
# USEFUL COMMANDS — Day-to-day operations
# ────────────────────────────────────────────────────────────

# Stop the container (data persists in ~/oracle-fund-data):
docker stop oracle-fund-db

# Restart from existing data (fast, ~20s):
docker start oracle-fund-db

# Open interactive SQLPlus as SYSDBA (admin tasks):
docker exec -it oracle-fund-db sqlplus sys/FundAdmin#2024@FREE as sysdba

# Open interactive SQLPlus on the Fund PDB:
docker exec -it oracle-fund-db sqlplus pdbadmin/FundAdmin#2024@FREEPDB1

# Change the password:
docker exec oracle-fund-db ./setPassword.sh NewPassword#2025

# Destroy and recreate from scratch (WARNING: deletes all data):
docker rm -f oracle-fund-db
rm -rf ~/oracle-fund-data
# Then run STEP 2 + 3 again

# Check container resource usage:
docker stats oracle-fund-db


# JDBC URL
#   jdbc:oracle:thin:@//localhost:1521/FREEPDB1

# SQL Developer connection settings:
#   Host:          localhost
#   Port:          1521
#   Service Name:  FREEPDB1
#   User:          fund_admin  (or pdbadmin)
#   Password:      FundAdmin#2024

# Python (oracledb):
#   import oracledb
#   conn = oracledb.connect(user="fund_admin", password="FundAdmin#2024",
#                           dsn="localhost:1521/FREEPDB1")
