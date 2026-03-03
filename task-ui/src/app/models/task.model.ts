export interface Task {
  id?: number;
  title: string;
  description?: string;
  status: TaskStatus;
  dueDate?: string;
  createdAt?: string;
  updatedAt?: string;
}

export type TaskStatus = 'PENDING' | 'IN_PROGRESS' | 'COMPLETED';
