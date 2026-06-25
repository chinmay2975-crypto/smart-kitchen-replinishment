// Profile functions

async function loadProfile() {
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
}