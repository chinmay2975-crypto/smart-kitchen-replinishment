// Dashboard functions
let dashboardRefreshInterval = null;

async function loadDashboard() {
    if (!api.isAuthenticated()) {
        console.warn('Dashboard load skipped: no auth token available');
        return;
    }

    try {
        const response = await api.getDashboardData();
        if (!response.ok) {
            if (response.status === 401) {
                handleLogout();
                return;
            }
            throw new Error('Failed to load dashboard');
        }
        const data = await response.json();
        renderDashboard(data);
    } catch (error) {
        console.error('Dashboard load error:', error);
    }
}

async function generateDemoData() {
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
        const response = await api.generateDemoData();
        const data = await response.json();
        
        if (response.ok) {
            showToast(data.message, 'success');
            // Refresh dashboard after a short delay
            setTimeout(() => {
                loadDashboard();
                loadDevices();
            }, 1000);
        } else {
            showToast(data.detail || 'Failed to generate demo data', 'error');
        }
    } catch (error) {
        console.error('Error generating demo data:', error);
        showToast('Failed to generate demo data', 'error');
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-magic mr-2"></i>Generate Demo Data';
        }
    }
}

function renderDashboard(data) {
    const inventory = data.inventory || [];
    const orders = data.recent_orders || [];

    // Update summary cards
    document.getElementById('total-items').textContent = inventory.length;
    document.getElementById('low-stock-count').textContent = inventory.filter(i => i.stock_status === 'low_stock').length;
    document.getElementById('out-of-stock-count').textContent = inventory.filter(i => i.stock_status === 'out_of_stock').length;
    document.getElementById('order-count').textContent = orders.length;
    document.getElementById('last-updated').textContent = `Updated: ${new Date().toLocaleTimeString()}`;

    // Render inventory grid
    const grid = document.getElementById('inventory-grid');
    if (inventory.length === 0) {
        grid.innerHTML = '<div class="col-span-full text-center py-12"><div class="text-6xl mb-4">📦</div><h3 class="text-xl font-semibold text-gray-700 mb-2">No Inventory Items</h3><p class="text-gray-500 mb-4">Generate demo data to see sample inventory and visualization</p><button id="generate-demo-btn" onclick="generateDemoData()" class="bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700 transition"><i class="fas fa-magic mr-2"></i>Generate Demo Data</button></div>';
    } else {
        grid.innerHTML = inventory.map(item => createInventoryCard(item)).join('');
    }

    // Render orders table
    const container = document.getElementById('orders-table-container');
    if (orders.length === 0) {
        container.innerHTML = '<div class="text-center py-8 text-gray-500">No replenishment orders yet. They will appear when stock runs low.</div>';
    } else {
        container.innerHTML = createOrdersTable(orders);
    }
}

function createInventoryCard(item) {
    const maxQty = item.threshold_max || 5;
    const percentage = Math.min((item.quantity / maxQty) * 100, 100);
    const statusColors = {
        'ok': 'bg-emerald-500',
        'low_stock': 'bg-yellow-500',
        'out_of_stock': 'bg-red-500'
    };
    const statusLabels = {
        'ok': 'In Stock',
        'low_stock': 'Low Stock',
        'out_of_stock': 'Out of Stock'
    };
    const barColor = statusColors[item.stock_status] || 'bg-emerald-500';

    return `
        <div class="inventory-card bg-white rounded-xl shadow-sm p-5 border border-gray-100">
            <div class="flex justify-between items-start mb-3">
                <div>
                    <h4 class="font-semibold text-gray-800">${item.product_name}</h4>
                    <span class="text-xs text-gray-500">${item.category} • ${item.location}</span>
                </div>
                <span class="px-2 py-1 rounded-full text-xs font-medium status-${item.stock_status}">
                    ${statusLabels[item.stock_status]}
                </span>
            </div>
            <div class="mb-2">
                <div class="flex justify-between text-sm mb-1">
                    <span class="text-gray-600">${item.quantity} ${item.unit_type}</span>
                    <span class="text-gray-400">max ${maxQty} ${item.unit_type}</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2.5">
                    <div class="progress-bar ${barColor} h-2.5 rounded-full" style="width: ${percentage}%"></div>
                </div>
            </div>
            <div class="flex justify-between text-xs text-gray-400 mt-2">
                <span>Min: ${item.threshold_min || 0} ${item.unit_type}</span>
                <span>Updated: ${item.last_updated ? new Date(item.last_updated).toLocaleTimeString() : 'N/A'}</span>
            </div>
        </div>
    `;
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
    dashboardRefreshInterval = setInterval(loadDashboard, 5000);
}

function stopDashboardRefresh() {
    if (dashboardRefreshInterval) {
        clearInterval(dashboardRefreshInterval);
        dashboardRefreshInterval = null;
    }
}