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