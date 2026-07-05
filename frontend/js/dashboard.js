// Dashboard functions
let dashboardRefreshInterval = null;

async function loadDashboard() {
    if (!api.isAuthenticated()) {
        console.warn('Dashboard load skipped: no auth token available');
        return;
    }

    try {
        const [ordersResponse, devicesResponse] = await Promise.all([
            api.getDashboardData(),
            api.getDevices(),
        ]);

        if (!ordersResponse.ok || !devicesResponse.ok) {
            if (ordersResponse.status === 401 || devicesResponse.status === 401) {
                handleLogout();
                return;
            }
            throw new Error('Failed to load dashboard');
        }

        const ordersData = await ordersResponse.json();
        const devices = await devicesResponse.json();
        renderDashboard(devices, ordersData.recent_orders || []);
    } catch (error) {
        console.error('Dashboard load error:', error);
    }
}

async function generateDemoData(force = false) {
    if (!api.isAuthenticated()) {
        showToast('Please login first', 'error');
        return;
    }
    
    const btn = document.getElementById('generate-demo-btn');
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Generating...';
    }
    
    try {
        const response = await api.generateDemoData(force);
        const data = await response.json();
        
        if (response.ok) {
            showToast(data.message, 'success');
            // Refresh dashboard after a short delay
            setTimeout(() => {
                loadDashboard();
                loadDevices();
            }, 1000);
        } else {
            // If demo data already exists, show option to force regenerate
            if (data.detail && data.detail.includes('already exists') && !force) {
                const shouldForce = confirm('Demo data already exists. Would you like to regenerate it?');
                if (shouldForce) {
                    generateDemoData(true);
                }
            } else {
                showToast(data.detail || data.message || 'Failed to generate demo data', 'error');
            }
        }
    } catch (error) {
        console.error('Error generating demo data:', error);
        showToast('Failed to generate demo data. Please check your connection.', 'error');
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-magic mr-2"></i>Generate Demo Data';
        }
    }
}

function renderDashboard(devices, orders) {
    const lowStock = devices.filter(d => d.reorder_level != null && d.current_quantity != null && d.current_quantity < d.reorder_level);
    const outOfStock = devices.filter(d => d.current_quantity === 0);

    // Update summary cards
    document.getElementById('total-items').textContent = devices.length;
    document.getElementById('low-stock-count').textContent = lowStock.length;
    document.getElementById('out-of-stock-count').textContent = outOfStock.length;
    document.getElementById('order-count').textContent = orders.length;
    document.getElementById('last-updated').textContent = `Updated: ${new Date().toLocaleTimeString()}`;

    // Render container grid (same cards as My Devices — name and quantity
    // are entirely user-decided via the Claim Device form, no more hardcoded
    // demo product names)
    const grid = document.getElementById('inventory-grid');
    if (devices.length === 0) {
        grid.innerHTML = '<div class="col-span-full text-center py-12"><div class="text-6xl mb-4">📦</div><h3 class="text-xl font-semibold text-gray-700 mb-2">No Containers Yet</h3><p class="text-gray-500 mb-4">Claim a device from the My Devices tab, or generate demo data, to see a container here</p><button id="generate-demo-btn" onclick="generateDemoData()" class="bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700 transition"><i class="fas fa-magic mr-2"></i>Generate Demo Data</button></div>';
    } else {
        grid.innerHTML = devices.map(device => createContainerCard(device)).join('');
    }

    // Render orders table (lives on the Cart tab)
    const container = document.getElementById('orders-table-container');
    if (container) {
        if (orders.length === 0) {
            container.innerHTML = '<div class="text-center py-8 text-gray-500">No replenishment orders yet. They will appear when stock runs low.</div>';
        } else {
            container.innerHTML = createOrdersTable(orders);
        }
    }
}

function createOrdersTable(orders) {
    let html = `
        <table class="w-full">
            <thead>
                <tr class="bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <th class="px-6 py-3">Order ID</th>
                    <th class="px-6 py-3">Supplier</th>
                    <th class="px-6 py-3">Status</th>
                    <th class="px-6 py-3">Amount</th>
                    <th class="px-6 py-3">Items</th>
                    <th class="px-6 py-3">Date</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
    `;

    orders.forEach(order => {
        const statusClass = `order-status-${order.order_status}`;
        const itemsList = (order.line_items || []).map(li => 
            `${li.product_name}: ${li.quantity_ordered} ${li.unit_type}`
        ).join(', ');

        html += `
            <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 text-sm font-mono text-gray-600">${order.order_id.substring(0, 8)}...</td>
                <td class="px-6 py-4 text-sm text-gray-800">${order.supplier_name || 'N/A'}</td>
                <td class="px-6 py-4">
                    <span class="px-2 py-1 rounded-full text-xs font-medium ${statusClass}">
                        ${order.order_status}
                    </span>
                </td>
                <td class="px-6 py-4 text-sm text-gray-800">₹${order.total_amount?.toFixed(2) || '0.00'}</td>
                <td class="px-6 py-4 text-sm text-gray-500 max-w-xs truncate" title="${itemsList}">${itemsList || 'N/A'}</td>
                <td class="px-6 py-4 text-sm text-gray-500">${order.created_at ? new Date(order.created_at).toLocaleDateString() : 'N/A'}</td>
            </tr>
        `;
    });

    html += '</tbody></table>';
    return html;
}

function startDashboardRefresh() {
    if (dashboardRefreshInterval) clearInterval(dashboardRefreshInterval);
    dashboardRefreshInterval = setInterval(() => {
        loadDashboard();
        loadCart();
    }, 5000);
}

function stopDashboardRefresh() {
    if (dashboardRefreshInterval) {
        clearInterval(dashboardRefreshInterval);
        dashboardRefreshInterval = null;
    }
}