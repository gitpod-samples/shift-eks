# Web Access Guide

## ✅ Application is Running!

The OpenShift Task Manager is deployed and accessible via localhost.

---

## 🌐 Access the Application

### Using VS Code Port Forwarding

The application is running on **localhost:8080** inside the container.

**To access it in your browser:**

1. **In VS Code**, look for the **PORTS** tab (usually at the bottom panel)
2. You should see port **8080** listed
3. Click on the **globe icon** or **"Open in Browser"** next to port 8080
4. The Task Manager web interface will open in your browser

**Alternative:** If port 8080 is not automatically forwarded:
1. Go to the **PORTS** tab
2. Click **"Forward a Port"**
3. Enter **8080**
4. Click the globe icon to open in browser

---

## 📍 Application URLs

Once you have port 8080 forwarded:

- **Main Application:** http://localhost:8080
- **Health Check:** http://localhost:8080/health
- **API Endpoint:** http://localhost:8080/api/tasks

---

## 🎯 What You'll See

The web interface includes:

- **Header:** OpenShift Task Manager with OpenShift branding
- **Info Box:** Lists all OpenShift-specific features being used
- **Statistics:** Total tasks, active tasks, completed tasks
- **Task Input:** Add new tasks
- **Task List:** View, complete, and delete tasks

---

## 🧪 Test the Application

### Via Web Browser
1. Open http://localhost:8080 (using VS Code port forwarding)
2. Add a task in the input field
3. Click "Add Task"
4. Mark tasks as complete
5. Delete tasks

### Via Command Line
```bash
# Health check
curl http://localhost:8080/health

# Create a task
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Task"}'

# Get all tasks
curl http://localhost:8080/api/tasks

# Complete a task (replace 1 with task ID)
curl -X PUT http://localhost:8080/api/tasks/1/complete

# Delete a task (replace 1 with task ID)
curl -X DELETE http://localhost:8080/api/tasks/1
```

---

## 🛠️ Management Commands

### View Application Logs
```bash
kubectl logs -n task-manager -l app.kubernetes.io/name=task-manager -f
```

### View All Resources
```bash
kubectl get all,route -n task-manager
```

### Check Pod Status
```bash
kubectl get pods -n task-manager
```

### Restart Port Forwarding (if needed)
```bash
# Stop existing port forward
pkill -f "port-forward.*task-manager"

# Start new port forward
kubectl port-forward -n task-manager svc/task-manager 8080:8080
```

### Redeploy Application
```bash
cd /workspaces/shift-eks/openshift-task-manager
./deploy-with-web-access.sh
```

### Uninstall Application
```bash
helm uninstall task-manager -n task-manager
kubectl delete namespace task-manager
```

---

## 🔍 Troubleshooting

### Port 8080 Not Accessible
```bash
# Check if port forwarding is running
ps aux | grep "port-forward"

# Restart port forwarding
kubectl port-forward -n task-manager svc/task-manager 8080:8080
```

### Application Not Responding
```bash
# Check pod status
kubectl get pods -n task-manager

# Check pod logs
kubectl logs -n task-manager -l app.kubernetes.io/name=task-manager

# Restart pod
kubectl rollout restart deployment task-manager -n task-manager
```

### VS Code Port Forwarding Not Working
1. Check the PORTS tab in VS Code
2. Manually add port 8080 if not listed
3. Try accessing http://localhost:8080 directly in your browser
4. Check if another process is using port 8080: `lsof -i :8080`

---

## 📊 Current Deployment Status

```bash
# Check deployment
kubectl get deployment task-manager -n task-manager

# Check service
kubectl get svc task-manager -n task-manager

# Check route (OpenShift-specific)
kubectl get route task-manager -n task-manager

# Full status
kubectl get all,route -n task-manager
```

---

## 🎉 Success!

Your OpenShift Task Manager is now running and accessible at:

**http://localhost:8080**

Use VS Code's port forwarding feature to access it in your web browser!

---

## 📚 Additional Documentation

- **README.md** - Application overview and features
- **OPENSHIFT_TO_EKS_MIGRATION.md** - Comprehensive migration guide
- **DEPLOYMENT_SUMMARY.md** - Deployment details and verification
- **deploy-with-web-access.sh** - Deployment script

---

**Deployed:** October 12, 2025  
**Cluster:** OKD Local (kind-okd-local)  
**Namespace:** task-manager  
**Status:** ✅ Running
