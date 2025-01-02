export function initializeWeather() {
  // Überprüfen, ob Geolokalisierung verfügbar ist
  if ("geolocation" in navigator) {
    // Aktuelle Position abrufen
    navigator.geolocation.getCurrentPosition(async (position) => {
      const { latitude, longitude } = position.coords;
      try {
        // Wetterdaten von Open-Meteo-API abrufen
        const response = await fetch(
          `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current_weather=true`
        );
        const data = await response.json();
        displayWeather(data);
      } catch (error) {
        // Bei Fehler Wetterfehler anzeigen
        displayWeatherError();
      }
    }, displayWeatherError);
  } else {
    // Geolokalisierung nicht verfügbar, Wetterfehler anzeigen
    displayWeatherError();
  }
}

function displayWeather(data) {
  // Wetterinformationen im DOM aktualisieren
  const weatherInfo = document.getElementById("weather-info");
  const weather = data.current_weather;

  weatherInfo.innerHTML = `
    <h3>Aktuelles Wetter</h3>
    <p>Temperatur: ${weather.temperature}°C</p>
    <p>Windgeschwindigkeit: ${weather.windspeed} km/h</p>
  `;
}

function displayWeatherError() {
  // Fehlermeldung im DOM anzeigen
  const weatherInfo = document.getElementById("weather-info");
  weatherInfo.innerHTML = "<p>Wetterdaten konnten nicht abgerufen werden</p>";
}
