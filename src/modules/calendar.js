import { initializeCalendarSettings } from "./calendarSettings.js";

let calendarSettings;

export function initializeCalendar() {
  // Initialisiert die Kalender-Einstellungen und holt die Liste der Events.
  calendarSettings = initializeCalendarSettings();
  updateCalendar();
  setupCalendarListeners();

  // Aktualisiert die Kalender-Events, wenn eine URL vorhanden ist
  if (calendarSettings.getCalendarUrl()) {
    calendarSettings.updateCalendarEvents();
  }
}

function setupCalendarListeners() {
  window.addEventListener("calendarUpdated", (e) => {
    renderEvents(e.detail);
  });
}

function updateCalendar() {
  const calendar = document.getElementById("calendar");
  const now = new Date();

  const options = {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  };

  calendar.innerHTML = `
    <h3>${now.toLocaleDateString(undefined, options)}</h3>
    <div class="time">${now.toLocaleTimeString()}</div>
    <div class="calendar-events"></div>
  `;

  // Aktualisiert die Uhrzeit alle Sekunde
  setInterval(() => {
    const time = new Date();
    calendar.querySelector(".time").textContent = time.toLocaleTimeString();
  }, 1000);
}

function renderEvents(events) {
  const eventsContainer = document.querySelector(".calendar-events");
  if (!events || events.length === 0) {
    eventsContainer.innerHTML = "<p>Keine anstehenden Ereignisse</p>";
    return;
  }

  const eventsList = events
    .slice(0, 5) // Zeige nur die nächsten 5 Ereignisse
    .map((event) => {
      const start = new Date(event.start.dateTime || event.start.date);
      return `
        <div class="calendar-event">
          <div class="event-time">${start.toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
          })}</div>
          <div class="event-title">${event.summary}</div>
        </div>
      `;
    })
    .join("");

  eventsContainer.innerHTML = `
    <h4>Anstehend (Woche)</h4>
    ${eventsList}
  `;
}

export function setCalendarUrl(url) {
  calendarSettings.saveCalendarUrl(url);
}

// Macht die setCalendarUrl-Funktion global verfügbar
window.setCalendarUrl = setCalendarUrl;
