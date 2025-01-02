// Kalender Einstellungen
// -----------------------
// Speichert die Kalender URL im LocalStorage und die Events im RAM.
// Die Events werden aktualisiert, wenn die URL gespeichert wird.
// Die Events werden als CustomEvent dispatcht, wenn sie aktualisiert werden.
// Die getEvents()- und getCalendarUrl()-Funktionen liefern die Events und die URL.
// Die saveCalendarUrl()-Funktion speichert die URL und aktualisiert die Events.
// Die updateCalendarEvents()-Funktion aktualisiert die Events, wenn die URL ge ndert wird.

import {
  parseGoogleCalendarUrl,
  fetchCalendarEvents,
} from "./googleCalendar.js";

export function initializeCalendarSettings() {
  const calendarSettings = {
    calendarUrl: localStorage.getItem("dashboard_calendar_url") || "",
    events: [],
  };

  async function updateCalendarEvents() {
    const calendarId = parseGoogleCalendarUrl(calendarSettings.calendarUrl);
    if (calendarId) {
      const events = await fetchCalendarEvents(calendarId);
      calendarSettings.events = events;
      window.dispatchEvent(
        new CustomEvent("calendarUpdated", { detail: events })
      );
    }
  }

  function saveCalendarUrl(url) {
    calendarSettings.calendarUrl = url;
    localStorage.setItem("dashboard_calendar_url", url);
    updateCalendarEvents();
  }

  return {
    getEvents: () => calendarSettings.events,
    getCalendarUrl: () => calendarSettings.calendarUrl,
    saveCalendarUrl,
    updateCalendarEvents,
  };
}
