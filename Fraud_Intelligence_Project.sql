-- FINTECH FRAUD INTELLIGENCE PLATFORM 

-- PART 1: DATABASE DESIGN & SCHEMA

-- 1. LOCATIONS TABLE
CREATE TABLE locations (
    location_id VARCHAR(50) PRIMARY KEY,
    country VARCHAR(100),
    region_state VARCHAR(100),
    city VARCHAR(100),
    zip_code VARCHAR(20),
    risk_score DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. DEVICES TABLE
CREATE TABLE devices (
    device_id VARCHAR(50) PRIMARY KEY,
    device_type VARCHAR(50), 
    os_name VARCHAR(50), 
    browser VARCHAR(50),
    ip_address VARCHAR(45),
    is_vpn_proxy BOOLEAN, 
    location_id VARCHAR(50) REFERENCES locations(location_id),
    first_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. CUSTOMERS TABLE
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    phone_number VARCHAR(20),
    account_status VARCHAR(20), 
    kyc_verified BOOLEAN,
    account_created_at TIMESTAMP,
    primary_location_id VARCHAR(50) REFERENCES locations(location_id)
);

-- 4. MERCHANTS TABLE
CREATE TABLE merchants (
    merchant_id VARCHAR(50) PRIMARY KEY,
    merchant_name VARCHAR(255),
    mcc_code VARCHAR(4), 
    mcc_description VARCHAR(100),
    business_type VARCHAR(50), 
    risk_tier VARCHAR(20), 
    onboarding_date DATE,
    primary_location_id VARCHAR(50) REFERENCES locations(location_id)
);

-- 5. TRANSACTIONS TABLE
CREATE TABLE transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES customers(customer_id),
    merchant_id VARCHAR(50) REFERENCES merchants(merchant_id),
    device_id VARCHAR(50) REFERENCES devices(device_id),
    amount DECIMAL(15,2),
    currency VARCHAR(3),
    transaction_timestamp TIMESTAMP,
    status VARCHAR(20), 
    payment_method VARCHAR(50), 
    card_network VARCHAR(20), 
    cvv_match BOOLEAN,
    avs_match BOOLEAN 
);

-- 6. CHARGEBACKS TABLE
CREATE TABLE chargebacks (
    chargeback_id VARCHAR(50) PRIMARY KEY,
    transaction_id VARCHAR(50) REFERENCES transactions(transaction_id),
    chargeback_date TIMESTAMP,
    reason_code VARCHAR(10), 
    chargeback_amount DECIMAL(15,2),
    status VARCHAR(20) 
);

-- 7. FRAUD_ALERTS TABLE
CREATE TABLE fraud_alerts (
    alert_id VARCHAR(50) PRIMARY KEY,
    transaction_id VARCHAR(50) REFERENCES transactions(transaction_id),
    alert_timestamp TIMESTAMP,
    rule_triggered VARCHAR(100), 
    risk_score INT, 
    reviewer_status VARCHAR(20), 
    resolution VARCHAR(50) 
);

-- INDEXING STRATEGY (For Performance)
CREATE INDEX idx_txn_customer_time ON transactions(customer_id, transaction_timestamp);
CREATE INDEX idx_txn_merchant ON transactions(merchant_id);
CREATE INDEX idx_device_ip ON devices(ip_address);
CREATE INDEX idx_chargeback_txn ON chargebacks(transaction_id);
CREATE INDEX idx_alerts_status ON fraud_alerts(reviewer_status);


-- PART 2: BASIC & INTERMEDIATE ANALYTICS

-- Daily transaction volume and value summary
SELECT 
    COUNT(transaction_id) as total_transactions,
    SUM(amount) as total_volume_processed
FROM transactions
WHERE DATE(transaction_timestamp) = CURRENT_DATE
  AND status = 'Approved';

-- Top 5 revenue-generating merchant categories
SELECT 
    m.mcc_description,
    COUNT(t.transaction_id) as tx_count,
    SUM(t.amount) as total_amount
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE t.status = 'Approved'
GROUP BY m.mcc_description
ORDER BY total_amount DESC
LIMIT 5;

-- Overall transaction approval rates
SELECT 
    status,
    COUNT(*) as tx_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transactions), 2) as percentage
FROM transactions
GROUP BY status;

-- Identify merchants with highest declined counts (potential card testing)
SELECT 
    m.merchant_name,
    COUNT(t.transaction_id) as declined_count
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE t.status = 'Declined'
GROUP BY m.merchant_name
ORDER BY declined_count DESC
LIMIT 10;

-- Approval rate for transactions via VPN/Proxy
SELECT 
    d.is_vpn_proxy,
    COUNT(t.transaction_id) as total_tx,
    SUM(CASE WHEN t.status = 'Approved' THEN 1 ELSE 0 END) as approved_tx,
    ROUND(SUM(CASE WHEN t.status = 'Approved' THEN 1 ELSE 0 END) * 100.0 / COUNT(t.transaction_id), 2) as approval_rate
FROM transactions t
JOIN devices d ON t.device_id = d.device_id
GROUP BY d.is_vpn_proxy;

-- Unverified users with high transaction volume (>10k)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    SUM(t.amount) as lifetime_spend
FROM customers c
JOIN transactions t ON c.customer_id = t.customer_id
WHERE c.kyc_verified = FALSE 
  AND t.status = 'Approved'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(t.amount) > 10000;

-- Monthly chargeback financial loss
SELECT 
    DATE_TRUNC('month', chargeback_date) as month,
    COUNT(chargeback_id) as total_chargebacks,
    SUM(chargeback_amount) as total_loss
FROM chargebacks
WHERE status = 'Lost'
GROUP BY DATE_TRUNC('month', chargeback_date);

-- Chargebacks grouped by reason code
SELECT 
    reason_code,
    COUNT(*) as incident_count,
    SUM(chargeback_amount) as total_amount
FROM chargebacks
GROUP BY reason_code
ORDER BY total_amount DESC;

-- Top 10 merchants by chargeback ratio
SELECT 
    m.merchant_name,
    COUNT(t.transaction_id) as total_transactions,
    COUNT(c.chargeback_id) as total_chargebacks,
    ROUND(COUNT(c.chargeback_id) * 100.0 / NULLIF(COUNT(t.transaction_id), 0), 2) as chargeback_ratio_pct
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
LEFT JOIN chargebacks c ON t.transaction_id = c.transaction_id
GROUP BY m.merchant_name
HAVING COUNT(t.transaction_id) > 100
ORDER BY chargeback_ratio_pct DESC
LIMIT 10;

-- Rules engine True Positive Rate (TPR)
SELECT 
    rule_triggered,
    COUNT(*) as total_alerts,
    SUM(CASE WHEN resolution = 'True Positive (Fraud)' THEN 1 ELSE 0 END) as confirmed_fraud,
    ROUND(SUM(CASE WHEN resolution = 'True Positive (Fraud)' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as precision_pct
FROM fraud_alerts
WHERE reviewer_status = 'Closed'
GROUP BY rule_triggered
ORDER BY total_alerts DESC;

-- Customers blocked due to AVS mismatch
SELECT 
    c.customer_id,
    c.email,
    COUNT(t.transaction_id) as blocked_attempts
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
WHERE t.avs_match = FALSE AND t.status = 'Declined'
GROUP BY c.customer_id, c.email
ORDER BY blocked_attempts DESC
LIMIT 20;


-- PART 3: ADVANCED ANALYTICS & WINDOW FUNCTIONS

-- Get most recent transaction per customer (ROW_NUMBER)
WITH RankedTransactions AS (
    SELECT 
        customer_id,
        transaction_id,
        amount,
        status,
        transaction_timestamp,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY transaction_timestamp DESC) as recent_rank
    FROM transactions
)
SELECT 
    customer_id,
    transaction_id,
    amount,
    status,
    transaction_timestamp
FROM RankedTransactions
WHERE recent_rank = 1;

-- Top 3 highest transactions per merchant (DENSE_RANK)
WITH MerchantTopTxns AS (
    SELECT 
        merchant_id,
        transaction_id,
        customer_id,
        amount,
        DENSE_RANK() OVER (PARTITION BY merchant_id ORDER BY amount DESC) as amount_rank
    FROM transactions
    WHERE status = 'Approved'
)
SELECT 
    m.merchant_name,
    t.transaction_id,
    t.customer_id,
    t.amount,
    t.amount_rank
FROM MerchantTopTxns t
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE amount_rank <= 3;

-- Cumulative running total of monthly chargeback losses (SUM OVER)
WITH MonthlyLosses AS (
    SELECT 
        DATE_TRUNC('month', chargeback_date) as loss_month,
        SUM(chargeback_amount) as monthly_loss
    FROM chargebacks
    WHERE status = 'Lost'
    GROUP BY DATE_TRUNC('month', chargeback_date)
)
SELECT 
    loss_month,
    monthly_loss,
    SUM(monthly_loss) OVER (ORDER BY loss_month ASC) as cumulative_running_loss
FROM MonthlyLosses
ORDER BY loss_month ASC;

-- Detect sudden spending spikes by comparing current vs previous txn (LAG)
WITH TxnHistory AS (
    SELECT 
        customer_id,
        transaction_id,
        amount as current_amount,
        LAG(amount, 1) OVER (PARTITION BY customer_id ORDER BY transaction_timestamp ASC) as previous_amount,
        transaction_timestamp
    FROM transactions
    WHERE status = 'Approved'
)
SELECT 
    customer_id,
    transaction_id,
    previous_amount,
    current_amount,
    transaction_timestamp
FROM TxnHistory
WHERE current_amount > (previous_amount * 2) 
  AND previous_amount IS NOT NULL;

-- Categorize merchants by risk tiers based on total chargebacks
WITH MerchantChargebacks AS (
    SELECT 
        t.merchant_id,
        COUNT(c.chargeback_id) as total_chargebacks,
        SUM(c.chargeback_amount) as total_chargeback_amount
    FROM transactions t
    JOIN chargebacks c ON t.transaction_id = c.transaction_id
    GROUP BY t.merchant_id
)
SELECT 
    m.merchant_name,
    mc.total_chargebacks,
    mc.total_chargeback_amount,
    CASE 
        WHEN mc.total_chargebacks >= 50 THEN 'High Risk - Suspend'
        WHEN mc.total_chargebacks BETWEEN 20 AND 49 THEN 'Medium Risk - Review'
        ELSE 'Low Risk - Safe'
    END as risk_category
FROM MerchantChargebacks mc
JOIN merchants m ON mc.merchant_id = m.merchant_id
ORDER BY mc.total_chargebacks DESC;
