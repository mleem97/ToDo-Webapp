import { addLink } from "./links.js";

export function initializeSettings() {
  // Einstellungs-Button
  const settingsBtn = document.getElementById("settingsBtn");
  // Schließen-Button im Einstellungs-Modal
  const closeBtn = document.getElementById("closeSettingsBtn");
  // Einstellungs-Modal
  const modal = document.getElementById("settings-modal");
  // Button zum Hinzuf gen eines Links
  const addLinkBtn = document.getElementById("addLinkBtn");

  // Modal  öffnen, wenn Einstellungs-Button geklickt wird
  settingsBtn.addEventListener("click", () => {
    modal.style.display = "block";
  });

  // Modal schließen, wenn Schließen-Button geklickt wird
  closeBtn.addEventListener("click", () => {
    modal.style.display = "none";
  });

  // Modal schließen, wenn außerhalb des Modals geklickt wird
  window.addEventListener("click", (e) => {
    if (e.target === modal) {
      modal.style.display = "none";
    }
  });

  // Link hinzuf gen, wenn Button geklickt wird
  addLinkBtn.addEventListener("click", () => {
    // Eingabefelder f r Name und URL
    const nameInput = document.getElementById("linkName");
    const urlInput = document.getElementById("linkUrl");

    // Wenn Name und URL gesetzt sind, Link hinzufügen
    if (nameInput.value && urlInput.value) {
      if (addLink(nameInput.value, urlInput.value)) {
        // Eingabefelder leeren
        nameInput.value = "";
        urlInput.value = "";
      }
    }
  });
}
