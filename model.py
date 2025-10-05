import pandas as pd
import sys

# ==============================================================================
## 1. Configuration
# ==============================================================================
# The path to your original, large Kaggle CSV file
INPUT_CSV_PATH = r'C:\Users\jithu\Downloads\archive (1)\india_2000_2024_daily_weather.csv'

# The name of the efficient, pre-processed file we will create
OUTPUT_FEATHER_PATH = 'india_weather_database.feather'

# ==============================================================================
## 2. Load, Process, and Save Data
# ==============================================================================
print(f"Loading the large CSV file from: {INPUT_CSV_PATH}")
print("This may take a moment...")
try:
    # Load the dataset, ensuring the 'date' column is parsed correctly
    df = pd.read_csv(INPUT_CSV_PATH, parse_dates=['date'])
except FileNotFoundError:
    print(f"FATAL ERROR: The file was not found at {INPUT_CSV_PATH}")
    sys.exit()

# Optional: Drop columns you know you won't use to save space
# For example, let's keep the most important ones
columns_to_keep = [
    'city', 'date', 'temperature_2m_max', 'temperature_2m_min',
    'precipitation_sum', 'rain_sum', 'wind_speed_10m_max'
]
df = df[columns_to_keep]

# Reset the index before saving to Feather format
df.reset_index(drop=True, inplace=True)

# Save the cleaned DataFrame to the fast Feather format
print(f"\nSaving processed data to: {OUTPUT_FEATHER_PATH}")
df.to_feather(OUTPUT_FEATHER_PATH)

print("\nData preparation complete!")
print(f"The 'training' is done. You can now use '{OUTPUT_FEATHER_PATH}' in your prediction script.")