# DGX Spark Server Configuration Plan

## Context

DGX Spark (GB10, 128GB unified, ARM64 Grace+Blackwell) currently used as a workstation with ad-hoc inference via justfile recipes. No persistent services, no remote access, no reverse proxy. Goal: transform into an always-on server — vLLM inference, personal apps, SSH from anywhere. Accessible from both Tailscale and local LAN.

---

## 1. Tailscale — Remote Access

Install on DGX Spark and all client devices. Provides encrypted WireGuard tunnel, SSH from anywhere, MagicDNS hostnames.

### Install

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --hostname spark
```

`--ssh` enables Tailscale SSH (ACL-controlled, no sshd port 22 exposure needed from outside). `--hostname spark` gives it a stable MagicDNS name.

### Client setup
Install Tailscale on RTX 5090 laptop, phone, any other device. Then `ssh spark` works from anywhere.

---

## 2. Firewall — UFW (Tailscale + LAN)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0          # All Tailscale traffic
sudo ufw allow from 192.168.0.0/16      # LAN access (adjust subnet)
sudo ufw allow from 10.0.0.0/8          # Common LAN range
sudo ufw enable
```

---

## 3. vLLM — Persistent Inference via systemd

### systemd unit (`/etc/systemd/system/vllm.service`)

```ini
[Unit]
Description=vLLM Inference Server (Qwen3.6-35B-A3B FP8)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=halcyonicstorm
Environment=VLLM_MARLIN_USE_ATOMIC_ADD=1
ExecStart=/home/halcyonicstorm/.local/bin/sparkrun run @atlas/qwen3.6-35b-a3b-fp8-mtp --hosts localhost --max-model-len 262144
Restart=on-failure
RestartSec=30
TimeoutStartSec=600
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Install:
```bash
sudo cp server/vllm.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now vllm
```

### Memory budget at 0.85 GPU util
- ~109GB for vLLM (35B-A3B FP8 + 262K context)
- ~19GB remaining for OS + sidecar models + apps
- Sidecar models run on CPU, so they eat RAM from this 19GB — fine for 4B + embedding

### Model swap
Create additional units (`vllm-dense.service`, etc.) and swap with:
```bash
sudo systemctl stop vllm
sudo systemctl start vllm-dense
```

---

## 4. Sidecar Models

### 4a. Embedding model — nomic-embed-text via llama.cpp

systemd unit (`/etc/systemd/system/embedding.service`):

```ini
[Unit]
Description=Embedding Server (nomic-embed-text, llama.cpp)
After=network-online.target

[Service]
Type=simple
User=halcyonicstorm
ExecStart=/home/halcyonicstorm/git/llama.cpp/build/bin/llama-server \
    --model /home/halcyonicstorm/git/models/nomic-embed-text-v2-moe.Q8_0.gguf \
    --port 8082 \
    --host 0.0.0.0 \
    --embedding \
    --ctx-size 8192 \
    --threads 8
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Download:
```bash
hf download nomic-ai/nomic-embed-text-v2-moe-GGUF nomic-embed-text-v2-moe.Q8_0.gguf \
    --local-dir ~/git/models
```

~700MB RAM. Exposes OpenAI-compatible `/v1/embeddings` on port 8082.

### 4b. Small coding LLM — Qwen3-4B via llama.cpp

systemd unit (`/etc/systemd/system/autocomplete.service`):

```ini
[Unit]
Description=Autocomplete Server (Qwen3-4B, llama.cpp)
After=network-online.target

[Service]
Type=simple
User=halcyonicstorm
ExecStart=/home/halcyonicstorm/git/llama.cpp/build/bin/llama-server \
    --model /home/halcyonicstorm/git/models/Qwen3-4B-Q8_0.gguf \
    --port 8080 \
    --host 0.0.0.0 \
    --ctx-size 32768 \
    --threads 8 \
    --chat-template chatml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Download:
```bash
hf download Qwen/Qwen3-4B-GGUF Qwen3-4B-Q8_0.gguf \
    --local-dir ~/git/models
```

~4.5GB RAM. Fast autocomplete on port 8080.

---

## 5. Caddy — Reverse Proxy

Config (`/etc/caddy/Caddyfile`):

```caddyfile
{
    admin off
}

:80 {
    # vLLM inference API
    handle /v1/* {
        reverse_proxy localhost:8000
    }

    # Embedding API
    handle /embed/* {
        uri strip_prefix /embed
        reverse_proxy localhost:8082
    }

    # Autocomplete API
    handle /autocomplete/* {
        uri strip_prefix /autocomplete
        reverse_proxy localhost:8080
    }

    # Future apps go here as handle blocks
    # handle /app1/* {
    #     reverse_proxy localhost:3000
    # }

    respond "DGX Spark" 200
}
```

Install:
```bash
sudo apt install -y caddy
sudo cp server/Caddyfile /etc/caddy/Caddyfile
sudo systemctl enable --now caddy
```

---

## 6. Docker Compose — Future App Hosting

`server/docker-compose.yml` — skeleton, add apps as needed:

```yaml
# Add personal apps here. Start with `docker compose up -d`.
# Each app gets a port, Caddy routes to it.
services: {}
```

---

## 7. Server Management — Justfile Module

`dev/just/server.just`:

```just
# Server management recipes for DGX Spark

# Show status of all server services
server-status:
    @echo "=== Inference ==="
    systemctl is-active vllm || true
    @echo "=== Sidecars ==="
    systemctl is-active embedding || true
    systemctl is-active autocomplete || true
    @echo "=== Infrastructure ==="
    systemctl is-active caddy || true
    systemctl is-active tailscaled || true
    @echo "=== Docker Apps ==="
    docker compose -f ~/server/docker-compose.yml ps 2>/dev/null || echo "no apps"

# Tail service logs
server-logs service="vllm":
    journalctl -u {{service}} -f

# Restart a service
server-restart service:
    sudo systemctl restart {{service}}

# Swap vLLM model (stop current, start named variant)
model-swap variant:
    sudo systemctl stop vllm || true
    sudo systemctl start vllm-{{variant}}
    @echo "Switched to vllm-{{variant}}"
```

---

## 8. Port Map

| Port | Service | Protocol |
|------|---------|----------|
| 8000 | vLLM (flagship 35B-A3B) | OpenAI API |
| 8080 | llama.cpp (Qwen3-4B autocomplete) | OpenAI API |
| 8082 | llama.cpp (nomic-embed-text) | OpenAI API |
| 80   | Caddy reverse proxy | HTTP |

---

## 9. Implementation Order

1. **Tailscale** — install, `tailscale up --ssh --hostname spark`, verify from laptop
2. **UFW** — deny all except tailscale0 + LAN
3. **systemd units** — create `server/` directory, write all `.service` files
4. **Download sidecar models** — nomic-embed-text GGUF + Qwen3-4B GGUF
5. **Enable services** — `systemctl enable --now` for vllm, embedding, autocomplete
6. **Caddy** — install, deploy Caddyfile, enable
7. **Justfile** — add server.just module, add setup recipes
8. **Docker Compose** — skeleton for future apps

---

## 10. Verification

1. `ssh spark` from RTX laptop off-network (Tailscale)
2. `ssh spark` from RTX laptop on-network (LAN)
3. `curl http://spark:8000/v1/models` returns vLLM model
4. `curl http://spark:8080/v1/models` returns autocomplete model
5. `curl http://spark:8082/v1/embeddings -d '{"input":"test","model":"nomic-embed-text"}'` returns embedding
6. `curl http://spark/v1/models` via Caddy
7. `sudo systemctl status vllm embedding autocomplete caddy` all active
8. Reboot — all services come back automatically
9. `just -g server-status` shows everything green
