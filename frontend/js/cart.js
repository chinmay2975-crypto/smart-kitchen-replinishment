// Cart functions

async function loadCart() {
    if (!api.isAuthenticated()) {
        console.warn('Cart load skipped: no auth token available');
        return;
    }

    try {
        const response = await api.getCart();
        if (!response.ok) {
            if (response.status === 401) {
                handleLogout();
                return;
            }
            throw new Error('Failed to load cart');
        }
        const items = await response.json();
        renderCart(items);
    } catch (error) {
        console.error('Cart load error:', error);
    }
}

function renderCart(items) {
    const pendingItems = items.filter(item => item.status === 'pending_cart');
    const placedItems = items.filter(item => item.status === 'placed');
    const deliveredItems = items.filter(item => item.status === 'delivered');

    const badge = document.getElementById('cart-count-badge');
    const headerBadge = document.getElementById('header-cart-count-badge');
    [badge, headerBadge].forEach(b => {
        if (!b) return;
        if (pendingItems.length > 0) {
            b.textContent = pendingItems.length;
            b.classList.remove('hidden');
        } else {
            b.classList.add('hidden');
        }
    });

    const pendingContainer = document.getElementById('cart-items-container');
    const placedContainer = document.getElementById('cart-placed-container');
    const deliveredContainer = document.getElementById('cart-delivered-container');
    const checkoutBtn = document.getElementById('checkout-cart-btn');

    if (pendingContainer) {
        if (pendingItems.length === 0) {
            pendingContainer.innerHTML = `
                <div class="col-span-full text-center py-12">
                    <div class="text-6xl mb-4">🛒</div>
                    <h3 class="text-xl font-semibold text-gray-700 mb-2">Your Cart is Empty</h3>
                    <p class="text-gray-500">Items will be added automatically when a container's reading drops below its reorder level.</p>
                </div>
            `;
            if (checkoutBtn) checkoutBtn.disabled = true;
        } else {
            if (checkoutBtn) checkoutBtn.disabled = false;
            pendingContainer.innerHTML = pendingItems.map(item => `
                <div class="cart-item-card bg-white rounded-xl shadow-sm p-5 border border-gray-100">
                    <div class="flex items-start justify-between mb-2">
                        <div class="w-12 h-12 bg-amber-100 rounded-full flex items-center justify-center text-2xl">
                            📦
                        </div>
                        <span class="px-2 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
                            Pending
                        </span>
                    </div>
                    <h4 class="font-semibold text-gray-800">${item.item_name}</h4>
                    <p class="text-sm text-gray-500">Quantity: ${item.quantity}</p>
                    <div class="mt-2">
                        <label class="text-xs text-gray-500 block mb-1">Price for this order</label>
                        <div class="flex space-x-2">
                            <input type="number" min="0" step="0.01" placeholder="e.g. 250"
                                   id="price-input-${item.cart_item_id}"
                                   value="${item.unit_price != null ? item.unit_price : ''}"
                                   class="flex-1 px-2 py-1 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none">
                            <button onclick="handleSavePrice('${item.cart_item_id}')" class="bg-gray-100 text-gray-700 px-3 py-1 rounded-lg text-sm font-medium hover:bg-gray-200 transition">
                                Save
                            </button>
                        </div>
                    </div>
                    <p class="text-xs text-gray-400 mt-2">Added: ${new Date(item.created_at).toLocaleString()}</p>
                </div>
            `).join('');
        }
    }

    if (placedContainer) {
        if (placedItems.length === 0) {
            placedContainer.innerHTML = `
                <div class="col-span-full text-center py-8 text-gray-400">No orders placed yet.</div>
            `;
        } else {
            placedContainer.innerHTML = placedItems.map(item => `
                <div class="cart-item-card bg-white rounded-xl shadow-sm p-5 border border-gray-100">
                    <div class="flex items-start justify-between mb-2">
                        <div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-2xl">
                            🚚
                        </div>
                        <span class="px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-700">
                            Placed
                        </span>
                    </div>
                    <h4 class="font-semibold text-gray-800">${item.item_name}</h4>
                    <p class="text-sm text-gray-500">Quantity: ${item.quantity}</p>
                    ${item.estimated_delivery ? `<p class="text-xs text-blue-600 mt-2"><i class="fas fa-truck mr-1"></i>Delivering by ${item.estimated_delivery}</p>` : ''}
                    <button onclick="handleMarkDelivered('${item.cart_item_id}')" class="w-full mt-3 bg-emerald-600 text-white py-1.5 rounded-lg text-sm font-medium hover:bg-emerald-700 transition">
                        <i class="fas fa-check mr-1"></i>Mark Delivered
                    </button>
                </div>
            `).join('');
        }
    }

    if (deliveredContainer) {
        if (deliveredItems.length === 0) {
            deliveredContainer.innerHTML = `
                <div class="col-span-full text-center py-8 text-gray-400">No deliveries completed yet.</div>
            `;
        } else {
            deliveredContainer.innerHTML = deliveredItems.map(item => `
                <div class="cart-item-card bg-white rounded-xl shadow-sm p-5 border border-gray-100">
                    <div class="flex items-start justify-between mb-2">
                        <div class="w-12 h-12 bg-emerald-100 rounded-full flex items-center justify-center text-2xl">
                            ✅
                        </div>
                        <span class="px-2 py-1 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700">
                            Delivered
                        </span>
                    </div>
                    <h4 class="font-semibold text-gray-800">${item.item_name}</h4>
                    <p class="text-sm text-gray-500">Quantity: ${item.quantity}</p>
                </div>
            `).join('');
        }
    }
}

async function handleSavePrice(cartItemId) {
    const input = document.getElementById(`price-input-${cartItemId}`);
    const value = parseFloat(input.value);

    if (isNaN(value) || value < 0) {
        showToast('Enter a valid non-negative price', 'error');
        return;
    }

    try {
        const response = await api.updateCartItemPrice(cartItemId, value);
        const data = await response.json();

        if (response.ok) {
            showToast('Price saved', 'success');
        } else {
            showToast(data.detail || 'Failed to save price', 'error');
        }
    } catch (error) {
        console.error('Error saving price:', error);
        showToast('Network error while saving price', 'error');
    }
}

async function handleMarkDelivered(cartItemId) {
    try {
        const response = await api.markOrderDelivered(cartItemId);
        const data = await response.json();

        if (response.ok) {
            showToast(`Delivered! Container restocked to ${data.new_quantity}g`, 'success');
            loadCart();
            loadDevices();
            loadDashboard();
        } else {
            showToast(data.detail || 'Failed to mark delivered', 'error');
        }
    } catch (error) {
        console.error('Error marking order delivered:', error);
        showToast('Network error while marking delivered', 'error');
    }
}

async function handleCheckoutCart() {
    const btn = document.getElementById('checkout-cart-btn');
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Placing order...';
    }

    try {
        const response = await api.checkoutCart();
        const data = await response.json();

        if (response.ok) {
            showToast(`${data.items_placed} item(s) checked out and container(s) replenished!`, 'success');
            loadCart();
            loadDevices();
            loadDashboard();
        } else {
            showToast(data.detail || data.message || 'Checkout failed', 'error');
        }
    } catch (error) {
        console.error('Error checking out cart:', error);
        showToast('Network error during checkout', 'error');
    } finally {
        if (btn) {
            btn.innerHTML = '<i class="fas fa-credit-card mr-2"></i>Checkout';
        }
    }
}
