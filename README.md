# Fintech Fraud Analytics Data Warehouse

![Project Cover](cover.png)

## Project Overview
An end-to-end SQL Data Analytics project simulating a Fintech Risk Data Warehouse. This project is designed to monitor payment gateways, identify suspicious transaction patterns, and score merchant risk to reduce chargeback exposure. It processes 50,000+ realistic simulated transactions using advanced SQL logic.

**Domain:** Fintech, Cyber Security, Risk Analytics  
**Tech Stack:** SQL (PostgreSQL/MySQL), Relational Database Design  

---

## Business Objectives
1. **Financial Loss Mitigation:** Identify and flag high-risk transactions before chargebacks occur.
2. **Merchant Risk Management:** Automatically categorize merchants into risk tiers based on historical fraud rates.
3. **Anomaly Detection:** Detect "Velocity Attacks" (rapid spending spikes) and Account Takeovers.

---

## Database Schema Design
The project features a highly normalized, production-inspired 7-table star schema optimized for analytical queries:
- **`transactions`**: Central fact table recording all payment attempts.
- **`customers`**: Profiles and KYC status.
- **`merchants`**: Businesses accepting payments and their risk tiers.
- **`devices`**: Device fingerprints and VPN/Proxy flags.
- **`locations`**: Geospatial data for anomaly tracking.
- **`chargebacks`**: Records of disputed transactions resulting in financial loss.
- **`fraud_alerts`**: System-generated warnings based on internal rules.

---

## Key SQL Skills Demonstrated
This project demonstrates Junior to Mid-level Data Analytics SQL capabilities:
* **Window Functions:** Extensively used `ROW_NUMBER()`, `DENSE_RANK()`, `SUM() OVER()`, and `LAG()` for comparative and ranking analysis.
* **CTEs (Common Table Expressions):** Used to break down complex risk scoring logic into readable, maintainable modules.
* **Data Aggregation:** `GROUP BY`, `HAVING`, and `DATE_TRUNC()` for monthly cumulative financial tracking.
* **Conditional Logic:** `CASE WHEN` to dynamically assign risk categories to merchants.

---

## Analytics Highlights
Some of the core business questions answered in this project include:
1. **Cumulative Loss Tracking:** Tracking the running total of monthly chargeback losses.
2. **Spending Spike Detection:** Comparing a customer's current transaction amount to their immediate previous transaction.
3. **High-Value Fraud Detection:** Extracting the top 3 highest transactions per merchant.
4. **Merchant Risk Tiering:** Automatically flagging merchants for "Review" or "Suspension" based on their total chargebacks.

---

## How to Run the Project
1. Clone this repository.
2. Ensure you have a SQL Database client installed (e.g., pgAdmin, DBeaver, or MySQL Workbench).
3. Import the 7 CSV files located in the `Datasets/` directory into your database.
4. Run the master script: `Fraud_Intelligence_Project.sql` to generate the schema and view the analytics outputs.
