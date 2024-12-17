document.addEventListener("DOMContentLoaded", () => {
  const newTodoInput = document.getElementById("new-todo");
  const addBtn = document.getElementById("add-btn");
  const todoList = document.getElementById("todo-list");
  let todos = JSON.parse(localStorage.getItem("todos")) || [];

  function renderTodos() {
    todoList.innerHTML = "";
    todos.forEach((todo) => {
      const li = document.createElement("li");
      li.innerHTML = `
                <span style="${todo.isNew ? "color:red;" : ""}">${
        todo.text
      }</span>
                <i class="mdi mdi-delete" data-id="${todo.id}"></i>
            `;
      if (todo.isNew) {
        setTimeout(() => {
          const span = li.querySelector("span");
          const i = li.querySelector("i");
          span.style.color = "";
          i.style.color = "";
          todo.isNew = false;
          saveTodos();
        }, 3000);
      }
      todoList.appendChild(li);
    });
  
    const deleteButtons = todoList.querySelectorAll(".mdi-delete");
    deleteButtons.forEach((button) => {
      button.addEventListener("click", () => {
        const id = button.dataset.id;
        removeTodo(id);
      });
    });
  }

  function saveTodos() {
    localStorage.setItem("todos", JSON.stringify(todos));
  }

  function addTodo(todoText) {
    if (todoText.trim() === "") return;
    const newTodo = {
      id: Date.now(),
      text: todoText,
      isNew: true,
    };
    todos.push(newTodo);
    saveTodos();
    renderTodos();
    newTodoInput.value = "";
  }

  function removeTodo(id) {
    todos = todos.filter((todo) => todo.id !== parseInt(id));
    localStorage.removeItem(id);
    saveTodos();
    renderTodos();
  }

  addBtn.addEventListener("click", () => {
    const todoText = newTodoInput.value.trim();
    addTodo(todoText);
  });

  newTodoInput.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
      const todoText = newTodoInput.value.trim();
      addTodo(todoText);
    }
  });

  window.addEventListener("storage", () => {
    todos = JSON.parse(localStorage.getItem("todos")) || [];
    renderTodos();
  });

  const app = document.getElementById("app");
  app.style.userSelect = "none";

  const deleteButtons = todoList.querySelectorAll(".mdi-delete");
  deleteButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.id;
      removeTodo(id);
    });
  });

  renderTodos();
});