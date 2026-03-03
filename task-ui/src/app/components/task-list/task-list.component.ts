import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TaskService } from '../../services/task.service';
import { Task, TaskStatus } from '../../models/task.model';
import { TaskFormComponent } from '../task-form/task-form.component';

@Component({
  selector: 'app-task-list',
  standalone: true,
  imports: [CommonModule, FormsModule, TaskFormComponent],
  templateUrl: './task-list.component.html',
  styleUrl: './task-list.component.css'
})
export class TaskListComponent implements OnInit {
  tasks: Task[] = [];
  filteredTasks: Task[] = [];
  selectedTask: Task | null = null;
  showForm = false;
  isEditing = false;
  searchQuery = '';
  statusFilter: TaskStatus | '' = '';
  loading = false;
  error = '';

  constructor(private taskService: TaskService) {}

  ngOnInit(): void {
    this.loadTasks();
  }

  loadTasks(): void {
    this.loading = true;
    this.error = '';
    this.taskService.getAllTasks().subscribe({
      next: (tasks) => {
        this.tasks = tasks;
        this.applyFilters();
        this.loading = false;
      },
      error: (err) => {
        this.error = 'Failed to load tasks. Please try again.';
        this.loading = false;
        console.error(err);
      }
    });
  }

  applyFilters(): void {
    let result = [...this.tasks];

    if (this.statusFilter) {
      result = result.filter(task => task.status === this.statusFilter);
    }

    if (this.searchQuery.trim()) {
      const query = this.searchQuery.toLowerCase();
      result = result.filter(task =>
        task.title.toLowerCase().includes(query) ||
        (task.description?.toLowerCase().includes(query))
      );
    }

    this.filteredTasks = result;
  }

  onStatusFilterChange(): void {
    this.applyFilters();
  }

  onSearchChange(): void {
    this.applyFilters();
  }

  openCreateForm(): void {
    this.selectedTask = null;
    this.isEditing = false;
    this.showForm = true;
  }

  openEditForm(task: Task): void {
    this.selectedTask = { ...task };
    this.isEditing = true;
    this.showForm = true;
  }

  closeForm(): void {
    this.showForm = false;
    this.selectedTask = null;
    this.isEditing = false;
  }

  onTaskSaved(task: Task): void {
    if (this.isEditing && task.id) {
      const index = this.tasks.findIndex(t => t.id === task.id);
      if (index !== -1) {
        this.tasks[index] = task;
      }
    } else {
      this.tasks.unshift(task);
    }
    this.applyFilters();
    this.closeForm();
  }

  deleteTask(task: Task): void {
    if (!task.id) return;

    if (confirm(`Are you sure you want to delete "${task.title}"?`)) {
      this.taskService.deleteTask(task.id).subscribe({
        next: () => {
          this.tasks = this.tasks.filter(t => t.id !== task.id);
          this.applyFilters();
        },
        error: (err) => {
          this.error = 'Failed to delete task.';
          console.error(err);
        }
      });
    }
  }

  getStatusClass(status: TaskStatus): string {
    switch (status) {
      case 'PENDING': return 'status-pending';
      case 'IN_PROGRESS': return 'status-progress';
      case 'COMPLETED': return 'status-completed';
      default: return '';
    }
  }

  formatDate(dateString?: string): string {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleString();
  }
}
