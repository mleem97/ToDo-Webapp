class TodoList {
  constructor() {
    this.newTodoInput = document.getElementById("new-todo");
    this.addBtn = document.getElementById("add-btn");
    this.todoList = document.getElementById("todo-list");
    this.todos = JSON.parse(localStorage.getItem("todos")) || [];
  }

  renderTodos() {
    this.todoList.innerHTML = this.todos
      .map(
        ({ id, text, isNew }) => `<li><span style="${isNew ? "color:red;" : ""}">${text}</span><button class="mdi mdi-delete" data-id="${id}"></button></li>`
      )
      .join("");
    this.addDeleteButtonListeners();
  }

  addDeleteButtonListeners() {
    const deleteButtons = this.todoList.querySelectorAll(".mdi-delete");
    deleteButtons.forEach((button) => {
      button.addEventListener("click", () => {
        const id = button.dataset.id;
        this.removeTodo(id);
      });
    });
  }

  saveTodos() {
    localStorage.setItem("todos", JSON.stringify(this.todos));
  }

  addTodo() {
    const todoText = this.newTodoInput.value.trim();
    if (todoText !== "") {
      const newTodo = {
        id: Date.now(),
        text: todoText,
        isNew: true,
      };
      this.todos.push(newTodo);
      this.saveTodos();
      this.renderTodos();
      this.newTodoInput.value = "";
    }
  }

  removeTodo(id) {
    this.todos = this.todos.filter((todo) => todo.id !== parseInt(id));
    this.saveTodos();
    this.renderTodos();
  }

  init() {
    this.addBtn.addEventListener("click", this.addTodo.bind(this));
    this.newTodoInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        this.addTodo();
      }
    });
    window.addEventListener("storage", () => {
      this.todos = JSON.parse(localStorage.getItem("todos")) || [];
      this.renderTodos();
    });
    this.renderTodos();
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const app = document.getElementById("app");
  app.style.userSelect = "none";

  const todoList = new TodoList();
  todoList.init();
});
