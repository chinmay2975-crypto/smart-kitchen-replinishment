// Profile functions

async function loadProfile() {
    if (!api.isAuthenticated()) {
        console.warn('Profile load skipped: no auth token available');
        return;
    }

    try {
        const response = await api.getProfile();
        if (!response.ok) {
            if (response.status === 401) {
                handleLogout();
                return;
            }
            throw new Error('Failed to load profile');
        }
        const profile = await response.json();

        document.getElementById('profile-name').textContent = profile.name || 'N/A';
        document.getElementById('profile-email').textContent = profile.email || 'N/A';
        document.getElementById('profile-phone').textContent = profile.phone || 'N/A';
        document.getElementById('profile-role').textContent = profile.role || 'N/A';
        document.getElementById('profile-household').textContent = profile.household?.name || 'N/A';
        document.getElementById('profile-userid').textContent = profile.user_id || 'N/A';
    } catch (error) {
        console.error('Profile load error:', error);
    }

    loadWallet();
}

async function loadWallet() {
    const section = document.getElementById('wallet-section');
    if (!api.isAuthenticated() || !section) return;

    try {
        const response = await api.getWalletBalance();
        if (!response.ok) {
            // Wallet not enabled (or unreachable) — hide the section rather
            // than showing an error for a feature that isn't turned on.
            section.classList.add('hidden');
            return;
        }
        const data = await response.json();
        section.classList.remove('hidden');
        document.getElementById('wallet-balance').textContent = `₹${data.balance.toFixed(2)}`;
    } catch (error) {
        console.error('Wallet load error:', error);
        section.classList.add('hidden');
        return;
    }

    loadPaymentHistory();
}

async function loadPaymentHistory() {
    const section = document.getElementById('payment-history-section');
    const list = document.getElementById('payment-history-list');
    if (!api.isAuthenticated() || !section || !list) return;

    try {
        const response = await api.getWalletTransactions();
        if (!response.ok) {
            section.classList.add('hidden');
            return;
        }
        const transactions = await response.json();
        section.classList.remove('hidden');

        if (transactions.length === 0) {
            list.innerHTML = '<p class="text-sm text-gray-400">No transactions yet.</p>';
            return;
        }

        list.innerHTML = transactions.map(tx => {
            const isCredit = tx.type === 'credit';
            const sign = isCredit ? '+' : '-';
            const colorClass = isCredit ? 'text-green-600' : 'text-red-600';
            const icon = isCredit ? 'fa-arrow-down' : 'fa-arrow-up';
            const dateStr = tx.date ? new Date(tx.date).toLocaleDateString() : '';
            return `
                <div class="flex items-center justify-between py-2 border-b border-gray-100 last:border-0">
                    <div class="flex items-center space-x-3">
                        <i class="fas ${icon} ${colorClass}"></i>
                        <div>
                            <p class="text-sm font-medium text-gray-800">${tx.description}</p>
                            <p class="text-xs text-gray-400">${tx.number || ''}${tx.number && dateStr ? ' • ' : ''}${dateStr}</p>
                        </div>
                    </div>
                    <span class="text-sm font-semibold ${colorClass}">${sign}₹${tx.amount.toFixed(2)}</span>
                </div>
            `;
        }).join('');
    } catch (error) {
        console.error('Payment history load error:', error);
        section.classList.add('hidden');
    }
}

async function handleWalletTopup() {
    const input = document.getElementById('wallet-topup-amount');
    const amount = parseFloat(input.value);

    if (isNaN(amount) || amount <= 0) {
        showToast('Enter a valid positive amount', 'error');
        return;
    }

    const btn = document.getElementById('wallet-topup-btn');
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin mr-1"></i>Adding...';

    try {
        const response = await api.topupWallet(amount);
        const data = await response.json();

        if (response.ok) {
            showToast(`₹${amount.toFixed(2)} added — new balance ₹${data.new_balance.toFixed(2)}`, 'success');
            input.value = '';
            document.getElementById('wallet-balance').textContent = `₹${data.new_balance.toFixed(2)}`;
            loadPaymentHistory();
        } else {
            showToast(data.detail || 'Failed to add credit', 'error');
        }
    } catch (error) {
        console.error('Wallet top-up error:', error);
        showToast('Network error while adding credit', 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = '<i class="fas fa-plus mr-1"></i>Add Credit';
    }
}