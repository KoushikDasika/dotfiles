# Server management recipes for DGX Spark

# Enable and start llama.cpp on boot
server-enable:
    sudo systemctl daemon-reload
    sudo systemctl enable --now llama

# Show status of all server services
server-status:
    @echo "=== llama.cpp ==="
    systemctl is-active llama || true
    @echo "=== Ollama ==="
    systemctl is-active ollama || true

# Tail service logs (default: llama)
server-logs service="llama":
    journalctl -u {{service}} -f

# Restart a service (default: llama)
server-restart service="llama":
    sudo systemctl restart {{service}}
