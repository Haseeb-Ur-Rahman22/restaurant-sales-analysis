# Data

- `Restaurant_items.csv` — the full 32 item menu (small).
- `Restaurant_Orders_sample.csv` — a 1,000 row sample so you can see the shape of the data.

The full orders file is 1,000,000 rows (about 73 MB) and is not committed here to keep the repo light.
To recreate the full dataset exactly, run the generator:

    python scripts/gen.py

It writes the full `Restaurant_Orders.csv` and `Restaurant_items.csv` using a fixed seed, so the output is always the same.
