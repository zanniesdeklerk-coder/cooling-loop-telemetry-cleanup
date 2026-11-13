# Cooling Loop Telemetry Cleanup

## Overview
Raw sensor exports from industrial cooling loops rarely arrive ready for analysis. Automated logging glitches often leave behind duplicate timestamps, inconsistent station labels, and calibration error codes mixed into live metrics. 

I built this R pipeline using `tidyverse` to clean, validate, and summarize raw telemetry logs from three cooling loop monitoring stations before thermal efficiency modeling.

## Data Issues Fixed
The raw dataset (`raw_telemetry`) contained several logging errors that needed to be resolved before aggregation:
* **Inconsistent Identifiers:** Station names had leading/trailing whitespace and mixed casing (e.g., `" stn-alpha "` vs `"STN-ALPHA"`).
* **Duplicate Logs:** Export glitches created exact duplicate rows for certain timestamps.
* **Mixed Data Types:** Temperature readings were stored as character strings with `" C"` suffixes attached.
* **Calibration Error Codes:** Sensor resets recorded flow rates as `-999.0` instead of null values.
* **Missing Status Labels:** Unlogged status codes appeared as `NA`.

## Transformation Pipeline
The cleanup script (`scripts/01_clean_telemetry.R`) handles the data in four steps:
1. **Standardization:** Trims whitespace, converts `station_id` to uppercase, and parses `reading_time` into `POSIXct` datetime format.
2. **Deduplication:** Removes exact duplicate rows after standardizing text fields so hidden duplicates are caught.
3. **Type Conversion & Imputation:** Strips unit suffixes to convert temperatures to numeric values, replaces `-999.0` flow rates with `NA`, and fills missing status codes with `"UNKNOWN"`.
4. **Anomaly Flagging & Aggregation:** Flags records where temperature exceeds `85°C` or flow rate drops out (`NA`), then summarizes station performance.

## Results Summary
After cleaning, 10 unique sensor readings remained across the three stations:

| Station ID | Total Clean Readings | Avg Temp (°C) | Anomaly Count |
| :--- | :---: | :---: | :---: |
| **STN-ALPHA** | 4 | 76.98 | 1 |
| **STN-BETA** | 3 | 82.90 | 3 |
| **STN-GAMMA** | 3 | 76.43 | 1 |

**Key Takeaway:** `STN-BETA` logged anomalies on 100% of its readings due to repeated flow sensor dropouts (`-999.0`) and a thermal spike (`88.5°C`), flagging it for immediate maintenance inspection.

## Repository Structure
```text
├── data/
│   └── raw_telemetry.csv        # Raw exported sensor logs
├── scripts/
│   └── 01_clean_telemetry.R     # Tidyverse cleaning and audit script
├── output/
│   ├── clean_telemetry.csv      # Validated dataset ready for modeling
│   └── station_summary.csv      # Aggregated station audit table
└── README.md
```

## How to Run
1. Clone this repository to your local machine.
2. Open `scripts/01_clean_telemetry.R` in RStudio.
3. Ensure `tidyverse` is installed (`install.packages("tidyverse")`) and run the script.

