<<<<<<< HEAD
# OpenResPublica TruthChain — ORP Engine

**Cryptographically verifiable barangay document issuance.**  
Every document gets a SHA-256 fingerprint, anchored to an immutable database, stamped with a QR code, and published to a public ledger — permanently.

---

## Contents

1. [What It Does](#what-it-does)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Setup (Ubuntu WSL2 — Windows)](#setup-ubuntu-wsl2--windows)
5. [Setup (Termux proot-distro Ubuntu — Android)](#setup-termux-proot-distro-ubuntu--android)
6. [First-Run Sequence](#first-run-sequence)
7. [Daily Operation](#daily-operation)
8. [File Structure](#file-structure)
9. [Security Model](#security-model)
10. [Troubleshooting](#troubleshooting)

---

## What It Does

An operator uploads a signed PDF barangay document. The engine:

1. Computes a **SHA-256 fingerprint** — any tampering changes it completely
2. **Anchors the hash** to a local immudb instance (append-only, Merkle tree)
3. **GPG-signs** the audit record using an ephemeral key that lives only in RAM
4. **Stamps the PDF** with a QR code linking to the public verification portal
5. **Publishes** the record to GitHub Pages within 60–90 seconds
6. Returns the stamped PDF to the operator for printing and issuance

A citizen can later scan the QR code and independently verify the document — without trusting anyone, including the barangay office itself.

---

## Architecture

```
Windows 10/11 (or Android)
└── WSL2 Ubuntu (or Termux proot-distro Ubuntu)
    ├── Nginx :9443            ← mTLS gateway (operator cert required)
    │   └── Proxy → Gunicorn :5000
    ├── Gunicorn               ← WSGI server (1 worker, 2 threads)
    │   └── Flask main.py      ← PDF processing + crypto pipeline
    ├── immudb :3322           ← immutable hash anchor
    ├── /dev/shm/              ← ephemeral GPG RAM disk (wiped on exit)
    └── docs/records/          ← JSON audit trail → GitHub Pages
```

**Public-facing** (GitHub Pages — static, no server):
```
openrespublica.github.io/
├── index.html     ← verification portal
├── records.html   ← public ledger
├── about.html     ← system information
└── docs/records/
    ├── manifest.json       ← all records, newest first
    └── <sha256hash>.json   ← individual record files
```

---

## Prerequisites

### Hardware

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 4 GB | 8 GB |
| Storage | 10 GB free | 20 GB free |
| CPU | 2 cores | 4 cores |
| OS | Windows 10 (64-bit) | Windows 11 |

### Software (Windows side)

- **WSL2** enabled — `wsl --install` in PowerShell (Admin)
- **Ubuntu** WSL2 distro — `wsl --install -d Ubuntu`
- **Windows Terminal** (recommended) — for the gum UI launcher
- **Git for Windows** (optional) — for the `.ps1` launcher

### Software (Ubuntu side — installed automatically by setup.sh)

- Python 3.10+, pip, venv
- Go toolchain (for building immudb)
- openssl, git, make, clang, cmake
- nginx
- netcat-openbsd (for vault readiness polling)
- gnupg2

---

## Setup (Ubuntu WSL2 — Windows)

### 1. Open Ubuntu WSL2

```powershell
# In PowerShell:
wsl -d Ubuntu
```

### 2. Clone the repository

```bash
cd ~
git clone https://github.com/openrespublica/openrespublica.github.io.git
cd openrespublica.github.io
```

### 3. Run the master setup script

```bash
chmod +x setup.sh
./setup.sh
```

`setup.sh` runs all 9 steps in order and is **idempotent** — safe to re-run:

| Step | Script | What it does |
|------|--------|--------------|
| 1 | `orp-timezone-setup.sh` | Sets timezone to Asia/Manila |
| 2 | `orp-env-bootstrap.sh` | Creates `.env` with your LGU details |
| 3 | `python_prep.sh` | Creates `.venv` and installs Python dependencies |
| 4 | `immudb_setup.sh` | Builds immudb binaries from source |
| 5 | `immudb-setup-operator.sh` | Creates DB + operator user + `~/.identity/db_secrets.env` |
| 6 | `orp-pki-setup.sh` | Generates Sovereign Root CA, server cert, operator cert |
| 7 | `nginx-setup.sh` | Installs nginx and deploys mTLS configuration |
| 8 | `repo-init.sh` | Creates `docs/records/`, `.gitignore`, initializes git |

### 4. Install the operator certificate in Chrome/Edge

After `orp-pki-setup.sh` runs, you will have `operator_01.p12` in your PKI directory (default: `~/orp_engine/ssl/`).

**Chrome / Edge:**
```
Settings → Privacy and security → Security →
Manage certificates → Personal → Import →
Select operator_01.p12 → Enter export password
```

**Firefox:**
```
Settings → Privacy & Security → View Certificates →
Your Certificates → Import →
Select operator_01.p12 → Enter export password
```

### 5. Launch the engine

```bash
./run_orp.sh
```

Or with the gum UI (requires `gum` installed):
```bash
./run_orp-gum.sh
```

Or from Windows PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File Launch_ORP.ps1
```

---

## Setup (Termux proot-distro Ubuntu — Android)

### 1. Install Termux and proot-distro

```bash
pkg install proot-distro
proot-distro install ubuntu
proot-distro login ubuntu
```

### 2. Install base dependencies inside Ubuntu

```bash
apt-get update
apt-get install -y git curl wget sudo
```

### 3. Clone and run setup

```bash
cd ~
git clone https://github.com/openrespublica/openrespublica.github.io.git
cd openrespublica.github.io
chmod +x setup.sh
./setup.sh
```

> **Note:** On Termux proot, nginx runs without systemd. The engine uses
> native `nginx` signals (`nginx`, `nginx -s reload`) — no `systemctl` needed.

### 4. Launch

```bash
./run_orp.sh
```

The Termux launcher will copy the SSH public key to the clipboard automatically if `termux-clipboard-set` is available.

---

## First-Run Sequence

The first time you run `run_orp.sh` or `run_orp-gum.sh`:

```
1. orp_load_env         → loads .env and ~/.identity/db_secrets.env
2. orp_forge_identity   → generates ephemeral Ed25519 key in /dev/shm
                          exports: GNUPGHOME, SSH_AUTH_SOCK, KEY_ID
3. orp_start_vault      → starts immudb on :3322 (or attaches if running)
4. orp_configure_git    → sets git user.name, user.email, signingkey
5. orp_refresh_gateway  → validates nginx config, starts/reloads nginx
6. Display session keys → SSH public key + GPG public key shown
7. PAUSE                → operator pastes SSH key to GitHub Settings
8. ENTER                → orp_launch_engine starts Gunicorn
```

**GitHub SSH key registration** (required for public ledger sync):

```
GitHub.com → Settings → SSH and GPG Keys → New SSH Key →
Paste the key shown in the terminal → Save
```

This must be done at every session start because the SSH key is ephemeral — it lives in RAM and is wiped when the engine shuts down.

---

## Daily Operation

### Starting the engine

```bash
cd ~/openrespublica.github.io
./run_orp.sh
```

The terminal will prompt:
```
Enter password for vault user [orp_operator]: ████
```

Enter the immudb operator password you set during `immudb-setup-operator.sh`.

### Accessing the portal

Open Chrome or Edge (with the operator certificate installed):

```
https://localhost:9443
```

If you see **"Sovereign Identity Required"** — your browser certificate is not installed or was not selected. See Step 4 in the Setup section.

### Issuing a document

1. Open the portal at `https://localhost:9443`
2. Select **PDF Stamp & Anchor** in the sidebar
3. Upload the signed PDF
4. Select the document type
5. Click **Stamp, Hash & Anchor to Ledger**
6. Download the stamped PDF with the QR code
7. The public ledger updates within 60–90 seconds

### Locking the engine

Click **🔒 Lock Engine** in the portal topbar.

This sends a signal to Gunicorn → triggers `graceful_shutdown()` in Python → the shell cleanup trap fires → wipes the GPG RAM disk → session is dead.

Or press `Ctrl+C` in the terminal.

---

## File Structure

```
openrespublica.github.io/
│
├── main.py                      ← Flask application (PDF pipeline)
├── requirements.txt             ← Python dependencies
│
├── templates/
│   └── portal.html              ← Operator portal (Jinja2 template)
│
├── static/
│   ├── css/style.css            ← Operator portal styles
│   └── js/portal.js             ← Operator portal behaviour
│
├── docs/                        ← GitHub Pages root
│   ├── records/
│   │   ├── manifest.json        ← All records, newest first (auto-generated)
│   │   └── <sha256>.json        ← Individual record files (auto-generated)
│   └── control_number.txt       ← Last issued control number (auto-generated)
│
├── index.html                   ← Public: verification portal
├── records.html                 ← Public: public ledger
├── about.html                   ← Public: system information
├── verify.html                  ← Public: QR code verification landing
├── ledger.js                    ← Public: ledger table rendering
├── verify.js                    ← Public: verification logic
├── style.css                    ← Public: shared GitHub Pages styles
│
├── _orp_core.sh                 ← Shared boot functions (source only)
├── run_orp.sh                   ← Plain terminal launcher
├── run_orp-gum.sh               ← gum UI launcher (Windows Terminal)
├── Launch_ORP.ps1               ← Windows PowerShell igniter
│
├── setup.sh                     ← Master setup orchestrator
├── orp-env-bootstrap.sh         ← Creates .env
├── python_prep.sh               ← Creates .venv + installs deps
├── immudb_setup.sh              ← Builds immudb binaries
├── immudb-setup-operator.sh     ← Creates DB + user + db_secrets.env
├── orp-pki-setup.sh             ← Generates all certificates
├── nginx-setup.sh               ← Installs nginx + deploys config
├── orp_engine.conf.tpl          ← Nginx config template
├── repo-init.sh                 ← Creates docs/records/, .gitignore
├── orp-timezone-setup.sh        ← Sets Asia/Manila timezone
│
├── .env                         ← NOT in git. Created by orp-env-bootstrap.sh
└── .gitignore                   ← Excludes .env, .venv, .orp_vault/

~/.identity/
└── db_secrets.env               ← NOT in repo. Created by immudb-setup-operator.sh
                                    Contains: IMMUDB_USER, IMMUDB_DB

~/orp_engine/ssl/                ← Default PKI directory
├── sovereign_root.key           ← Root CA private key (KEEP SAFE)
├── sovereign_root.crt           ← Root CA certificate (share with operators)
├── orp_server.key               ← Nginx TLS private key
├── orp_server.crt               ← Nginx TLS certificate
├── operator_01.key              ← Operator client private key
├── operator_01.crt              ← Operator client certificate
└── operator_01.p12              ← Browser import bundle (KEEP SAFE)

~/.orp_vault/
├── data/                        ← immudb data (never delete)
├── immudb.pid                   ← immudb process ID
└── immudb.log                   ← immudb logs
```

---

## Security Model

### Layered defense

```
Layer 1 — Network:    mTLS at Nginx (:9443)
                      No valid operator_01.p12 = no access

Layer 2 — Identity:   Ephemeral Ed25519 key in /dev/shm
                      Generated fresh every session, wiped on exit

Layer 3 — Integrity:  SHA-256 hash + immudb anchor
                      Tampering changes the hash; immudb detects it

Layer 4 — Audit:      GPG-signed JSON record + public GitHub ledger
                      Cryptographically verifiable by anyone, anywhere

Layer 5 — Privacy:    Only the hash is stored, never the document
                      Compliant with RA 10173 (Data Privacy Act 2012)
```

### Ephemeral key lifecycle

```
run_orp.sh starts
    ↓
orp_forge_identity()
    ↓ creates GNUPGHOME in /dev/shm (RAM only)
    ↓ generates Ed25519 key (expires in 1 day)
    ↓ exports SSH_AUTH_SOCK, KEY_ID
    ↓
Session active — key usable for signing and git auth
    ↓
Engine shuts down (Ctrl+C or Lock Engine button)
    ↓
orp_cleanup()
    ↓ gpgconf --kill all
    ↓ rm -rf /dev/shm/.orp-gpg-* /dev/shm/orp_identity
    ↓
RAM wiped — key is gone permanently
```

### What is and is not stored on disk

| Data | Location | Persists |
|------|----------|----------|
| SHA-256 hash | immudb (`~/.orp_vault/data/`) | Forever |
| JSON audit record | `docs/records/<hash>.json` | Forever (git) |
| GPG signature | Inside JSON record | Forever (git) |
| PDF document | Never stored | — |
| Operator password | Never stored | — |
| Private keys (session) | `/dev/shm/` only | Until shutdown |

---

## Troubleshooting

### "CRITICAL: db_secrets.env not found"

```bash
# Re-run the operator setup:
./immudb-setup-operator.sh
```

### "Vault already running. Connecting." but Flask can't connect

```bash
# immudb may be running on a different port or crashed.
pkill immudb
./run_orp.sh
```

### "Nginx config test failed"

```bash
sudo nginx -t
# Read the output — it tells you the exact line number
sudo cat /etc/nginx/conf.d/orp_engine.conf
```

### Browser shows "Sovereign Identity Required" (495/496)

The browser did not present the operator certificate. Check:
1. `operator_01.p12` is imported in the browser
2. When prompted by the browser, select the ORP Operator certificate
3. The certificate has not expired (1-year validity from `orp-pki-setup.sh`)

To check certificate expiry:
```bash
openssl x509 -noout -dates -in ~/orp_engine/ssl/operator_01.crt
```

To renew: re-run `orp-pki-setup.sh` and re-import the new `operator_01.p12`.

### "GPG key generation timed out after 10s"

```bash
# The system may be under load. Retry:
./run_orp.sh

# Or check if a stale GNUPGHOME is blocking:
ls /dev/shm/.orp-gpg-*
rm -rf /dev/shm/.orp-gpg-*
```

### Public ledger not updating after 90 seconds

```bash
# Check git sync — the background thread logs to the console:
# Look for: "✅ TruthChain synchronized" or "❌ Git sync error"

# Common causes:
# 1. SSH key not added to GitHub Settings this session
# 2. No internet connection
# 3. Git conflict — the engine resolves with --rebase -X ours automatically
```

### immudb "ACCESS DENIED"

The operator password entered at startup does not match the one set during `immudb-setup-operator.sh`.

```bash
# Reset the operator password (requires superadmin):
~/bin/immuadmin login immudb
~/bin/immuadmin user changepassword orp_operator
```

---

## Legal & Compliance

| Requirement | Implementation |
|-------------|---------------|
| RA 10173 — Data Privacy Act 2012 | No personal data stored — only document hashes |
| RA 11032 — Ease of Doing Business | Documents issued with traceable control numbers |
| RA 11337 — Innovative Startup Act | System registered under DTI (PORE606818386933) |
| Civil Service Commission | Human review required before document issuance |

---

## About

**OpenResPublica TruthChain** is developed by **Marco Catapusan Fernandez**,  
registered under DTI as *OpenResPublica Information Technology Solutions*  
(Business Name No. 7643594, valid Dec 22 2025 – Dec 22 2030).

Deployed at Barangay Buñao, Dumaguete City, Negros Oriental, Philippines.

> *"A public servant's word must be written not just in ink, but in mathematics —  
> so that no power on earth can erase it."*

---

*Secured by immudb · Ed25519 · SHA-256 · mTLS · OpenPGP*
=======
# openrespublica-core
Official setup wizard and documentation for OpenResPublica (ORP) Sovereign Nodes. A zero-trust, verifiable civic infrastructure system built for Local Government Units utilizing immutable ledgers and mTLS gateways.
>>>>>>> 65e754ce974b099ee7bf330b188b25371e28828d
