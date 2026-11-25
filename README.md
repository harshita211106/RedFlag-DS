# RedFlag — The Fraud Files

**Student:** Harshita Bhingare  
**Batch:** DA-DS-1  
**Database:** MySQL 8.0+

## Overview
RedFlag is a SQL-based investigation of a simulated payment transaction dataset. It contains queries for 12 suspicious transaction patterns, including transaction velocity, card testing, refund abuse, mule accounts, merchant collusion and geographic impossibility.

## Fraud patterns
1. Velocity fraud
2. Round-amount clustering
3. Card testing
4. Failed-then-succeeded transactions
5. Odd-hour concentration
6. Mule accounts
7. Refund abuse
8. Merchant collusion
9. Just-under-threshold structuring
10. Dormant-then-active accounts
11. Velocity spike
12. Geographic impossibility

## Technology
- MySQL 8.0+
- SQL aggregation, filtering, joins, subqueries, CTEs and window functions

## Files
- `RedFlag_Harshita.sql` — detection queries

## Dataset and execution
The project brief supplies a separate dataset named `redflag_transactions.sql`. Import it into a MySQL database named `redflag`, then execute `RedFlag_Harshita.sql`.

The dataset is not included in this repository.
