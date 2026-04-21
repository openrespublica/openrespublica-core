# OpenResPublica TruthChain
## Technical and Policy Whitepaper
### A Cryptographically Verifiable Document Issuance System for Philippine Barangay Governance

---

**Issued by:** OpenResPublica Information Technology Solutions  
**Developer:** Marco Catapusan Fernandez  
**DTI Registration:** Business Name No. 7643594 · PORE606818386933  
**Deployment Site:** Barangay Buñao, Dumaguete City, Negros Oriental  
**Version:** 1.0 · April 2026  

---

## Executive Summary

OpenResPublica TruthChain (ORP Engine) is a lean, cryptographically rigorous document issuance and verification system designed for deployment at the barangay level of Philippine local government. It addresses a longstanding vulnerability in civic document administration: the absence of any tamper-evident, publicly verifiable audit trail for barangay-issued certificates.

The system enables a barangay operator to upload a signed PDF document and receive, within seconds, a stamped copy bearing a SHA-256 fingerprint, a unique control number, and a scannable QR code. The document's hash is simultaneously anchored to a local immutable database and published to a globally accessible public ledger on GitHub Pages. Any citizen, official, or auditor can verify the document's authenticity at any time — without contacting the barangay office, without trusting any intermediary, and without specialized software.

The system is operational at Barangay Buñao, Dumaguete City, and is designed for replication across any barangay in the Philippines with a standard laptop and an internet connection.

---

## 1. Problem Statement

### 1.1 The Document Authenticity Gap

Barangay offices in the Philippines issue millions of certificates annually — certificates of indigency, residency, clearance, business permits, and general-purpose barangay certifications. These documents are foundational to civic life: they are required for employment, school enrollment, social services, and legal proceedings.

Yet the current issuance process is almost entirely paper-based and relies entirely on trust. There is no technical mechanism by which a recipient, an employer, or a government agency can independently verify that a barangay certificate is authentic, unaltered, and was genuinely issued by the barangay it purports to come from. A document can be:

- Physically forged with a rubber stamp and a signature imitation
- Digitally altered after issuance without any detectable trace
- Issued under a false name with no linkage to an official record
- Denied by the issuing office without consequence, since no immutable issuance record exists

This vulnerability affects not only individual citizens but the integrity of processes that depend on these documents — from DSWD social protection assessments to DICT connectivity program eligibility determinations.

### 1.2 Existing Approaches and Their Limitations

Some barangays have adopted electronic record systems, typically spreadsheets or simple databases. These approaches share a fundamental weakness: they are mutable. Any record can be modified, deleted, or backdated by anyone with access to the system. A spreadsheet is not a ledger. A database backup is not cryptographic proof.

National-level systems such as the Philippine Statistics Authority's civil registry and the PhilSys national ID program address identity at the national level but do not solve the document issuance problem at the barangay level, where the volume of daily transactions is highest and the technical capacity is most constrained.

### 1.3 The Specific Gap This System Fills

ORP Engine fills the gap between a barangay official signing a document and a third party trusting that document — without requiring either party to trust the other, a database, or a central authority. The trust is transferred from people to mathematics.

---

## 2. Solution Overview

### 2.1 Core Concept

Every document processed by ORP Engine receives a **SHA-256 cryptographic fingerprint** — a unique 64-character string that is mathematically derived from the exact contents of the document. This fingerprint has two critical properties:

**Determinism:** The same document always produces the same fingerprint. Scan the document tomorrow, next year, or a decade from now — the hash will match.

**Avalanche sensitivity:** Any modification to the document — a single character, a space, a pixel — produces a completely different fingerprint. There is no way to modify a document and preserve its original hash.

This fingerprint is anchored to an **immutable, append-only database** (immudb) that uses a Merkle tree structure. Once a hash is written, it cannot be deleted or altered by anyone — including system administrators. The Merkle root provides mathematical proof that no historical entry has ever been tampered with.

The fingerprint and associated metadata are also published to a **public GitHub Pages ledger**, accessible globally without authentication. Anyone in the world can verify any document by scanning its QR code.

### 2.2 What the System Does NOT Store

ORP Engine stores only the cryptographic fingerprint of a document — not the document itself, not its contents, not the personal information of the document subject. This is a deliberate privacy-by-design decision, compliant with the Data Privacy Act of 2012 (RA 10173). The document exists only in two places: the barangay's physical files and the hands of the recipient.

---

## 3. Technical Architecture

### 3.1 System Overview

```
Operator Terminal (Windows 10/11 + WSL2 Ubuntu)
│
├── Browser (Chrome/Edge with mTLS operator certificate)
│   └── HTTPS → Nginx :9443
│
├── Nginx (mTLS Reverse Proxy)
│   ├── Verifies operator certificate against Sovereign Root CA
│   ├── Injects operator identity into request headers (X-Operator-ID)
│   └── Proxies to Gunicorn :5000
│
├── Gunicorn + Flask (ORP Engine — main.py)
│   ├── SHA-256 fingerprinting
│   ├── immudb anchor
│   ├── Control number issuance (thread-safe)
│   ├── GPG record signing
│   ├── PDF stamping (QR + footer)
│   └── Background GitHub sync
│
├── immudb (Immutable Vault — :3322)
│   └── Append-only, Merkle tree anchored hash store
│
└── /dev/shm/ (RAM disk — ephemeral session identity)
    ├── Ephemeral Ed25519 keypair (auto-generated, 1-day expiry)
    ├── GPG agent socket
    └── Wiped on session end
```

### 3.2 Document Processing Pipeline

When an operator submits a PDF, the following sequence executes in under five seconds:

| Step | Action | Technology |
|------|--------|-----------|
| 1 | File validation (PDF format, size ≤ 20MB) | Flask / Python |
| 2 | SHA-256 fingerprint computation | Python hashlib |
| 3 | Hash anchored to immutable database | immudb gRPC client |
| 4 | Thread-safe control number issuance | Python threading.Lock() |
| 5 | Operator identity captured from mTLS certificate | Nginx X-Operator-ID header |
| 6 | Audit record assembled and GPG-signed | python-gnupg, Ed25519 |
| 7 | JSON record saved locally | Python filesystem |
| 8 | QR code generated linking to public ledger | qrcode library |
| 9 | PDF stamped with footer (hash, timestamp, QR) | ReportLab + pypdf |
| 10 | Stamped PDF returned to operator browser | Flask send_file |
| 11 | Record committed to GitHub Pages (background) | git + SSH ephemeral key |

### 3.3 Cryptographic Stack

**SHA-256 (Document Fingerprinting)**
The industry standard for document integrity verification. Produces a 256-bit (64-character hexadecimal) fingerprint. Collision resistance: no two different documents will produce the same hash. Used in Philippine e-Government standards and internationally by ISO/IEC 10118-3.

**Ed25519 (Session Signing and Authentication)**
An elliptic curve digital signature algorithm providing 128-bit security with compact key sizes. The session keypair is generated fresh at every engine start, lives only in RAM (/dev/shm), expires in 24 hours, and is cryptographically wiped on shutdown. Used for both GPG record signing and SSH authentication to GitHub.

**mTLS with RSA-2048 / SHA-256 (Operator Authentication)**
Mutual TLS (Transport Layer Security) requires both the server and the client to present certificates. The operator's browser must present a certificate signed by the Sovereign Root CA before any request reaches Flask. This eliminates the possibility of remote access by anyone who does not physically possess the operator certificate file (operator_01.p12).

**immudb Merkle Tree (Tamper Evidence)**
immudb maintains a cryptographic Merkle tree over all stored records. Each new entry is linked to all previous entries through their combined hash. Any attempt to modify, delete, or insert a record into the historical sequence breaks the Merkle root — immediately detectable by any independent audit.

### 3.4 Immutability Model

The system achieves immutability through two independent, complementary mechanisms:

**Local immutability (immudb):** The hash is anchored locally before any network operation. Even if the internet connection fails, the local audit record is already mathematically locked. The immudb transaction ID serves as the timestamp and sequence proof.

**Public immutability (GitHub):** The JSON audit record is committed to a public git repository. Git uses SHA-1 (transitioning to SHA-256) to chain commits — any modification to a historical record would require rewriting the entire commit chain, which is publicly visible. The GitHub Pages ledger is additionally cached by CDN, creating multiple independent copies.

Together, these two mechanisms mean that an attacker would need to simultaneously compromise the local immudb instance AND rewrite the public git history AND invalidate the CDN cache — an effectively impossible combination.

### 3.5 Ephemeral Identity Architecture

One of the most significant security properties of the system is its use of ephemeral cryptographic identities. The session keypair is generated at engine start, used exclusively in RAM, and is wiped completely at session end. This means:

- There is no persistent private key on disk to steal
- A compromised machine after a session contains no cryptographic material
- Every session is independently auditable with its own unique key fingerprint
- The key automatically expires in 24 hours even if the cleanup process fails

This design is aligned with NIST Special Publication 800-57 recommendations on key lifecycle management and exceeds the security posture of most enterprise document management systems.

---

## 4. Security Model

### 4.1 Threat Model

| Threat | Mitigation |
|--------|-----------|
| Remote unauthorized access | mTLS: no valid certificate = no access at the network layer |
| Stolen operator credentials | Ephemeral key wiped at session end; password never stored on disk |
| Document forgery after issuance | SHA-256 hash mismatch detectable by anyone via QR scan |
| Insider tampering with records | immudb Merkle tree breaks on any modification |
| Physical theft of the terminal | No persistent private keys on disk; RAM wiped on shutdown |
| Man-in-the-middle attack | TLS 1.2/1.3 with HSTS; mTLS mutual authentication |
| Session hijacking | Ephemeral keys expire in 24 hours; SIGINT wipes RAM immediately |
| Denial-of-service | Rate limiting at Nginx layer; Gunicorn worker isolation |

### 4.2 What "Verified" Means

When a citizen scans the QR code on an ORP-stamped document and sees "AUTHENTIC DOCUMENT," the system is asserting the following, with mathematical proof:

1. A PDF with this exact SHA-256 fingerprint existed at the recorded timestamp
2. That fingerprint was anchored to immudb at that exact moment (transaction ID provides proof)
3. An operator whose identity is recorded in the audit record was authenticated via a certificate signed by the Sovereign Root CA at the time of issuance
4. The audit record itself has not been altered since it was GPG-signed

None of these assertions requires trusting the barangay office. They are verifiable by any party with access to the public ledger and the document.

---

## 5. Compliance and Legal Framework

### 5.1 Republic Act 10173 — Data Privacy Act of 2012

ORP Engine processes documents but stores no personal data. The only data stored is the document's SHA-256 hash — a one-way mathematical transformation that cannot be reversed to reveal the document's contents. The audit record stores document metadata (type, timestamp, control number) but no subject names, addresses, or identification numbers.

**Compliance status:** The system is designed from the ground up to minimize data collection. It collects only what is mathematically necessary to prove a document's authenticity — and nothing more.

### 5.2 Republic Act 11032 — Ease of Doing Business and Efficient Government Service Delivery Act

RA 11032 mandates that government transactions be traceable and that processing times be minimized. ORP Engine provides:

- A unique, formatted control number for every document issued (format: YYYY-NNNN-DOCTYPE)
- A complete audit trail from issuance to public publication, timestamped to the second
- End-to-end document processing in under five seconds
- A public verification portal accessible 24/7 at zero cost to the citizen

**Compliance status:** The system directly implements the traceability and accountability provisions of RA 11032 at the barangay level.

### 5.3 Republic Act 8792 — Electronic Commerce Act

The Electronic Commerce Act recognizes electronic documents and electronic signatures as legally valid. The GPG signature applied to every ORP audit record constitutes an electronic signature under RA 8792, binding the operator's verified identity to the record at the time of issuance.

**Compliance status:** Every ORP record carries a valid electronic signature. The system's use of standard cryptographic algorithms (Ed25519, SHA-256) is consistent with international e-commerce standards.

### 5.4 Republic Act 11337 — Innovative Startup Act

The Innovative Startup Act establishes a policy environment that encourages technology-based solutions to public-sector challenges. ORP Engine was developed under the principles of open-source innovation and civic technology, consistent with the Act's mandate to support technology entrepreneurs contributing to public welfare.

**Compliance status:** The developer is a DTI-registered IT solutions entity (PORE606818386933). The system is open-source and designed for public-sector replication without licensing fees.

---

## 6. Deployment and Operational Evidence

### 6.1 Pilot Deployment

ORP Engine is deployed and operational at **Barangay Buñao, Dumaguete City, Negros Oriental**, under the administration of **Hon. Raquel A. Samson**, Punong Barangay.

The deployment runs on a standard consumer-grade laptop (HP) using Windows 10 with WSL2 Ubuntu, demonstrating that the system operates within the technical constraints of a typical barangay office — no dedicated server hardware, no cloud subscription, no specialized IT staff required.

### 6.2 Public Ledger

The public ledger is accessible at:

**https://openrespublica.github.io**

The ledger is hosted on GitHub Pages — a static site with no server-side components, no authentication requirement, and no maintenance overhead. Records published to this ledger are preserved by GitHub's infrastructure and mirrored by CDN, providing independent, decentralized availability.

### 6.3 System Performance

Based on operational data from the pilot deployment:

| Metric | Value |
|--------|-------|
| Document processing time | Under 5 seconds |
| Public ledger sync time | 60–90 seconds |
| System availability | Session-bound (operator-controlled) |
| Storage per record | ~2 KB (JSON metadata only) |
| Network requirement | Outbound HTTPS to GitHub only |

### 6.4 Hardware Requirements for Replication

| Component | Minimum | Notes |
|-----------|---------|-------|
| RAM | 4 GB | 8 GB recommended |
| Storage | 10 GB free | immudb data grows ~2 KB per record |
| OS | Windows 10 64-bit | Windows 11 also supported |
| Internet | Broadband | Required for GitHub sync only |
| Browser | Chrome or Edge | Firefox also supported |

---

## 7. Comparison with Alternative Approaches

| Capability | ORP Engine | Traditional Registry | Cloud Document System |
|-----------|-----------|---------------------|----------------------|
| Tamper-evident records | ✅ Cryptographic | ❌ None | ⚠️ Vendor-dependent |
| Publicly verifiable | ✅ Anyone, anywhere | ❌ In-office only | ⚠️ Account required |
| Operates offline (after setup) | ✅ Local immudb | ✅ Paper | ❌ Cloud-dependent |
| No recurring cost | ✅ Zero | ✅ Zero | ❌ Subscription fee |
| Citizen self-verification | ✅ QR scan | ❌ Not possible | ⚠️ App required |
| Data privacy compliant | ✅ No PII stored | ✅ Paper only | ⚠️ Cloud data risk |
| Disaster recovery | ✅ GitHub backup | ❌ Fire/flood risk | ⚠️ Vendor recovery |
| Open source / replicable | ✅ Full source | N/A | ❌ Proprietary |

---

## 8. Replication and Scalability

### 8.1 Designed for Replication

Every configuration value in ORP Engine is stored in a single `.env` file populated through an interactive setup script (`orp-env-bootstrap.sh`). No credentials, names, or location data are hardcoded in any script or application file. A new barangay deployment requires:

1. A standard laptop with Windows 10/11 and WSL2
2. Approximately 60 minutes for automated setup
3. A GitHub account for the public ledger
4. An operator certificate issued by the deployment's own Sovereign Root CA

The entire setup process is documented, automated, and reproducible through a single master script (`setup.sh`).

### 8.2 Federated Architecture

Each barangay runs its own independent ORP Engine with its own Sovereign Root CA, immudb vault, and GitHub Pages ledger. There is no central server and no single point of failure. This federated model means:

- A compromise of one barangay's system does not affect any other
- Each barangay owns and controls its own cryptographic identity
- No data leaves the barangay's local network except the anonymized hash and metadata published to GitHub
- The system can operate during internet outages with the local immudb anchor intact

### 8.3 Upgrade Path

Because the system's public interface is a static GitHub Pages site and its internal API is a versioned REST interface, future upgrades can be deployed without disrupting the historical ledger or existing verified documents. The SHA-256 fingerprints and immudb transaction IDs of all previously issued documents remain valid indefinitely.

---

## 9. Limitations and Known Constraints

**Human review requirement:** ORP Engine verifies that a document was stamped by an authenticated operator at a specific time — it does not verify that the document's contents are accurate. A barangay officer must review and approve the document before uploading it. The system is a seal of authenticity, not a substitute for official judgment.

**Single-operator design:** The current implementation is optimized for a single authorized operator per deployment. Multi-operator support (with independent certificates per operator) is architecturally supported but has not been implemented in the pilot.

**Key ceremony required at each session:** The ephemeral key architecture requires the operator to paste the session SSH key to GitHub at the start of every session. This is a security feature — not a limitation — but it requires the operator to follow a consistent startup procedure.

**Internet connectivity for public ledger sync:** The local immudb anchor operates without internet. However, publication to the public GitHub Pages ledger requires outbound HTTPS connectivity. Documents issued during an outage will sync automatically when connectivity is restored.

---

## 10. Roadmap

### Phase 2 — Physical Presence Verification (Planned)

Integration of an ESP32 microcontroller with PIR (motion), IR obstacle avoidance, and ambient light sensors to provide hardware-level proof-of-physical-presence. This ensures that no automated or remote process can issue documents — a human body must be physically present at the terminal.

### Phase 3 — Multi-Barangay Federation (Planned)

A shared verification standard allowing any barangay's documents to be verified against a common schema while each barangay retains full ownership of its own keys, ledger, and vault. No central authority required.

### Phase 4 — Policy-Compliant PhilID Integration (Pending)

Automated certificate generation from PhilID JSON payloads, contingent on CSC/DILG policy establishing the legal basis for machine-assisted document generation and the appropriate wet-signature or digital-signature workflow.

---

## 11. About the Developer

**Marco Catapusan Fernandez** is an independent civic technology developer based in Barangay Buñao, Dumaguete City, Negros Oriental. OpenResPublica TruthChain was developed as a direct response to the gap between the promise of Philippine e-governance and the operational reality at the barangay level.

The system was built with the following principles:

**Simplicity as a security property.** A lean codebase with minimal dependencies is easier to audit, harder to exploit, and easier to maintain by non-specialist operators.

**No trust required.** The system is designed so that its correctness can be verified by anyone with a web browser and the document in hand — without trusting the developer, the barangay, or any intermediary.

**Replication over exclusivity.** The system is open-source and designed to be replicated by any barangay in the Philippines without licensing fees, vendor lock-in, or dependency on a central service.

**OpenResPublica Information Technology Solutions**
DTI Business Name No. 7643594
PORE No. PORE606818386933
Validity: December 22, 2025 — December 22, 2030
Address: Bunao, City of Dumaguete, Negros Oriental

---

## 12. Conclusion

OpenResPublica TruthChain demonstrates that government-grade document authenticity — previously the domain of national agencies with significant infrastructure investment — is achievable at the barangay level using open-source tools, standard cryptography, and a standard laptop.

The system does not ask citizens to trust a person or an office. It asks them to trust mathematics. SHA-256, immudb, and a public git ledger together provide a chain of evidence that is verifiable by anyone, anywhere, at any time, at zero cost.

The pilot deployment at Barangay Buñao is operational evidence that this is not a theoretical system. It runs today, it issues real documents, and those documents are verifiable on the public internet.

The authors invite the Department of Information and Communications Technology to evaluate ORP Engine as a model for barangay-level document integrity — a system lean enough to run on the equipment already present in every barangay office, yet rigorous enough to satisfy cryptographic audit standards.

---

## Appendix A — Glossary

| Term | Definition |
|------|-----------|
| SHA-256 | A one-way cryptographic hash function producing a 256-bit (64-character) fingerprint. Any change to the input produces a completely different output. |
| Ed25519 | An elliptic curve digital signature algorithm. Used for signing audit records and authenticating to GitHub. |
| mTLS | Mutual TLS. Both the server and the client must present valid certificates. Used to restrict portal access to authorized operators only. |
| immudb | An open-source, append-only database using a Merkle tree to provide cryptographic proof that no historical record has been modified. |
| Merkle Tree | A tree of cryptographic hashes where each node depends on all nodes below it. Any modification to any entry changes the root hash, making tampering immediately detectable. |
| GPG | GNU Privacy Guard. Used to digitally sign audit records, binding the operator's ephemeral session identity to each issuance. |
| Ephemeral Key | A cryptographic key generated for a single session, stored only in RAM, and permanently destroyed at session end. |
| PKCS#12 (.p12) | A file format for bundling a private key and its certificate chain. Used to install the operator certificate in a browser. |
| Sovereign Root CA | The certificate authority created during PKI setup. All operator certificates are signed by this CA. Nginx uses it to verify operator certificates. |
| GitHub Pages | A static site hosting service. Used as the public ledger because it is free, CDN-backed, globally accessible, and has no server-side attack surface. |
| Control Number | A sequential identifier issued to each document. Format: YYYY-NNNN-DOCTYPE. Thread-safe — no two documents can ever receive the same number. |

## Appendix B — Technology Stack

| Component | Technology | Version | License |
|-----------|-----------|---------|---------|
| Application server | Python / Flask | 3.10+ / 3.0+ | BSD / MIT |
| WSGI server | Gunicorn | 21.0+ | MIT |
| Reverse proxy | Nginx | 1.18+ | BSD |
| Immutable database | immudb | 1.9.0 | Apache 2.0 |
| PDF processing | pypdf + ReportLab | 4.0+ / 4.0+ | BSD / BSD |
| Cryptographic signing | python-gnupg + GnuPG | 0.5+ / 2.2+ | LGPL / GPL |
| QR code generation | qrcode | 7.4+ | BSD |
| Operating system | Ubuntu 22.04 LTS (WSL2) | 22.04 | Various (open) |
| Public ledger host | GitHub Pages | — | Free tier |
| Runtime environment | Windows 10/11 + WSL2 | — | Proprietary |

---

*OpenResPublica TruthChain — Version 1.0 — April 2026*
*Barangay Buñao, Dumaguete City, Negros Oriental, Philippines*
*Secured by immudb · Ed25519 · SHA-256 · mTLS · OpenPGP*
