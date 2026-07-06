// Main Application Controller

// Register service worker for PWA installability (app-shell caching only,
// never caches /api/ requests — see sw.js).
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .catch((err) => console.warn('Service worker registration failed:', err));
    });
}

function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active', 'text-emerald-600', 'border-emerald-600');
        btn.classList.add('text-gray-500', 'border-transparent');
    });
    const tabBtn = document.getElementById(`tab-${tabName}`);
    if (tabBtn) {
        tabBtn.classList.add('active', 'text-emerald-600', 'border-emerald-600');
        tabBtn.classList.remove('text-gray-500', 'border-transparent');
    }

    // Show/hide content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.add('hidden');
    });
    document.getElementById(`content-${tabName}`).classList.remove('hidden');

    // Start/stop refresh based on active tab
    if (tabName === 'dashboard') {
        loadDashboard();
        startDashboardRefresh();
    } else {
        stopDashboardRefresh();
    }

    if (tabName === 'devices') {
        startDevicesRefresh();
    } else {
        stopDevicesRefresh();
    }

    if (tabName === 'cart') {
        loadCart();
        loadDashboard(); // also populates the Recent Replenishment Orders table
    }
}

// Initialize the app
document.addEventListener('DOMContentLoaded', function() {
    // Check if user is already logged in
    if (api.isAuthenticated()) {
        const userData = localStorage.getItem('user_data');
        if (userData) {
            try {
                const data = JSON.parse(userData);
                enterApp(data);
                return;
            } catch (e) {
                // Invalid stored data, show auth page
            }
        }
    }

    // Show auth page
    document.getElementById('auth-page').classList.remove('hidden');
    showPage('welcome-page');
});

// Close modals on Escape key
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        hideClaimDeviceModal();
        closeDetail();
    }
});