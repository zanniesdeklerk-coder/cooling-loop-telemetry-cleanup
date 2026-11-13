library(tidyverse)

raw_telemetry <- tibble(
  log_id = c(101, 102, 102, 103, 104, 105, 106, 107, 108, 109, 110, 110),
  station_id = c(" stn-alpha ", "STN-ALPHA", "STN-ALPHA", "stn-beta", "STN-BETA ", 
                 "stn-gamma", "STN-GAMMA", " stn-alpha", "stn-beta", "STN-GAMMA", 
                 "stn-alpha", "stn-alpha"),
  reading_time = c("2026-11-10 08:00:00", "2026-11-10 08:15:00", "2026-11-10 08:15:00",
                   "2026-11-10 08:00:00", "2026-11-10 08:15:00", "2026-11-10 08:00:00",
                   "2026-11-10 08:15:00", "2026-11-10 08:30:00", "2026-11-10 08:30:00",
                   "2026-11-10 08:30:00", "2026-11-10 08:45:00", "2026-11-10 08:45:00"),
  temp_reading = c("72.4 C", "74.1 C", "74.1 C", "88.5 C", "79.0", 
                   "68.2 C", "91.3 C", "75.0 C", "81.2 C", "69.8 C", 
                   "86.4 C", "86.4 C"),
  flow_rate_lpm = c(450.5, 448.0, 448.0, 410.2, -999.0, 
                    460.1, 395.4, 452.0, -999.0, 458.9, 
                    415.0, 415.0),
  status_code = c("OK", "OK", "OK", "WARN", NA, 
                  "OK", "CRIT", "OK", NA, "OK", 
                  "WARN", "WARN")
)
# Q4 Cooling Loop Telemetry Cleanup & Audit
# Author: Zandre De Klerk
# Description: Cleans raw station logs, removes export duplicates, and flags sensor anomalies.

library(tidyverse)

# 1. Load Raw Data --------------------------------------------------------
# (In production, replace this block with: raw_telemetry <- read_csv("data/raw_telemetry.csv"))
raw_telemetry <- tibble(
  log_id = c(101, 102, 102, 103, 104, 105, 106, 107, 108, 109, 110, 110),
  station_id = c(" stn-alpha ", "STN-ALPHA", "STN-ALPHA", "stn-beta", "STN-BETA ", 
                 "stn-gamma", "STN-GAMMA", " stn-alpha", "stn-beta", "STN-GAMMA", 
                 "stn-alpha", "stn-alpha"),
  reading_time = c("2026-11-10 08:00:00", "2026-11-10 08:15:00", "2026-11-10 08:15:00",
                   "2026-11-10 08:00:00", "2026-11-10 08:15:00", "2026-11-10 08:00:00",
                   "2026-11-10 08:15:00", "2026-11-10 08:30:00", "2026-11-10 08:30:00",
                   "2026-11-10 08:30:00", "2026-11-10 08:45:00", "2026-11-10 08:45:00"),
  temp_reading = c("72.4 C", "74.1 C", "74.1 C", "88.5 C", "79.0", 
                   "68.2 C", "91.3 C", "75.0 C", "81.2 C", "69.8 C", 
                   "86.4 C", "86.4 C"),
  flow_rate_lpm = c(450.5, 448.0, 448.0, 410.2, -999.0, 
                    460.1, 395.4, 452.0, -999.0, 458.9, 
                    415.0, 415.0),
  status_code = c("OK", "OK", "OK", "WARN", NA, 
                  "OK", "CRIT", "OK", NA, "OK", 
                  "WARN", "WARN")
)


# 2. Clean & Transform ----------------------------------------------------
clean_telemetry <- raw_telemetry |>
  # Standardize station IDs first so duplicate checks catch casing mismatches
  mutate(
    station_id = str_squish(station_id) |> str_to_upper(),
    reading_time = ymd_hms(reading_time)
  ) |>
  # Drop exact duplicate rows from the export glitch
  distinct() |>
  # Parse numeric values and handle sensor error codes
  mutate(
    temp_reading = str_remove(temp_reading, " C") |> as.numeric(),
    flow_rate_lpm = na_if(flow_rate_lpm, -999.0),
    status_code = replace_na(status_code, "UNKNOWN")
  ) |>
  # Flag thermal spikes (> 85C) or dropped flow readings
  mutate(
    is_anomaly = temp_reading > 85 | is.na(flow_rate_lpm)
  ) |>
  arrange(station_id, reading_time)


# 3. Station Audit Summary ------------------------------------------------
station_summary <- clean_telemetry |>
  group_by(station_id) |>
  summarise(
    total_readings = n(),
    avg_temp_c = round(mean(temp_reading, na.rm = TRUE), 2),
    anomaly_count = sum(is_anomaly, na.rm = TRUE),
    .groups = "drop"
  )


# 4. Inspect & Export -----------------------------------------------------
print(clean_telemetry)
print(station_summary)

# Uncomment below once your local folders are created:
# write_csv(raw_telemetry, "data/raw_telemetry.csv")
# write_csv(clean_telemetry, "output/clean_telemetry.csv")
# write_csv(station_summary, "output/station_summary.csv")

#Let us now do a ggplot of our DATA
# 4. Visualize Thermal Trends & Anomalies ---------------------------------
telemetry_plot <- ggplot(clean_telemetry, aes(x = reading_time, y = temp_reading, color = station_id)) +
  # Plot temperature trend lines per station
  geom_line(linewidth = 1, alpha = 0.8) +
  # Plot individual readings, using shape to highlight anomalies
  geom_point(aes(shape = is_anomaly), size = 3.5) +
  # Add horizontal threshold line for the 85°C thermal limit
  geom_hline(yintercept = 85, linetype = "dashed", color = "#D9534F", linewidth = 0.8) +
  annotate(
    "text",
    x = min(clean_telemetry$reading_time),
    y = 86.2,
    label = "Thermal Threshold (85°C)",
    color = "#D9534F",
    hjust = 0,
    size = 3.5,
    fontface = "bold"
  ) +
  scale_color_brewer(palette = "Dark2") +
  scale_shape_manual(
    values = c("FALSE" = 16, "TRUE" = 17),
    labels = c("Normal", "Anomaly (Temp > 85°C or Flow NA)")
  ) +
  labs(
    title = "Cooling Loop Temperature Trends & Anomaly Detection",
    subtitle = "Q4 Monitoring Audit across Vaal Triangle Stations (Nov 10, 2026)",
    x = "Reading Timestamp",
    y = "Temperature (°C)",
    color = "Station ID",
    shape = "Reading Status"
  ) +
  theme_classic() +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(color = "grey30", size = 10),
    axis.title = element_text(face = "bold"),
    legend.position = "right"
  )

# Display the plot in RStudio
print(telemetry_plot)

# Save high-resolution chart to your output folder
# ggsave("output/thermal_anomalies.png", plot = telemetry_plot, width = 9, height = 5, dpi = 300)

