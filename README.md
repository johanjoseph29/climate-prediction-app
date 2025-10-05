# Climate Prediction App

A full-stack application built for the NASA Space Apps Challenge in Kochi. It provides historical climate analysis, trend visualization, and AI-powered summaries for any location selected on a map.

-  **Historical Data**: Displays key metrics like average high temperature and chance of rain.
-  **20-Year Trend Chart**: Visualizes the historical temperature trend for the selected week.
-  **AI Summary**: Uses the Google Gemini API to generate a conversational weather summary.
-  **Responsive UI**: The layout adapts for both mobile and web/desktop screens.

## Technologies Used

- **Frontend**: Flutter, Dart
- **Backend**: Python, Flask
- **AI**: Google Gemini API
- **Data**: Pandas, Haversine
- **Visualization**: `fl_chart`
  
## Setup and Installation

### 1. Backend (Python)

- Navigate to the `backend` folder.
- Install the required packages: `pip install -r requirements.txt`
- **IMPORTANT**: Open `app.py` and replace `"YOUR_API_KEY_HERE"` with your Google Gemini API key.
- Run the server: `python app.py`

### 2. Frontend (Flutter)

- Navigate to the `frontend` folder.
- Get the dependencies: `flutter pub get`
- **IMPORTANT**: Configure your Google Maps API key for Android, iOS, and Web.
- Open `lib/main.dart` and update the `yourPcIpAddress` constant to your computer's local IP address.
- Run the app: `flutter run`
