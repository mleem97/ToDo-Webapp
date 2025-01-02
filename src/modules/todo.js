// Die Liste aller Todos wird in LocalStorage gespeichert.
// Die Initialisierung der Todos wird nur einmal ausgefhrt.
// Sie wird in main.js aufgerufen.
let todos = JSON.parse(localStorage.getItem("dashboard_todos") || "[]");

export function initializeTodo() {
  const addBtn = document.getElementById("addTodoBtn");
  const input = document.getElementById("todoInput");

  addBtn.addEventListener("click", () => addTodo());
  input.addEventListener("keypress", (e) => {
    if (e.key === "Enter") addTodo();
  });

  renderTodos();
}

// Fgt ein neues Todo an die Liste an.
// Der Text wird aus dem Input-Feld gelesen.
// Der Input wird danach geleert.
function addTodo() {
  const input = document.getElementById("todoInput");
  const text = input.value.trim();

  if (text) {
    todos.push({ text, completed: false });
    saveTodos();
    renderTodos();
    input.value = "";
  }
}

// Setzt den Status eines Todos auf "erledigt" oder "nicht erledigt".
// Der Status wird in LocalStorage gespeichert.
function toggleTodo(index) {
  todos[index].completed = !todos[index].completed;
  saveTodos();
  renderTodos();
}

// Lscht ein Todo aus der Liste.
// Der Status wird in LocalStorage gespeichert.
function removeTodo(index) {
  todos.splice(index, 1);
  saveTodos();
  renderTodos();
}

// Speichert die Todos in LocalStorage.
function saveTodos() {
  localStorage.setItem("dashboard_todos", JSON.stringify(todos));
}

// Rendert die Todos in der Todo-Liste.
// Jedes Todo wird in einem LI-Element gerendert.
function renderTodos() {
  const todoList = document.getElementById("todoList");

  todoList.innerHTML = todos
    .map(
      (todo, index) => `
    <li>
      <label>
        
        <span style="${
          todo.completed ? "text-decoration: line-through" : ""
        }">${todo.text}</span><input type="checkbox" 
          ${todo.completed ? "checked" : ""} 
          onchange="window.toggleTodo(${index})"
        >
      </label>
      <button onclick="window.removeTodo(${index})">Löschen</button>
    </li>
  `
    )
    .join("");
}

// Macht die Funktionen global verfügbar für die onclick-Handler
window.toggleTodo = toggleTodo;
window.removeTodo = removeTodo;
