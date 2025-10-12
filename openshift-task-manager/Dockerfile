FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ .

# Create non-root user for OpenShift compatibility
RUN useradd -u 1001 -r -g 0 -m -s /sbin/nologin \
    -c "Application user" appuser && \
    chown -R 1001:0 /app && \
    chmod -R g=u /app && \
    chmod 1777 /tmp

# Switch to non-root user
USER 1001

# Expose port
EXPOSE 8080

# Run the application with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "120", "app:app"]
