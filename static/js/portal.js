// static/js/portal.js
// ORP Engine — Operator Portal behaviour layer.
// Handles: navigation, file drop, upload form, ledger, dashboard, lock button.
// No ingest route — removed pending legal framework (see main.py comments).

// ── ENTRY POINT ──────────────────────────────────────────────────
// DOMContentLoaded fires when the HTML is fully parsed and all elements
// exist in the DOM. We wait for this before attaching any event listeners
// because JS loaded at the bottom of <body> runs before all elements
// are guaranteed to be ready on slower machines.
document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initLockButton();
    initFileDrop();
    initUploadForm();
    initLedgerPagination();
    loadDashboard();  // fetch manifest stats immediately on page load
});


// ── NAVIGATION ───────────────────────────────────────────────────
// One function handles all nav buttons — regardless of how many exist.
// This is event delegation: instead of one listener per button,
// we loop once and attach the same logic to each button.
// The data-target attribute on each button tells us which panel to show.
function initNavigation() {
    document.querySelectorAll('.nav-item[data-target]').forEach(btn => {
        btn.addEventListener('click', e => {
            const target = e.currentTarget.getAttribute('data-target');

            // Remove "active" from every nav item, then add it to the clicked one.
            document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
            e.currentTarget.classList.add('active');

            // Remove "active" from every panel, then add it to the target panel.
            // CSS does the rest: .panel { display:none } .panel.active { display:block }
            document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
            document.getElementById('panel-' + target).classList.add('active');

            // Load data on demand — only when the operator actually navigates there.
            // This avoids unnecessary network requests on page load.
            if (target === 'ledger')    loadLedger();
            if (target === 'dashboard') loadDashboard();
        });
    });
}


// ── LOCK BUTTON ──────────────────────────────────────────────────
// Sends POST /lock_engine to Flask.
// Flask fires SIGINT after a 0.5s delay → graceful_shutdown() →
// shell trap in run_orp.sh → RAM disk wiped → session dead.
// The try/catch is intentional: after Flask fires SIGINT the connection
// resets, which would normally throw a network error. We catch it silently
// because the lock succeeded — the error is expected, not a failure.
function initLockButton() {
    document.getElementById('lockBtn')?.addEventListener('click', async () => {
        if (!confirm('Shut down engine and purge RAM disk?')) return;
        try {
            await fetch('/lock_engine', { method: 'POST' });
        } catch {
            // Expected: server closes the connection after SIGINT.
            // We still show the locked screen — the operation succeeded.
        }
        document.body.innerHTML = `
            <div style="text-align:center;padding:5rem;font-family:sans-serif;">
                <h1 style="font-size:2rem;">🏛️ Engine Locked</h1>
                <p style="color:#6B7280;">RAM disk purged. Session closed securely.</p>
            </div>`;
    });
}


// ── FILE DROP UX ─────────────────────────────────────────────────
// The native <input type="file"> is hidden because it cannot be styled.
// This function makes the styled .file-drop div behave like a file input:
//   - Click on the zone → programmatically clicks the hidden input
//   - Drag a file over  → visual feedback (dragover class)
//   - Drop a file       → attaches it to the hidden input
// The hidden input then holds the file exactly as if the operator
// had clicked it directly — FormData picks it up normally.
function initFileDrop() {
    const dropZone  = document.getElementById('dropZone');
    const fileInput = document.getElementById('pdfFile');
    if (!dropZone || !fileInput) return;

    // Click on the styled zone → open the native file picker.
    dropZone.addEventListener('click', () => fileInput.click());

    // Visual feedback while dragging a file over the zone.
    dropZone.addEventListener('dragover', e => {
        e.preventDefault();  // must preventDefault to allow drop
        dropZone.classList.add('dragover');
    });

    dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('dragover');
    });

    // File dropped — validate it's a PDF, then attach to the hidden input.
    dropZone.addEventListener('drop', e => {
        e.preventDefault();
        dropZone.classList.remove('dragover');
        const file = e.dataTransfer.files[0];
        if (file?.name.toLowerCase().endsWith('.pdf')) {
            fileInput.files = e.dataTransfer.files;
            updateFileDisplay(fileInput);
        }
    });

    // File selected via the native picker — update the display.
    fileInput.addEventListener('change', () => updateFileDisplay(fileInput));
}

// Shows the selected filename and size inside the drop zone.
// Called after both drop and native file picker selection.
function updateFileDisplay(input) {
    const file = input.files[0];
    if (!file) return;
    const el         = document.getElementById('selectedFileName');
    el.textContent   = `✓ ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
    el.style.display = 'inline-block';
}


// ── UI HELPERS ───────────────────────────────────────────────────

// Animates the progress steps (us1–us4 for upload).
// step: the current active step number (1-indexed)
// total: total number of steps
// Steps before current → "done" (green)
// Current step         → "active" (navy, highlighted)
// Steps after current  → unstyled (grey)
function setProgress(prefix, step, total) {
    for (let i = 1; i <= total; i++) {
        const el = document.getElementById(prefix + i);
        if (!el) continue;
        el.className = 'progress-step' +
            (i < step ? ' done' : i === step ? ' active' : '');
    }
    // Move the progress bar proportionally.
    const bar = document.getElementById('uploadBar');
    if (bar) bar.style.width = `${Math.min(100, (step / total) * 100)}%`;
}

// Renders the result box after Flask responds.
// ok:       true = success (green), false = error (red)
// title:    headline text
// details:  object → renders as key/value pairs
//           string → renders as a paragraph
// blob:     the stamped PDF as a Blob object (browser RAM, not server)
// filename: the download filename from Content-Disposition header
function showResult(id, ok, title, details, blob, filename) {
    const el         = document.getElementById(id);
    el.className     = 'result-box ' + (ok ? 'result-success' : 'result-error');
    el.style.display = 'block';

    // Build the details section.
    let dHtml = '';
    if (details && typeof details === 'object') {
        dHtml = '<div class="result-kv">' +
            Object.entries(details).map(([k, v]) =>
                `<span class="result-key">${k}</span>` +
                `<span class="result-val">${v}</span>`
            ).join('') +
            '</div>';
    } else if (details) {
        dHtml = `<p style="margin-top:0.5rem;">${details}</p>`;
    }

    // Build the download link.
    // createObjectURL creates a temporary URL pointing to the blob in RAM.
    // This URL never exists on the server — it's ephemeral to this browser tab.
    // a.click() simulates a download without the operator clicking anything.
    let dlHtml = '';
    if (blob && filename) {
        const url = URL.createObjectURL(blob);
        dlHtml = `<a href="${url}" download="${filename}" class="download-btn">` +
                 `⬇ Download ${filename}</a>`;
    }

    el.innerHTML =
        `<div class="result-header"><h4>${ok ? '✅' : '❌'} ${title}</h4></div>` +
        `<div class="result-body">${dHtml}${dlHtml}</div>`;
}


// ── UPLOAD FORM ──────────────────────────────────────────────────
// Handles the entire PDF upload flow:
//   1. Validate file is selected
//   2. Disable button (prevent duplicate submissions)
//   3. Show progress steps
//   4. Pack file + doc_type into FormData
//   5. POST to Flask /upload
//   6. Animate progress steps while waiting
//   7. On response: show result + download link, or error
//   8. Re-enable button, hide progress
function initUploadForm() {
    document.getElementById('uploadForm')?.addEventListener('submit', async e => {
        e.preventDefault();  // stop the browser's default form submission

        const file    = document.getElementById('pdfFile').files[0];
        const docType = document.getElementById('uploadDocType').value;
        const btn     = document.getElementById('uploadBtn');

        if (!file) { alert('Please select a PDF file.'); return; }

        // Disable the button immediately — prevents duplicate submissions
        // while Flask is still processing. Re-enabled in the finally block.
        btn.disabled = true;

        // Show the progress section, hide any previous result.
        document.getElementById('uploadProgress').style.display = 'block';
        document.getElementById('uploadResult').style.display   = 'none';

        // Animate steps 1-3 on a timer.
        // These are theatre — they don't reflect real Flask progress.
        // Step 4 fires only when Flask actually responds (below).
        // Timings: 100ms, 800ms, 1500ms after submit.
        [1, 2, 3].forEach((s, i) =>
            setTimeout(() => setProgress('us', s, 4), i * 700 + 100)
        );

        // FormData packs the file and doc_type exactly as if the browser
        // submitted a traditional HTML form. Flask reads them via
        // request.files.get('document') and request.form.get('doc_type').
        const fd = new FormData();
        fd.append('document', file);
        fd.append('doc_type', docType);

        try {
            // fetch() sends the POST request. await pauses THIS function
            // here until Flask responds — but the browser tab stays alive
            // and responsive. This is the key benefit of async/await.
            const res = await fetch('/upload', { method: 'POST', body: fd });

            // Step 4 fires on actual Flask response — the real signal.
            setProgress('us', 4, 4);

            if (res.ok) {
                // res.ok is true for any 2xx status code (200, 201, etc.)
                // res.blob() reads the response body as raw binary data —
                // the stamped PDF that Flask sent via send_file().
                const blob = await res.blob();

                // The filename comes from Flask's Content-Disposition header:
                // attachment; filename="Verified_2026-0042-BARANGAY-CERT.pdf"
                // The regex extracts just the filename part.
                const ctrl = res.headers.get('Content-Disposition')
                    ?.match(/filename="?([^"]+)"?/)?.[1] || `${docType}.pdf`;

                showResult(
                    'uploadResult', true,
                    'Document Anchored to TruthChain',
                    {
                        'File':   file.name,
                        'Type':   docType,
                        'Status': 'Anchored · Publishing to ledger...',
                    },
                    blob, ctrl
                );
            } else {
                // Flask returned a non-2xx status (400, 500, etc.)
                // Read the response body as text to show the error message.
                showResult('uploadResult', false, 'Upload Failed', await res.text());
            }

        } catch (err) {
            // Network error — Flask unreachable, connection dropped, etc.
            showResult('uploadResult', false, 'Connection Error', err.message);

        } finally {
            // finally runs whether the request succeeded or failed.
            // Always re-enable the button and hide progress after 3.5s.
            btn.disabled = false;
            setTimeout(() => {
                document.getElementById('uploadProgress').style.display = 'none';
                setProgress('us', 0, 4);  // reset all steps to unstyled
            }, 3500);
        }
    });
}


// ── LEDGER ───────────────────────────────────────────────────────
// Pagination state — module-level variables shared between
// loadLedger(), renderLedgerTable(), and initLedgerPagination().
let lData = [];   // full array of records from manifest.json
let lPage = 1;    // current page number (1-indexed)
const LP  = 15;   // records per page

// Fetches manifest.json from the public GitHub Pages ledger.
// Called when the operator clicks "Local Ledger" in the sidebar.
// Uses ?t=Date.now() to bust the browser cache — ensures fresh data.
async function loadLedger() {
    // Show loading state while the fetch is in-flight.
    document.getElementById('ledgerBody').innerHTML =
        '<tr><td colspan="6" style="text-align:center;padding:1.5rem;color:var(--muted);">' +
        '<div class="spinner" style="margin:0 auto 0.5rem;"></div>Loading...</td></tr>';

    try {
        const res = await fetch(
            'https://openrespublica.github.io/records/manifest.json?t=' + Date.now()
        );
        if (!res.ok) throw new Error('Manifest unavailable');

        // manifest.json is newest-first (main.py uses records.insert(0, record)).
        // .reverse() is NOT needed — data is already in the right order.
        lData = await res.json();
        lPage = 1;  // reset to first page on every fresh load
        renderLedgerTable();

    } catch {
        document.getElementById('ledgerBody').innerHTML =
            '<tr><td colspan="6" style="text-align:center;padding:1.5rem;color:var(--muted);">' +
            'Could not load manifest. Check your connection.</td></tr>';
    }
}

// Renders the current page of records into the table.
// Called by loadLedger() on first load, and by pagination buttons.
function renderLedgerTable() {
    const total = lData.length;
    const start = (lPage - 1) * LP;
    const end   = Math.min(start + LP, total);
    const slice = lData.slice(start, end);

    document.getElementById('ledgerBody').innerHTML = slice.map(r => `
        <tr>
            <td>
                <strong style="font-size:0.78rem;color:var(--navy-mid);">
                    ${r.control_number || '—'}
                </strong>
            </td>
            <td><span class="badge-type">${r.document_type || 'GENERAL'}</span></td>
            <td style="font-size:0.75rem;color:var(--muted);">${r.timestamp || '—'}</td>
            <td><span class="mono">${(r.sha256_hash || '').substring(0, 14)}…</span></td>
            <td><span class="mono">#${r.immudb_transaction_id || '—'}</span></td>
            <td style="text-align:center;">
                <a href="https://openrespublica.github.io/index.html?hash=${r.sha256_hash}"
                   target="_blank" class="btn-outline">Verify</a>
            </td>
        </tr>`).join('');

    // Update the record count label and pagination button states.
    document.getElementById('ledgerCount').textContent =
        `Showing ${start + 1}–${end} of ${total} records`;
    document.getElementById('lPrev').disabled = lPage === 1;
    document.getElementById('lNext').disabled = end >= total;
}

// Attaches click listeners to the Prev/Next pagination buttons.
// Called once on DOMContentLoaded — the buttons always exist in the DOM.
function initLedgerPagination() {
    document.getElementById('lPrev')?.addEventListener('click', () => {
        lPage = Math.max(1, lPage - 1);
        renderLedgerTable();
    });
    document.getElementById('lNext')?.addEventListener('click', () => {
        lPage = Math.min(lPage + 1, Math.ceil(lData.length / LP));
        renderLedgerTable();
    });
}


// ── DASHBOARD ────────────────────────────────────────────────────
// Fetches the manifest and updates the two live stat values.
// Called on page load so the dashboard has data even before
// the operator navigates to it.
// Failures are silently ignored — dashboard stats are informational,
// not critical. The operator can still use the upload form if this fails.
async function loadDashboard() {
    try {
        const res = await fetch(
            'https://openrespublica.github.io/records/manifest.json?t=' + Date.now()
        );
        if (!res.ok) return;

        // manifest.json is newest-first — data[0] is the most recent record.
        const data = await res.json();
        document.getElementById('dTotal').textContent  = data.length;
        document.getElementById('dLatest').textContent =
            (data[0]?.timestamp || '').split(' ')[0] || '—';

    } catch { /* silently ignore — dashboard stats are non-critical */ }
}
}
