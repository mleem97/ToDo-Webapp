class TodoList {
  constructor() {
    this.todoInput = document.getElementById("new-todo");
    this.addButton = document.getElementById("add-btn");
    this.todoList = document.getElementById("todo-list");
    this.todos = JSON.parse(localStorage.getItem("todos")) || [];
  }

  renderTodos() {
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

    this.todoList
      .querySelectorAll(".mdi-delete")
      .forEach((btn) =>
        btn.addEventListener("click", () => this.removeTodo(btn.dataset.id))
      );
  }

  saveTodos() {
    localStorage.setItem("todos", JSON.stringify(this.todos));
  }

  addTodo() {
    const text = this.todoInput.value.trim();
    if (!text) return;

    this.todos.push({ id: Date.now(), text, isNew: true });
    this.saveTodos();
    this.renderTodos();
    this.todoInput.value = "";
  }

  removeTodo(id) {
    this.todos = this.todos.filter((todo) => todo.id !== parseInt(id));
    this.saveTodos();
    this.renderTodos();
  }

  init() {
    this.addButton.addEventListener("click", () => this.addTodo());
    this.todoInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") this.addTodo();
    });
    window.addEventListener("storage", () => {
      this.todos = JSON.parse(localStorage.getItem("todos")) || [];
      this.renderTodos();
    });

    this.renderTodos();
  }
}

document.addEventListener("DOMContentLoaded", () => new TodoList().init());
