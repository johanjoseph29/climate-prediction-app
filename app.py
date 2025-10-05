from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import sys
import google.generativeai as genai

# --- Configuration ---
DATABASE_PATH = 'india_weather_database.feather'
API_KEY = "AIzaSyAnvUs9oZAdM5IxclSiO3LQSwhsk6_LBRs"  # Paste your Google Gemini API key here

# --- Initialize App and AI ---
app = Flask(__name__)
CORS(app)  # Enables requests from your Flutter app

try:
    if not API_KEY or API_KEY == "YOUR_API_KEY_HERE":
        print("API Key Error: Please paste your API key into the API_KEY variable.")
        sys.exit()
    genai.configure(api_key=API_KEY)
except Exception as e:
    print(f"API Configuration Error: {e}")
    sys.exit()

# --- Load Data ONCE at startup ---
try:
    print("Loading weather database...")
    df = pd.read_feather(DATABASE_PATH)
    df['date'] = pd.to_datetime(df['date'])
    print("Database loaded successfully.")
except FileNotFoundError:
    print(f"FATAL ERROR: The database file '{DATABASE_PATH}' was not found.")
    sys.exit()

# --- Core Functions ---
def get_historical_analysis(data, city_name, month, day):
    """Calculates historical climate statistics for a given city and day."""
    city_df = data[data['city'].str.title() == city_name.title()]
    if city_df.empty:
        return {"error": f"City '{city_name}' not found."}

    historical_data = city_df[
        (city_df['date'].dt.month == month) &
        (city_df['date'].dt.day == day)
    ]
    
    if historical_data.empty:
        return {"error": f"No historical data found for that date in {city_name}."}

    total_years = len(historical_data)
    avg_temp_max = historical_data['temperature_2m_max'].mean()
    avg_temp_min = historical_data['temperature_2m_min'].mean()
    record_high = historical_data['temperature_2m_max'].max()
    record_low = historical_data['temperature_2m_min'].min()
    days_with_rain = historical_data[historical_data['rain_sum'] > 0.1].shape[0]
    prob_rain = (days_with_rain / total_years) * 100

    return {
        "city": city_name.title(),
        "date_analyzed": pd.to_datetime(f"2000-{month}-{day}").strftime('%B %d'),
        "based_on_years_of_data": total_years,
        "average_max_temp": f"{avg_temp_max:.1f}°C",
        "average_min_temp": f"{avg_temp_min:.1f}°C",
        "historical_record_high": f"{record_high:.1f}°C",
        "historical_record_low": f"{record_low:.1f}°C",
        "chance_of_rain": f"{prob_rain:.0f}%"
    }

def generate_ai_summary(stats_dict):
    """Generates a conversational summary from the climate stats using the Gemini API."""
    model = genai.GenerativeModel("gemini-2.5-flash")
    prompt = f"""
    You are a friendly weather forecaster. Based on historical data for {stats_dict['city']} on {stats_dict['date_analyzed']}, 
    generate a conversational, easy-to-read summary for a local in Kozhikode.
    Historical Data:
    - Average High Temp: {stats_dict['average_max_temp']}
    - Average Low Temp: {stats_dict['average_min_temp']}
    - Chance of Rain: {stats_dict['chance_of_rain']}
    - Data based on {stats_dict['based_on_years_of_data']} years of records.
    Generate the summary now.
    """
    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return f"Could not generate AI summary. Error: {e}"

def get_chart_data(data, city_name, central_date):
    """Prepares data for the historical trend chart."""
    city_df = data[data['city'].str.title() == city_name.title()]
    if city_df.empty: return {"error": f"City '{city_name}' not found."}

    target_week = central_date.isocalendar().week
    weekly_data = city_df[city_df['date'].dt.isocalendar().week == target_week]
    
    if weekly_data.empty: return {"error": "Not enough historical data to generate a trend chart."}
        
    yearly_avg_temps = weekly_data.groupby(weekly_data['date'].dt.year)['temperature_2m_max'].mean().round(1)
    
    chart_points = [{"year": year, "avg_temp": temp} for year, temp in yearly_avg_temps.items()]
    return chart_points[-20:] # Return the last 20 years of data

# --- API Endpoints ---
@app.route('/predict', methods=['POST'])
def predict():
    """Endpoint for the main prediction and AI summary."""
    data = request.get_json()
    if not data or 'city' not in data or 'date' not in data:
        return jsonify({"error": "Invalid input. 'city' and 'date' are required."}), 400

    try:
        user_city = data['city']
        user_date = pd.to_datetime(data['date'])
        
        analysis_results = get_historical_analysis(df, user_city, user_date.month, user_date.day)
        if "error" in analysis_results: return jsonify(analysis_results), 404
            
        ai_summary = generate_ai_summary(analysis_results)
        
        final_response = {"statistics": analysis_results, "summary": ai_summary}
        return jsonify(final_response)
    except Exception as e:
        return jsonify({"error": f"An unexpected server error occurred: {e}"}), 500

@app.route('/historical-chart', methods=['POST'])
def historical_chart():
    """Endpoint for the historical temperature trend chart data."""
    data = request.get_json()
    if not data or 'city' not in data or 'date' not in data:
        return jsonify({"error": "Invalid input. 'city' and 'date' are required."}), 400

    try:
        user_city = data['city']
        user_date = pd.to_datetime(data['date'])
        chart_data = get_chart_data(df, user_city, user_date)
        
        if "error" in chart_data: return jsonify(chart_data), 404
        return jsonify(chart_data)
    except Exception as e:
        return jsonify({"error": f"An unexpected server error occurred: {e}"}), 500

# --- Run the App ---
if __name__ == '__main__':
    # use_reloader=False helps prevent common errors on Windows.
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False)