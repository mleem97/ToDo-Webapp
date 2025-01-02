// Maximale Anzahl von Links
const MAX_LINKS = 10;
// Liste mit Links, wird aus LocalStorage geladen
let links = JSON.parse(localStorage.getItem("dashboard_links") || "[]");

// Initialisiert die Links
export function initializeLinks() {
  renderLinks();
}

// F gt einen Link zur Liste hinzu
export function addLink(name, url) {
  if (links.length >= MAX_LINKS) {
    alert("Das sind zu viele! Maximal " + MAX_LINKS + " sind erlaubt.");
    return false;
  }

  links.push({ name, url });
  saveLinks();
  renderLinks();
  return true;
}

// Entfernt einen Link aus der Liste
export function removeLink(index) {
  links.splice(index, 1);
  saveLinks();
  renderLinks();
}

// Speichert die Links in LocalStorage
function saveLinks() {
  localStorage.setItem("dashboard_links", JSON.stringify(links));
}

// Rendert die Links in der Liste
function renderLinks() {
  const linksList = document.getElementById("links-list");
  const settingsList = document.getElementById("links-settings-list");

  linksList.innerHTML = links
    .map((link) => `<a href="${link.url}" target="_blank">${link.name}</a>`)
    .join("");

  settingsList.innerHTML = links
    .map(
      (link, index) =>
        `<div class="link-item">
      <span>${link.name}</span>
      <button onclick="window.removeLink(${index})">Entfernen</button>
    </div>`
    )
    .join("");
}

// Macht removeLink global verfügbar für die onclick-Handler
window.removeLink = removeLink;
