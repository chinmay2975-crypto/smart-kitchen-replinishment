// Authentication functions

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = 'fixed bottom-4 right-4 text-white px-6 py-3 rounded-lg shadow-lg z-50';
    if (type === 'error') {
        toast.classList.add('bg-red-600');
    } else if (type === 'warning') {
        toast.classList.add('bg-yellow-600');
    } else {
        toast.classList.add('bg-gray-800');
    }
    toast.classList.remove('hidden');
    setTimeout(() => toast.classList.add('hidden'), 3000);
}

function showFormMessage(elementId, message, type = 'error') {
    const messageEl = document.getElementById(elementId);
    if (!messageEl) return;

    messageEl.textContent = message || '';
    messageEl.className = 'mb-4 rounded-lg px-4 py-3 text-sm';

    if (type === 'success') {
        messageEl.classList.add('bg-emerald-50', 'text-emerald-700', 'border', 'border-emerald-200');
    } else {
        messageEl.classList.add('bg-red-50', 'text-red-700', 'border', 'border-red-200');
    }

    messageEl.classList.toggle('hidden', !message);
}

function clearAuthMessages() {
    showFormMessage('login-error', '');
    showFormMessage('register-error', '');
}

function showPage(pageId) {
    document.querySelectorAll('#auth-page > div').forEach(div => div.classList.add('hidden'));
    document.getElementById(pageId).classList.remove('hidden');
    clearAuthMessages();
}

async function handleRegister(event) {
    event.preventDefault();
    clearAuthMessages();
    const name = document.getElementById('reg-name').value;
    const email = document.getElementById('reg-email').value;
    const phone = document.getElementById('reg-phone').value;
    const password = document.getElementById('reg-password').value;
    const confirm = document.getElementById('reg-confirm').value;

    if (password !== confirm) {
        showFormMessage('register-error', 'Passwords do not match');
        showToast('Passwords do not match', 'error');
        return;
    }

    const submitBtn = event.target.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Registering...';

    try {
        const response = await api.register(name, email, phone, password);
        const data = await api.parseResponse(response);

        if (response.ok) {
            api.setTokens(data.access_token, data.refresh_token);
            localStorage.setItem('user_data', JSON.stringify(data));
            showToast('Registration successful!');
            enterApp(data);
        } else {
            const message = api.getErrorMessage(data, 'Registration failed');
            showFormMessage('register-error', message);
            showToast(message, 'error');
        }
    } catch (error) {
        console.error('Registration error:', error);
        const message = 'Network error. Please check your internet connection and try again.';
        showFormMessage('register-error', message);
        showToast(message, 'error');
    } finally {
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<i class="fas fa-user-plus mr-2"></i>Register';
    }
}

async function handleLogin(event) {
    event.preventDefault();
    clearAuthMessages();
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;

    const submitBtn = event.target.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Signing In...';

    try {
        const response = await api.login(email, password);
        const data = await api.parseResponse(response);

        if (response.ok) {
            api.setTokens(data.access_token, data.refresh_token);
            localStorage.setItem('user_data', JSON.stringify(data));
            showToast('Login successful!');
            enterApp(data);
        } else {
            const message = api.getErrorMessage(data, 'Login failed');
            showFormMessage('login-error', message);
            showToast(message, 'error');
        }
    } catch (error) {
        console.error('Login error:', error);
        const message = 'Network error. Please check your internet connection and try again.';
        showFormMessage('login-error', message);
        showToast(message, 'error');
    } finally {
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<i class="fas fa-sign-in-alt mr-2"></i>Sign In';
    }
}

function handleLogout() {
    api.clearTokens();
    document.getElementById('main-app').classList.add('hidden');
    document.getElementById('auth-page').classList.remove('hidden');
    showPage('welcome-page');
    showToast('Logged out successfully');
}

function enterApp(userData) {
    document.getElementById('auth-page').classList.add('hidden');
    document.getElementById('main-app').classList.remove('hidden');
    document.getElementById('user-name-display').textContent = userData.name || userData.email;
    
    // Load initial data
    loadDashboard();
    loadDevices();
    loadProfile();
    switchTab('dashboard');
}