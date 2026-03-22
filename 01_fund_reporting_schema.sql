-- ============================================================
-- DROP EXISTING OBJECTS (if they exist)
-- ============================================================
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW v_daily_nav';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE report_runs';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE benchmark_values';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE fx_rates';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE prices';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE positions';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE client_fund_subscriptions';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE instruments';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE funds';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE clients';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

WHENEVER SQLERROR EXIT SQL.SQLCODE

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE clients (
    client_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_code        VARCHAR2(20)  NOT NULL UNIQUE,
    client_name        VARCHAR2(200) NOT NULL,
    email              VARCHAR2(200) NOT NULL,
    timezone           VARCHAR2(50)  DEFAULT 'Europe/Zurich',
    preferred_currency VARCHAR2(3)   DEFAULT 'CHF',
    report_template    VARCHAR2(50)  DEFAULT 'STANDARD',   -- STANDARD | DETAILED | COMPACT
    is_active          NUMBER(1)     DEFAULT 1,
    created_at         TIMESTAMP     DEFAULT SYSTIMESTAMP,
    updated_at         TIMESTAMP     DEFAULT SYSTIMESTAMP
);

CREATE TABLE funds (
    fund_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fund_code      VARCHAR2(20)  NOT NULL UNIQUE,
    fund_name      VARCHAR2(200) NOT NULL,
    isin           VARCHAR2(12),
    base_currency  VARCHAR2(3)   DEFAULT 'USD',
    fund_type      VARCHAR2(50),                           -- EQUITY | BOND | MIXED | MONEY_MARKET
    benchmark_code VARCHAR2(50),
    inception_date DATE,
    is_active      NUMBER(1)     DEFAULT 1,
    created_at     TIMESTAMP     DEFAULT SYSTIMESTAMP
);

CREATE TABLE client_fund_subscriptions (
    subscription_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id       NUMBER    NOT NULL REFERENCES clients(client_id),
    fund_id         NUMBER    NOT NULL REFERENCES funds(fund_id),
    subscribed_at   DATE      DEFAULT SYSDATE,
    unsubscribed_at DATE,
    is_active       NUMBER(1) DEFAULT 1,
    CONSTRAINT uq_client_fund UNIQUE (client_id, fund_id)
);

CREATE TABLE instruments (
    instrument_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticker          VARCHAR2(20)  NOT NULL UNIQUE,
    instrument_name VARCHAR2(200) NOT NULL,
    asset_class     VARCHAR2(50),                          -- EQUITY | BOND | CASH | ETF
    currency        VARCHAR2(3)   DEFAULT 'USD',
    exchange        VARCHAR2(50),
    isin            VARCHAR2(12),
    is_active       NUMBER(1)     DEFAULT 1
);

-- Range-partitioned by date — mirrors a warehouse-style table
CREATE TABLE positions (
    position_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fund_id       NUMBER       NOT NULL REFERENCES funds(fund_id),
    instrument_id NUMBER       NOT NULL REFERENCES instruments(instrument_id),
    position_date DATE         NOT NULL,
    quantity      NUMBER(20,6) NOT NULL,
    CONSTRAINT uq_pos UNIQUE (fund_id, instrument_id, position_date)
)
PARTITION BY RANGE (position_date) (
    PARTITION p2023    VALUES LESS THAN (DATE '2024-01-01'),
    PARTITION p2024    VALUES LESS THAN (DATE '2025-01-01'),
    PARTITION p2025    VALUES LESS THAN (DATE '2026-01-01'),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);

CREATE TABLE prices (
    price_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    instrument_id NUMBER       NOT NULL REFERENCES instruments(instrument_id),
    price_date    DATE         NOT NULL,
    close_price   NUMBER(18,6) NOT NULL,
    currency      VARCHAR2(3)  NOT NULL,
    source        VARCHAR2(50) DEFAULT 'MARKET_DATA_API',
    CONSTRAINT uq_price UNIQUE (instrument_id, price_date)
)
PARTITION BY RANGE (price_date) (
    PARTITION p2023    VALUES LESS THAN (DATE '2024-01-01'),
    PARTITION p2024    VALUES LESS THAN (DATE '2025-01-01'),
    PARTITION p2025    VALUES LESS THAN (DATE '2026-01-01'),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);

CREATE TABLE fx_rates (
    fx_rate_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rate_date     DATE         NOT NULL,
    from_currency VARCHAR2(3)  NOT NULL,
    to_currency   VARCHAR2(3)  DEFAULT 'USD' NOT NULL,
    rate          NUMBER(18,8) NOT NULL,
    CONSTRAINT uq_fx UNIQUE (rate_date, from_currency, to_currency)
);

CREATE TABLE benchmark_values (
    benchmark_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    benchmark_code VARCHAR2(50) NOT NULL,
    value_date     DATE         NOT NULL,
    index_value    NUMBER(18,4) NOT NULL,
    CONSTRAINT uq_bench UNIQUE (benchmark_code, value_date)
);

CREATE TABLE report_runs (
    run_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_date      DATE          NOT NULL,
    client_id     NUMBER        NOT NULL REFERENCES clients(client_id),
    fund_id       NUMBER        NOT NULL REFERENCES funds(fund_id),
    status        VARCHAR2(20)  DEFAULT 'PENDING',         -- PENDING | RUNNING | COMPLETED | FAILED
    started_at    TIMESTAMP,
    completed_at  TIMESTAMP,
    file_path     VARCHAR2(500),                           -- S3 / object-store path
    error_message VARCHAR2(2000),
    created_at    TIMESTAMP     DEFAULT SYSTIMESTAMP
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_positions_fund_date ON positions(fund_id, position_date);
CREATE INDEX idx_fx_date_currency    ON fx_rates(rate_date, from_currency);
CREATE INDEX idx_report_runs_client  ON report_runs(client_id, run_date);
CREATE INDEX idx_report_runs_status  ON report_runs(status);
CREATE INDEX idx_subs_client_active  ON client_fund_subscriptions(client_id, is_active);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Clients
INSERT INTO clients (client_code, client_name, email, timezone, preferred_currency, report_template) VALUES ('CLT001','Helvetia Pension Fund',    'reports@helvetia-pension.ch', 'Europe/Zurich',    'CHF','DETAILED');
INSERT INTO clients (client_code, client_name, email, timezone, preferred_currency, report_template) VALUES ('CLT002','Nordic Capital Partners',  'ops@nordiccap.se',            'Europe/Stockholm', 'EUR','STANDARD');
INSERT INTO clients (client_code, client_name, email, timezone, preferred_currency, report_template) VALUES ('CLT003','Zurich Institutional AM',  'fundreports@zia.ch',          'Europe/Zurich',    'CHF','STANDARD');
INSERT INTO clients (client_code, client_name, email, timezone, preferred_currency, report_template) VALUES ('CLT004','Atlantic Growth Advisors', 'reports@atlantic-ga.com',     'America/New_York', 'USD','COMPACT');
INSERT INTO clients (client_code, client_name, email, timezone, preferred_currency, report_template) VALUES ('CLT005','Midlands Endowment Trust', 'finance@midlands-endow.co.uk','Europe/London',    'GBP','DETAILED');
COMMIT;

-- Funds
INSERT INTO funds (fund_code, fund_name, isin, base_currency, fund_type, benchmark_code, inception_date) VALUES ('FND-GLBEQ', 'Global Equity Growth Fund',      'CH0123456789','USD','EQUITY',       'MSCI_WORLD', DATE '2018-01-15');
INSERT INTO funds (fund_code, fund_name, isin, base_currency, fund_type, benchmark_code, inception_date) VALUES ('FND-EUBD',  'European Investment Grade Bond', 'CH0234567891','EUR','BOND',         'EURO_AGG',   DATE '2019-06-01');
INSERT INTO funds (fund_code, fund_name, isin, base_currency, fund_type, benchmark_code, inception_date) VALUES ('FND-CHBAL', 'Swiss Balanced Opportunities',   'CH0345678912','CHF','MIXED',        'SPI',        DATE '2020-03-01');
INSERT INTO funds (fund_code, fund_name, isin, base_currency, fund_type, benchmark_code, inception_date) VALUES ('FND-USTECH','US Technology Leaders',          'CH0456789123','USD','EQUITY',       'NASDAQ100',  DATE '2021-09-10');
INSERT INTO funds (fund_code, fund_name, isin, base_currency, fund_type, benchmark_code, inception_date) VALUES ('FND-MMCHF', 'CHF Money Market Fund',          'CH0567891234','CHF','MONEY_MARKET', 'SARON',      DATE '2017-04-01');
COMMIT;

-- Subscriptions
INSERT INTO client_fund_subscriptions (client_id, fund_id) SELECT c.client_id, f.fund_id FROM clients c, funds f WHERE c.client_code='CLT001';
INSERT INTO client_fund_subscriptions (client_id, fund_id) SELECT c.client_id, f.fund_id FROM clients c, funds f WHERE c.client_code='CLT002' AND f.fund_code IN ('FND-GLBEQ','FND-EUBD');
INSERT INTO client_fund_subscriptions (client_id, fund_id) SELECT c.client_id, f.fund_id FROM clients c, funds f WHERE c.client_code='CLT003' AND f.fund_code IN ('FND-CHBAL','FND-MMCHF');
INSERT INTO client_fund_subscriptions (client_id, fund_id) SELECT c.client_id, f.fund_id FROM clients c, funds f WHERE c.client_code='CLT004' AND f.fund_code IN ('FND-USTECH','FND-GLBEQ');
INSERT INTO client_fund_subscriptions (client_id, fund_id) SELECT c.client_id, f.fund_id FROM clients c, funds f WHERE c.client_code='CLT005' AND f.fund_code IN ('FND-EUBD','FND-CHBAL');
COMMIT;

-- Instruments
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('AAPL',     'Apple Inc.',                  'EQUITY', 'USD', 'NASDAQ');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('MSFT',     'Microsoft Corporation',        'EQUITY', 'USD', 'NASDAQ');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('NVDA',     'NVIDIA Corporation',           'EQUITY', 'USD', 'NASDAQ');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('AMZN',     'Amazon.com Inc.',              'EQUITY', 'USD', 'NASDAQ');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('GOOGL',    'Alphabet Inc.',                'EQUITY', 'USD', 'NASDAQ');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('NESN',     'Nestle SA',                    'EQUITY', 'CHF', 'SIX');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('NOVN',     'Novartis AG',                  'EQUITY', 'CHF', 'SIX');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('ROG',      'Roche Holding AG',             'EQUITY', 'CHF', 'SIX');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('ADS',      'Adidas AG',                    'EQUITY', 'EUR', 'XETRA');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('SAP',      'SAP SE',                       'EQUITY', 'EUR', 'XETRA');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('DE10Y',    'German Bund 10Y 2.5% 2033',    'BOND',   'EUR', 'EUREX');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('CH10Y',    'Swiss Confederation Bond 10Y', 'BOND',   'CHF', 'SIX');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('CASH_USD', 'Cash USD',                     'CASH',   'USD', 'INTERNAL');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('CASH_CHF', 'Cash CHF',                     'CASH',   'CHF', 'INTERNAL');
INSERT INTO instruments (ticker, instrument_name, asset_class, currency, exchange) VALUES ('CASH_EUR', 'Cash EUR',                     'CASH',   'EUR', 'INTERNAL');
COMMIT;

-- ============================================================
-- POSITIONS — 90 rolling days, one row per fund/instrument/date
-- PL/SQL resolves tables against fund_admin because we are
-- connected as fund_admin (not pdbadmin).
-- ============================================================
BEGIN
  FOR d IN 0..89 LOOP
    DECLARE
      v_date DATE := TRUNC(SYSDATE) - d;
    BEGIN
      -- FND-GLBEQ: US tech + Swiss blue chips
      INSERT INTO positions (fund_id, instrument_id, position_date, quantity)
        SELECT f.fund_id, i.instrument_id, v_date,
          CASE i.ticker
            WHEN 'AAPL'     THEN  15000
            WHEN 'MSFT'     THEN  12000
            WHEN 'NVDA'     THEN   8000
            WHEN 'AMZN'     THEN   6000
            WHEN 'NESN'     THEN  20000
            WHEN 'NOVN'     THEN  18000
            WHEN 'CASH_USD' THEN 500000
            ELSE 0
          END
        FROM funds f, instruments i
        WHERE f.fund_code = 'FND-GLBEQ'
          AND i.ticker IN ('AAPL','MSFT','NVDA','AMZN','NESN','NOVN','CASH_USD');

      -- FND-EUBD: European bonds
      INSERT INTO positions (fund_id, instrument_id, position_date, quantity)
        SELECT f.fund_id, i.instrument_id, v_date,
          CASE i.ticker
            WHEN 'DE10Y'    THEN 1000000
            WHEN 'CH10Y'    THEN  800000
            WHEN 'CASH_EUR' THEN  200000
            ELSE 0
          END
        FROM funds f, instruments i
        WHERE f.fund_code = 'FND-EUBD'
          AND i.ticker IN ('DE10Y','CH10Y','CASH_EUR');

      -- FND-CHBAL: Swiss balanced
      INSERT INTO positions (fund_id, instrument_id, position_date, quantity)
        SELECT f.fund_id, i.instrument_id, v_date,
          CASE i.ticker
            WHEN 'NESN'     THEN  10000
            WHEN 'ROG'      THEN   9000
            WHEN 'CH10Y'    THEN 500000
            WHEN 'CASH_CHF' THEN 300000
            ELSE 0
          END
        FROM funds f, instruments i
        WHERE f.fund_code = 'FND-CHBAL'
          AND i.ticker IN ('NESN','ROG','CH10Y','CASH_CHF');

      -- FND-USTECH: heavy US tech
      INSERT INTO positions (fund_id, instrument_id, position_date, quantity)
        SELECT f.fund_id, i.instrument_id, v_date,
          CASE i.ticker
            WHEN 'AAPL'     THEN    25000
            WHEN 'MSFT'     THEN    20000
            WHEN 'NVDA'     THEN    18000
            WHEN 'GOOGL'    THEN    10000
            WHEN 'AMZN'     THEN    12000
            WHEN 'CASH_USD' THEN  1000000
            ELSE 0
          END
        FROM funds f, instruments i
        WHERE f.fund_code = 'FND-USTECH'
          AND i.ticker IN ('AAPL','MSFT','NVDA','GOOGL','AMZN','CASH_USD');

      -- FND-MMCHF: CHF money market
      INSERT INTO positions (fund_id, instrument_id, position_date, quantity)
        SELECT f.fund_id, i.instrument_id, v_date,
          CASE i.ticker
            WHEN 'CH10Y'    THEN 2000000
            WHEN 'CASH_CHF' THEN 5000000
            ELSE 0
          END
        FROM funds f, instruments i
        WHERE f.fund_code = 'FND-MMCHF'
          AND i.ticker IN ('CH10Y','CASH_CHF');
    END;
  END LOOP;
  COMMIT;
END;
/

-- ============================================================
-- PRICES — 90 rolling days with ±1.5 % random daily noise
-- ============================================================
BEGIN
  FOR d IN 0..89 LOOP
    DECLARE
      v_date DATE   := TRUNC(SYSDATE) - d;
      v_rand NUMBER := DBMS_RANDOM.VALUE(-0.015, 0.015);
    BEGIN
      INSERT INTO prices (instrument_id, price_date, close_price, currency)
        SELECT i.instrument_id, v_date,
          ROUND(
            CASE i.ticker
              WHEN 'AAPL'     THEN 189.50  * (1 + v_rand * DBMS_RANDOM.VALUE(0.5, 1.5))
              WHEN 'MSFT'     THEN 415.20  * (1 + v_rand * DBMS_RANDOM.VALUE(0.5, 1.5))
              WHEN 'NVDA'     THEN 875.00  * (1 + v_rand * DBMS_RANDOM.VALUE(0.5, 1.5))
              WHEN 'AMZN'     THEN 198.30  * (1 + v_rand * DBMS_RANDOM.VALUE(0.5, 1.5))
              WHEN 'GOOGL'    THEN 174.50  * (1 + v_rand * DBMS_RANDOM.VALUE(0.5, 1.5))
              WHEN 'NESN'     THEN  92.50  * (1 + v_rand * DBMS_RANDOM.VALUE(0.3, 1.0))
              WHEN 'NOVN'     THEN  88.30  * (1 + v_rand * DBMS_RANDOM.VALUE(0.3, 1.0))
              WHEN 'ROG'      THEN 237.40  * (1 + v_rand * DBMS_RANDOM.VALUE(0.3, 1.0))
              WHEN 'ADS'      THEN 212.00  * (1 + v_rand * DBMS_RANDOM.VALUE(0.3, 1.0))
              WHEN 'SAP'      THEN 188.90  * (1 + v_rand * DBMS_RANDOM.VALUE(0.3, 1.0))
              WHEN 'DE10Y'    THEN  98.50  * (1 + v_rand * DBMS_RANDOM.VALUE(0.1, 0.3))
              WHEN 'CH10Y'    THEN  99.10  * (1 + v_rand * DBMS_RANDOM.VALUE(0.1, 0.3))
              ELSE 1.00   -- CASH_USD / CASH_CHF / CASH_EUR
            END
          , 4),
          i.currency
        FROM instruments i
        WHERE i.ticker IN (
          'AAPL','MSFT','NVDA','AMZN','GOOGL',
          'NESN','NOVN','ROG','ADS','SAP',
          'DE10Y','CH10Y','CASH_USD','CASH_CHF','CASH_EUR'
        );
    END;
  END LOOP;
  COMMIT;
END;
/

-- ============================================================
-- FX RATES — 90 rolling days  (CHF, EUR, GBP, USD → USD)
-- ============================================================
BEGIN
  FOR d IN 0..89 LOOP
    DECLARE
      v_date  DATE   := TRUNC(SYSDATE) - d;
      v_noise NUMBER := DBMS_RANDOM.VALUE(-0.005, 0.005);
    BEGIN
      INSERT INTO fx_rates (rate_date, from_currency, to_currency, rate) VALUES (v_date, 'CHF', 'USD', ROUND(1.1340 + v_noise, 6));
      INSERT INTO fx_rates (rate_date, from_currency, to_currency, rate) VALUES (v_date, 'EUR', 'USD', ROUND(1.0850 + v_noise, 6));
      INSERT INTO fx_rates (rate_date, from_currency, to_currency, rate) VALUES (v_date, 'GBP', 'USD', ROUND(1.2720 + v_noise, 6));
      INSERT INTO fx_rates (rate_date, from_currency, to_currency, rate) VALUES (v_date, 'USD', 'USD', 1.000000);
    END;
  END LOOP;
  COMMIT;
END;
/

-- ============================================================
-- BENCHMARK VALUES — 90 rolling days
-- ============================================================
BEGIN
  FOR d IN 0..89 LOOP
    DECLARE
      v_date  DATE   := TRUNC(SYSDATE) - d;
      v_noise NUMBER := DBMS_RANDOM.VALUE(-0.01, 0.01);
    BEGIN
      INSERT INTO benchmark_values (benchmark_code, value_date, index_value) VALUES ('MSCI_WORLD', v_date, ROUND(3450.00  * (1 + v_noise),        2));
      INSERT INTO benchmark_values (benchmark_code, value_date, index_value) VALUES ('NASDAQ100',  v_date, ROUND(18200.00 * (1 + v_noise * 1.5),   2));
      INSERT INTO benchmark_values (benchmark_code, value_date, index_value) VALUES ('SPI',        v_date, ROUND(15800.00 * (1 + v_noise * 0.8),   2));
      INSERT INTO benchmark_values (benchmark_code, value_date, index_value) VALUES ('EURO_AGG',   v_date, ROUND(220.50   * (1 + v_noise * 0.3),   2));
      INSERT INTO benchmark_values (benchmark_code, value_date, index_value) VALUES ('SARON',      v_date, ROUND(100.80   * (1 + v_noise * 0.05),  4));
    END;
  END LOOP;
  COMMIT;
END;
/

-- ============================================================
-- REPORT RUNS — sample completed runs for yesterday
-- ============================================================
INSERT INTO report_runs (run_date, client_id, fund_id, status, started_at, completed_at, file_path)
  SELECT
    TRUNC(SYSDATE) - 1,
    c.client_id,
    f.fund_id,
    'COMPLETED',
    SYSTIMESTAMP - INTERVAL '2' HOUR,
    SYSTIMESTAMP - INTERVAL '1' HOUR,
    'reports/' || TO_CHAR(SYSDATE - 1, 'YYYY-MM-DD')
      || '/client-' || c.client_id
      || '/fund-'   || f.fund_code || '.pdf'
  FROM client_fund_subscriptions cfs
  JOIN clients c ON c.client_id = cfs.client_id
  JOIN funds   f ON f.fund_id   = cfs.fund_id
  WHERE cfs.is_active = 1;
COMMIT;

-- ============================================================
-- VIEW: v_daily_nav
-- Mirrors the NAV computation query described in the system design.
-- quantity × close_price × fx_rate = NAV in USD per holding line.
-- ============================================================
CREATE OR REPLACE VIEW v_daily_nav AS
SELECT
    f.fund_code,
    f.fund_name,
    p.position_date,
    i.ticker,
    i.instrument_name,
    i.asset_class,
    p.quantity,
    pr.close_price,
    pr.currency                                              AS price_currency,
    NVL(fx.rate, 1)                                         AS fx_to_usd,
    ROUND(p.quantity * pr.close_price * NVL(fx.rate, 1), 2) AS nav_usd
FROM  positions   p
JOIN  funds       f  ON f.fund_id        = p.fund_id
JOIN  instruments i  ON i.instrument_id  = p.instrument_id
JOIN  prices      pr ON pr.instrument_id = p.instrument_id
                    AND pr.price_date    = p.position_date
LEFT JOIN fx_rates fx ON fx.from_currency = pr.currency
                     AND fx.to_currency   = 'USD'
                     AND fx.rate_date     = p.position_date;

-- ============================================================
-- VERIFY — row counts
-- ============================================================
SELECT 'clients'               AS entity, COUNT(*) AS row_count FROM clients               UNION ALL
SELECT 'funds',                            COUNT(*)          FROM funds                UNION ALL
SELECT 'client_fund_subscriptions',        COUNT(*)          FROM client_fund_subscriptions UNION ALL
SELECT 'instruments',                      COUNT(*)          FROM instruments          UNION ALL
SELECT 'positions',                        COUNT(*)          FROM positions            UNION ALL
SELECT 'prices',                           COUNT(*)          FROM prices               UNION ALL
SELECT 'fx_rates',                         COUNT(*)          FROM fx_rates             UNION ALL
SELECT 'benchmark_values',                 COUNT(*)          FROM benchmark_values     UNION ALL
SELECT 'report_runs',                      COUNT(*)          FROM report_runs;
/

EXIT 0;