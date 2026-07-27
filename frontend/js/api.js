// API Configuration and Client
// For local development, use: 'http://localhost:8000
// For production (Cloud Run), use: 'https://smart-kitchen-api-309488529038.asia-south1.run.app'
const API_BASE = 'https://smart-kitchen-api-309488529038.asia-south1.run.app';

class ApiClient {
    constructor() {
        this.token = localStorage.getItem('access_token');
        this.refreshToken = localStorage.getItem('refresh_token');
    }

    setTokens(access, refresh) {
        this.token = access;
        this.refreshToken = refresh;
        localStorage.setItem('access_token', access);
        localStorage.setItem('refresh_token', refresh);
    }

    clearTokens() {
        this.token = null;
        this.refreshToken = null;
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        localStorage.removeItem('user_data');
    }

    isAuthenticated() {
        return !!this.token;
    }

    async parseResponse(response) {
        const contentType = response.headers.get('content-type') || '';
        try {
            if (contentType.includes('application/json')) {
                return await response.json();
            }

            const text = await response.text();
            return text ? { detail: text } : {};
        } catch (error) {
            console.error('Failed to parse API response:', error);
            return { detail: 'Server returned an unreadable response' };
        }
    }

    getErrorMessage(data, fallback = 'Request failed') {
        if (!data) return fallback;
        if (typeof data.detail === 'string') return data.detail;
        if (Array.isArray(data.detail)) {
            return data.detail
                .map(error => {
                    const location = Array.isArray(error.loc) ? error.loc.join('.') : '';
                    return `${location ? `${location}: ` : ''}${error.msg || 'Invalid value'}`;
                })
                .join('\n');
        }
        if (typeof data.message === 'string') return data.message;
        if (typeof data.error === 'string') return data.error;
        return fallback;
    }

    async request(endpoint, options = {}) {
        const url = `${API_BASE}${endpoint}`;
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers,
        };

        // Fallback: re-read token from localStorage if in-memory token is missing
        if (!this.token) {
            this.token = localStorage.getItem('access_token');
            this.refreshToken = localStorage.getItem('refresh_token');
        }

        if (this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
        }

        try {
            const response = await fetch(url, {
                ...options,
                headers,
            });

            const isAuthEndpoint = endpoint.startsWith('/api/v1/auth/login')
                || endpoint.startsWith('/api/v1/auth/register')
                || endpoint.startsWith('/api/v1/auth/refresh');

            if (response.status === 401 && this.refreshToken && !isAuthEndpoint) {
                // Try to refresh the token
                const refreshed = await this.refreshAccessToken();
                if (refreshed) {
                    headers['Authorization'] = `Bearer ${this.token}`;
                    const retryResponse = await fetch(url, {
                        ...options,
                        headers,
                    });
                    return retryResponse;
                }
            }

            return response;
        } catch (error) {
            console.error('API request failed:', error);
            // Check if it's a network error (server unreachable)
            if (error instanceof TypeError && error.message === 'Failed to fetch') {
                console.error('Network error: Backend server may be unreachable at', API_BASE);
                // Return a synthetic response so the caller can handle it gracefully
                return new Response(
                    JSON.stringify({ detail: 'Unable to reach the server. Please check your internet connection and try again.' }),
                    { status: 503, headers: { 'Content-Type': 'application/json' } }
                );
            }
            throw error;
        }
    }

    async refreshAccessToken() {
        try {
            const response = await fetch(`${API_BASE}/api/v1/auth/refresh`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ refresh_token: this.refreshToken }),
            });

            if (response.ok) {
                const data = await response.json();
                this.setTokens(data.access_token, data.refresh_token);
                return true;
            }
        } catch (error) {
            console.error('Token refresh failed:', error);
        }
        this.clearTokens();
        return false;
    }

    // Auth endpoints
    async register(name, email, phone, password) {
        const response = await this.request('/api/v1/auth/register', {
            method: 'POST',
            body: JSON.stringify({ name, email, phone, password }),
        });
        return response;
    }

    async login(email, password) {
        const response = await this.request('/api/v1/auth/login', {
            method: 'POST',
            body: JSON.stringify({ email, password }),
        });
        return response;
    }

    // Devices
    async getDevices() {
        const response = await this.request('/api/v1/devices/');
        return response;
    }

    async getDeviceDetail(deviceId) {
        const response = await this.request(`/api/v1/devices/${deviceId}`);
        return response;
    }

    async claimDevice(deviceUid, deviceName, reorderLevel = null, reorderQuantity = null, zohoItemId = null) {
        const response = await this.request('/api/v1/devices/claim', {
            method: 'POST',
            body: JSON.stringify({
                device_uid: deviceUid,
                device_name: deviceName,
                reorder_level: reorderLevel,
                reorder_quantity: reorderQuantity,
                zoho_item_id: zohoItemId,
            }),
        });
        return response;
    }

    async directCheckout(itemId, quantity) {
        const response = await this.request('/api/v1/checkout', {
            method: 'POST',
            body: JSON.stringify({
                item_id: itemId,
                quantity: quantity,
            }),
        });
        return response;
    }

    async getDeviceTelemetry(deviceId, limit = 50) {
        const response = await this.request(`/api/v1/devices/${deviceId}/telemetry?limit=${limit}`);
        return response;
    }

    async sendDeviceReading(deviceId, readingValue) {
        const response = await this.request('/api/v1/device/reading', {
            method: 'POST',
            body: JSON.stringify({ device_id: deviceId, reading_value: readingValue }),
        });
        return response;
    }

    async deleteDevice(deviceId) {
        const response = await this.request(`/api/v1/devices/${deviceId}`, {
            method: 'DELETE',
        });
        return response;
    }

    // Profile
    async getProfile() {
        const response = await this.request('/api/v1/profile');
        return response;
    }

// Demo data generation
    async generateDemoData(force = false) {
        const response = await this.request(`/api/v1/demo/generate?force=${force}`, {
            method: 'POST',
        });
        return response;
    }

    // Cart
    async getCart() {
        const response = await this.request('/api/v1/cart');
        return response;
    }

    async checkoutCart() {
        const response = await this.request('/api/v1/cart/checkout', {
            method: 'POST',
        });
        return response;
    }

    async markOrderDelivered(cartItemId) {
        const response = await this.request(`/api/v1/cart/${cartItemId}/deliver`, {
            method: 'POST',
        });
        return response;
    }

    async updateCartItemPrice(cartItemId, unitPrice) {
        const response = await this.request(`/api/v1/cart/${cartItemId}/price`, {
            method: 'PATCH',
            body: JSON.stringify({ unit_price: unitPrice }),
        });
        return response;
    }
}

// Global API instance
const api = new ApiClient();
