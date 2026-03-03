import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Task, TaskStatus } from '../../models/task.model';
import { TaskService } from '../../services/task.service';

@Component({
  selector: 'app-task-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './task-form.component.html',
  styleUrl: './task-form.component.css'
})
export class TaskFormComponent implements OnInit {
  @Input() task: Task | null = null;
  @Input() isEditing = false;
  @Output() save = new EventEmitter<Task>();
  @Output() cancel = new EventEmitter<void>();

  formData: Task = {
    title: '',
    description: '',
    status: 'PENDING'
  };

  statuses: TaskStatus[] = ['PENDING', 'IN_PROGRESS', 'COMPLETED'];
  loading = false;
  error = '';

  constructor(private taskService: TaskService) {}

  ngOnInit(): void {
    if (this.task) {
      this.formData = { ...this.task };
    }
  }

  onSubmit(): void {
    if (!this.formData.title.trim()) {
      this.error = 'Title is required';
      return;
    }

    this.loading = true;
    this.error = '';

    const taskData: Task = {
      title: this.formData.title.trim(),
      description: this.formData.description?.trim() || '',
      status: this.formData.status
    };

    if (this.isEditing && this.task?.id) {
      this.taskService.updateTask(this.task.id, taskData).subscribe({
        next: (updatedTask) => {
          this.save.emit(updatedTask);
          this.loading = false;
        },
        error: (err) => {
          this.error = 'Failed to update task. Please try again.';
          this.loading = false;
          console.error(err);
        }
      });
    } else {
      this.taskService.createTask(taskData).subscribe({
        next: (newTask) => {
          this.save.emit(newTask);
          this.loading = false;
        },
        error: (err) => {
          this.error = 'Failed to create task. Please try again.';
          this.loading = false;
          console.error(err);
        }
      });
    }
  }

  onCancel(): void {
    this.cancel.emit();
  }

  formatStatusLabel(status: TaskStatus): string {
    return status.replace('_', ' ');
  }
}
