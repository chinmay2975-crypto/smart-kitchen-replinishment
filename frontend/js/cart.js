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
    const badge = document.getElementById('cart-count-badge');
    if (badge) {
        if (items.length > 0) {
            badge.textContent = items.length;
            badge.classList.remove('hidden');
        } else {
            badge.classList.add('hidden');
        }
    }

    const container = document.getElementById('cart-items-container');
    const checkoutBtn = document.getElementById('checkout-cart-btn');
    if (!container) return;

    if (items.length === 0) {
        container.innerHTML = `
            <div class="col-span-full text-center py-12">
                <div class="text-6xl mb-4">🛒</div>
                <h3 class="text-xl font-semibold text-gray-700 mb-2">Your Cart is Empty</h3>
                <p class="text-gray-500">Items will be added automatically when a container's reading drops below its reorder level.</p>
            </div>
        `;
        if (checkoutBtn) checkoutBtn.disabled = true;
        return;
    }

    if (checkoutBtn) checkoutBtn.disabled = false;

    container.innerHTML = items.map(item => `
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
            <p class="text-xs text-gray-400 mt-2">Added: ${new Date(item.created_at).toLocaleString()}</p>
        </div>
    `).join('');
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
            showToast(`${data.items_placed} item(s) placed! Estimated delivery: ${data.estimated_delivery}`, 'success');
            loadCart();
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
