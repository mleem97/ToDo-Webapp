// Klasse, die die gesamte Funktionalität der Todo-Liste verwaltet
class TodoList {
  constructor() {
    // HTML-Elemente werden referenziert
    this.todoInput = document.getElementById("new-todo"); // Eingabefeld für neue Aufgaben
    this.addButton = document.getElementById("add-btn"); // Button zum Hinzufügen neuer Aufgaben
    this.todoList = document.getElementById("todo-list"); // Liste für die Anzeige der Aufgaben
    // Lädt gespeicherte Aufgaben aus dem lokalen Speicher oder erstellt ein leeres Array
    this.todos = JSON.parse(localStorage.getItem("todos")) || [];
  }

  // Rendert die Aufgaben-Liste im HTML
  renderTodos() {
    // Generiert die Liste der Aufgaben und fügt sie ins DOM ein
    this.todoList.innerHTML = this.todos
      .map(
        ({ id, text, isNew }) => `
        <li>
          <span style="${isNew ? "color:red;" : ""}">${text}</span>
          <button class="mdi mdi-delete" data-id="${id}"></button>
        </li>
      `
      )
      .join("");

    // Fügt Event-Listener für die Löschen-Buttons hinzu
    this.todoList
      .querySelectorAll(".mdi-delete")
      .forEach((btn) =>
        btn.addEventListener("click", () => this.removeTodo(btn.dataset.id))
      );
  }

  // Speichert die aktuelle Liste der Aufgaben im lokalen Speicher
  saveTodos() {
    localStorage.setItem("todos", JSON.stringify(this.todos));
  }

  // Fügt eine neue Aufgabe hinzu
  addTodo() {
    const text = this.todoInput.value.trim(); // Entfernt unnötige Leerzeichen
    if (!text) return; // Verhindert das Hinzufügen leerer Aufgaben

    // Erstellt eine neue Aufgabe und fügt sie zum Array hinzu
    this.todos.push({ id: Date.now(), text, isNew: true });
    this.saveTodos(); // Speichert die Änderungen
    this.renderTodos(); // Aktualisiert die Anzeige
    this.todoInput.value = ""; // Leert das Eingabefeld
  }

  // Entfernt eine Aufgabe basierend auf ihrer ID
  removeTodo(id) {
    // Filtert die Liste, um die ausgewählte Aufgabe zu entfernen
    this.todos = this.todos.filter((todo) => todo.id !== parseInt(id));
    this.saveTodos(); // Speichert die Änderungen
    this.renderTodos(); // Aktualisiert die Anzeige
  }

  // Initialisiert die Event-Listener und rendert die bestehende Liste
  init() {
    // Hinzufügen-Button: Fügt neue Aufgabe hinzu
    this.addButton.addEventListener("click", () => this.addTodo());
    // "Enter"-Taste im Eingabefeld: Fügt neue Aufgabe hinzu
    this.todoInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") this.addTodo();
    });
    // Aktualisiert die Liste, wenn sich der lokale Speicher ändert
    window.addEventListener("storage", () => {
      this.todos = JSON.parse(localStorage.getItem("todos")) || [];
      this.renderTodos();
    });

    this.renderTodos(); // Rendert die Aufgaben beim Start
  }
}

// Startet die App, wenn das Dokument geladen wurde
document.addEventListener("DOMContentLoaded", () => new TodoList().init());
