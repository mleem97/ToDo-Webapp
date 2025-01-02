// Google Calendar API utilities
export function parseGoogleCalendarUrl(url) {
  try {
    const calendarId = url.match(/\/calendars\/([^/]+)/)?.[1];
    if (!calendarId) throw new Error('Invalid Google Calendar URL');
    return decodeURIComponent(calendarId);
  } catch (error) {
    console.error('Error parsing calendar URL:', error);
    return null;
  }
}

export async function fetchCalendarEvents(calendarId) {
  try {
    // Using public calendar feed
    const baseUrl = 'https://www.googleapis.com/calendar/v3/calendars';
    const key = 'AIzaSyBNlYH01_9Hc5S1J9vuFmu2nUqBZJNAXxs'; // Public API key for demo
    const timeMin = new Date().toISOString();
    const timeMax = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(); // 7 days ahead

    const response = await fetch(
      `${baseUrl}/${encodeURIComponent(calendarId)}/events?` +
      `key=${key}&timeMin=${timeMin}&timeMax=${timeMax}&singleEvents=true&orderBy=startTime`
    );

    if (!response.ok) throw new Error('Failed to fetch calendar events');
    const data = await response.json();
    return data.items || [];
  } catch (error) {
    console.error('Error fetching calendar events:', error);
    return [];
  }
}