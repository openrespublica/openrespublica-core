let ledgerData = [];

document.addEventListener('DOMContentLoaded', () => {
    loadLedger();
});

async function loadLedger() {
    const tbody = document.getElementById('ledger-body');
    try {
        const response = await fetch(`records/manifest.json?t=${Date.now()}`);
        if (!response.ok) throw new Error();
        
        ledgerData = await response.json();
        // Show newest records first
        renderTable(ledgerData.reverse());
    } catch (e) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;">No records found in the cloud ledger yet.</td></tr>';
    }
}

function renderTable(arr) {
    const tbody = document.getElementById('ledger-body');
    tbody.innerHTML = arr.map(item => `
        <tr>
            <td><strong>${item.control_number}</strong></td>
            <td>${item.timestamp.split(' ')[0]}</td>
            <td><span class="badge-type">${item.document_type || 'GENERAL'}</span></td>
            <td><code>${item.sha256_hash.substring(0, 12)}...</code></td>
            <td><a href="index.html?hash=${item.sha256_hash}">Verify</a></td>
        </tr>
    `).join('');
}

function searchLedger() {
    const term = document.getElementById('search').value.toLowerCase();
    const filtered = ledgerData.filter(item => 
        item.control_number.toLowerCase().includes(term) || 
        item.document_type.toLowerCase().includes(term)
    );
    renderTable(filtered);
}
