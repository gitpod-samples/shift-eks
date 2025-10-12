#!/usr/bin/env python3
"""
OpenShift Task Manager - A simple task management application
that demonstrates OpenShift-specific features.
"""
import os
import json
from datetime import datetime
from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# In-memory storage
tasks = []
task_id_counter = 1

# HTML template with embedded CSS and JavaScript
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenShift Task Manager</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        .header {
            background: #ee0000;
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .openshift-badge {
            display: inline-block;
            background: rgba(255,255,255,0.2);
            padding: 5px 15px;
            border-radius: 20px;
            margin-top: 10px;
            font-size: 0.9em;
        }
        .content {
            padding: 30px;
        }
        .add-task-form {
            display: flex;
            gap: 10px;
            margin-bottom: 30px;
        }
        .add-task-form input {
            flex: 1;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 5px;
            font-size: 1em;
        }
        .add-task-form input:focus {
            outline: none;
            border-color: #ee0000;
        }
        .add-task-form button {
            padding: 12px 30px;
            background: #ee0000;
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 1em;
            cursor: pointer;
            transition: background 0.3s;
        }
        .add-task-form button:hover {
            background: #cc0000;
        }
        .tasks-list {
            list-style: none;
        }
        .task-item {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 5px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: transform 0.2s;
        }
        .task-item:hover {
            transform: translateX(5px);
        }
        .task-item.completed {
            opacity: 0.6;
        }
        .task-item.completed .task-title {
            text-decoration: line-through;
        }
        .task-info {
            flex: 1;
        }
        .task-title {
            font-size: 1.1em;
            margin-bottom: 5px;
            color: #333;
        }
        .task-meta {
            font-size: 0.85em;
            color: #666;
        }
        .task-actions {
            display: flex;
            gap: 10px;
        }
        .task-actions button {
            padding: 8px 15px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 0.9em;
            transition: all 0.3s;
        }
        .btn-complete {
            background: #28a745;
            color: white;
        }
        .btn-complete:hover {
            background: #218838;
        }
        .btn-delete {
            background: #dc3545;
            color: white;
        }
        .btn-delete:hover {
            background: #c82333;
        }
        .empty-state {
            text-align: center;
            padding: 40px;
            color: #999;
        }
        .empty-state svg {
            width: 100px;
            height: 100px;
            margin-bottom: 20px;
            opacity: 0.3;
        }
        .stats {
            display: flex;
            justify-content: space-around;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .stat-item {
            text-align: center;
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #ee0000;
        }
        .stat-label {
            font-size: 0.9em;
            color: #666;
            margin-top: 5px;
        }
        .openshift-info {
            background: #fff3cd;
            border: 1px solid #ffc107;
            border-radius: 5px;
            padding: 15px;
            margin-bottom: 20px;
        }
        .openshift-info h3 {
            color: #856404;
            margin-bottom: 10px;
        }
        .openshift-info ul {
            margin-left: 20px;
            color: #856404;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Task Manager</h1>
            <p>Powered by OpenShift OKD</p>
            <div class="openshift-badge">Using OpenShift-Specific Features</div>
        </div>
        <div class="content">
            <div class="openshift-info">
                <h3>OpenShift Features in Use:</h3>
                <ul>
                    <li>Routes (instead of Ingress)</li>
                    <li>DeploymentConfig (instead of Deployment)</li>
                    <li>ImageStreams (for image management)</li>
                    <li>SecurityContextConstraints (custom SCC)</li>
                    <li>Templates (resource provisioning)</li>
                </ul>
            </div>
            
            <div class="stats">
                <div class="stat-item">
                    <div class="stat-value" id="total-tasks">0</div>
                    <div class="stat-label">Total Tasks</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value" id="active-tasks">0</div>
                    <div class="stat-label">Active</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value" id="completed-tasks">0</div>
                    <div class="stat-label">Completed</div>
                </div>
            </div>

            <div class="add-task-form">
                <input type="text" id="task-input" placeholder="Enter a new task..." />
                <button onclick="addTask()">Add Task</button>
            </div>

            <ul class="tasks-list" id="tasks-list">
                <div class="empty-state">
                    <svg viewBox="0 0 24 24" fill="currentColor">
                        <path d="M19 3h-4.18C14.4 1.84 13.3 1 12 1c-1.3 0-2.4.84-2.82 2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 0c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm2 14H7v-2h7v2zm3-4H7v-2h10v2zm0-4H7V7h10v2z"/>
                    </svg>
                    <p>No tasks yet. Add your first task above!</p>
                </div>
            </ul>
        </div>
    </div>

    <script>
        const API_BASE = window.location.origin;

        async function loadTasks() {
            try {
                const response = await fetch(`${API_BASE}/api/tasks`);
                const tasks = await response.json();
                renderTasks(tasks);
                updateStats(tasks);
            } catch (error) {
                console.error('Error loading tasks:', error);
            }
        }

        function renderTasks(tasks) {
            const tasksList = document.getElementById('tasks-list');
            
            if (tasks.length === 0) {
                tasksList.innerHTML = `
                    <div class="empty-state">
                        <svg viewBox="0 0 24 24" fill="currentColor">
                            <path d="M19 3h-4.18C14.4 1.84 13.3 1 12 1c-1.3 0-2.4.84-2.82 2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 0c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm2 14H7v-2h7v2zm3-4H7v-2h10v2zm0-4H7V7h10v2z"/>
                        </svg>
                        <p>No tasks yet. Add your first task above!</p>
                    </div>
                `;
                return;
            }

            tasksList.innerHTML = tasks.map(task => `
                <li class="task-item ${task.completed ? 'completed' : ''}">
                    <div class="task-info">
                        <div class="task-title">${escapeHtml(task.title)}</div>
                        <div class="task-meta">
                            Created: ${new Date(task.created_at).toLocaleString()} | 
                            Status: ${task.completed ? 'Completed' : 'Active'}
                        </div>
                    </div>
                    <div class="task-actions">
                        ${!task.completed ? `
                            <button class="btn-complete" onclick="completeTask(${task.id})">
                                ✓ Complete
                            </button>
                        ` : ''}
                        <button class="btn-delete" onclick="deleteTask(${task.id})">
                            ✕ Delete
                        </button>
                    </div>
                </li>
            `).join('');
        }

        function updateStats(tasks) {
            const total = tasks.length;
            const completed = tasks.filter(t => t.completed).length;
            const active = total - completed;

            document.getElementById('total-tasks').textContent = total;
            document.getElementById('active-tasks').textContent = active;
            document.getElementById('completed-tasks').textContent = completed;
        }

        async function addTask() {
            const input = document.getElementById('task-input');
            const title = input.value.trim();

            if (!title) {
                alert('Please enter a task title');
                return;
            }

            try {
                const response = await fetch(`${API_BASE}/api/tasks`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ title }),
                });

                if (response.ok) {
                    input.value = '';
                    loadTasks();
                }
            } catch (error) {
                console.error('Error adding task:', error);
                alert('Failed to add task');
            }
        }

        async function completeTask(id) {
            try {
                const response = await fetch(`${API_BASE}/api/tasks/${id}/complete`, {
                    method: 'PUT',
                });

                if (response.ok) {
                    loadTasks();
                }
            } catch (error) {
                console.error('Error completing task:', error);
            }
        }

        async function deleteTask(id) {
            if (!confirm('Are you sure you want to delete this task?')) {
                return;
            }

            try {
                const response = await fetch(`${API_BASE}/api/tasks/${id}`, {
                    method: 'DELETE',
                });

                if (response.ok) {
                    loadTasks();
                }
            } catch (error) {
                console.error('Error deleting task:', error);
            }
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Allow Enter key to add task
        document.getElementById('task-input').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                addTask();
            }
        });

        // Load tasks on page load
        loadTasks();
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """Serve the main application page."""
    return render_template_string(HTML_TEMPLATE)

@app.route('/health')
def health():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'service': 'openshift-task-manager',
        'openshift_features': [
            'Routes',
            'DeploymentConfig',
            'ImageStreams',
            'SecurityContextConstraints',
            'Templates'
        ]
    })

@app.route('/api/tasks', methods=['GET'])
def get_tasks():
    """Get all tasks."""
    return jsonify(tasks)

@app.route('/api/tasks', methods=['POST'])
def create_task():
    """Create a new task."""
    global task_id_counter
    
    data = request.get_json()
    if not data or 'title' not in data:
        return jsonify({'error': 'Title is required'}), 400
    
    task = {
        'id': task_id_counter,
        'title': data['title'],
        'completed': False,
        'created_at': datetime.utcnow().isoformat()
    }
    
    tasks.append(task)
    task_id_counter += 1
    
    return jsonify(task), 201

@app.route('/api/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    """Delete a task."""
    global tasks
    tasks = [t for t in tasks if t['id'] != task_id]
    return '', 204

@app.route('/api/tasks/<int:task_id>/complete', methods=['PUT'])
def complete_task(task_id):
    """Mark a task as completed."""
    for task in tasks:
        if task['id'] == task_id:
            task['completed'] = True
            return jsonify(task)
    
    return jsonify({'error': 'Task not found'}), 404

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
