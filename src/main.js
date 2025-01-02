import "../style.css";
import { initializeLinks } from "./modules/links.js";
import { initializeTodo } from "./modules/todo.js";
import { initializeWeather } from "./modules/weather.js";
import { initializeCalendar } from "./modules/calendar.js";
import { initializeSettings } from "./modules/settings.js";

// Initialize all modules
document.addEventListener("DOMContentLoaded", () => {
  initializeLinks();
  initializeTodo();
  initializeWeather();
  initializeCalendar();
  initializeSettings();
});
