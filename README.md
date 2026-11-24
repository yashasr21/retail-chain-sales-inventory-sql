# Retail Chain Sales & Inventory Analysis (SQL + Python)

Sales, profit and stock analysis for a chain of 50 toy stores, using **SQL** on 4 related tables and **Python (pandas, Matplotlib)** for cleaning, loading and charts.

## Business questions
1. How are sales and profit growing?
2. Which categories and products actually make the profit?
3. Which store types and stores perform best and worst?
4. How much money is tied up in stock, and where are we losing sales to stock-outs?

## Data
Maven Toys sales and inventory data (Maven Analytics free data playground, public domain). Jan 2022 to Sep 2023. Prices are in dollars.

| Table | Rows | What it holds |
|---|---|---|
| sales | 829,262 | one row per sale: date, store, product, units |
| products | 35 | category, cost and price |
| stores | 50 | city, location type (Airport, Downtown, Commercial, Residential) |
| inventory | 1,593 | stock on hand for each store and product (snapshot) |

## What I did
1. **Python:** loaded the 4 CSV files, converted prices stored as text (`$15.99 `) into numbers, checked for missing values, duplicate IDs and sales pointing to unknown products or stores, then loaded the tables into a SQL database.
2. **SQL (11 queries, see `queries.sql`):** multi-table JOINs, CTEs, a self-join for year-on-year comparison, subqueries, window functions (ROW_NUMBER, RANK, LAG), CASE and a LEFT JOIN for stock analysis.
3. **Python:** charts with Matplotlib.

## Key results
| | |
|---|---|
| Revenue / gross profit | $14.44M / $4.01M (27.8% margin) |
| Growth | Jan–Sep 2023 revenue up 31% vs Jan–Sep 2022; every month grew |
| Category | Electronics: 15.6% of revenue but 24.9% of profit (44.6% margin) |
| Product risk | One product (Colorbuds) earns 20.8% of all profit |
| Store type | Airport stores: $126K profit per store vs about $77K for other types (+63%) |
| Stock | $300K tied up at cost; 293 store-product lines under 1 week of cover; 77 out of stock |
| Lost sales | Stock-outs of selling items cost about $957 revenue per day (about $29K per month) |

![Monthly revenue](images/monthly_revenue.png)
![Category share](images/category_share.png)
![Stock status](images/stock_status.png)

## Recommendations
1. Restock out-of-stock items first, starting with Dino Egg, Playfoam and Mini Ping Pong Set.
2. Add a reorder alert when days of cover drops below 7.
3. Protect Colorbuds supply (second supplier or safety stock) and push other high-margin Electronics.
4. Prefer airport locations for new stores.
5. Clear stock that has not sold in 3 months (transfer or discount).

## Limitations
- Inventory is one snapshot, so days of cover assumes the last 3 months' sales rate continues.
- No rent or staff cost data, so profit here is gross profit (price minus product cost).

## Files
- `sales_inventory_analysis.ipynb`: full analysis with outputs
- `queries.sql`: all SQL queries
- `data/`: the 4 tables (`sales.csv.gz` is compressed; pandas reads it directly)
- `images/`: charts

## How to run
```
pip install pandas matplotlib jupyter
jupyter notebook sales_inventory_analysis.ipynb
```
