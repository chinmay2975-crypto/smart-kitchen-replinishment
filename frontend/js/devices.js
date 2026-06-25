// Devices functions

async function loadDevices() {
    try {
        const response = await api.getDevices();
        if (!response.ok) {
            if (response.status === 401) {
                handleLogout();
                return;
            }
            throw new Error('Failed to load devices');
        }
        const devices = await response.json();
        renderDevices(devices);
    } catch (error) {
        console.error('Devices load error:', error);
    }
}

function renderDevices(devices) {
    const grid = document.getElementById('devices-grid');

    if (devices.length === 0) {
        grid.innerHTML = `
            <div class="col-span-full text-center py-12">
                <div class="text-6xl mb-4">📡</div>
                <h3 class="text-xl font-semibold text-gray-700 mb-2">No Devices Yet</h3>
                <p class="text-gray-500 mb-4">Claim a device to start monitoring your kitchen inventory</p>
                <button onclick="showClaimDeviceModal()" class="bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700 transition">
                    <i class="fas fa-plus mr-1"></i>Claim Your First Device
                </button>
            </div>
        `;
        return;
    }

    grid.innerHTML = devices.map(device => `
        <div class="device-card bg-white rounded-xl shadow-sm p-5 border border-gray-100 cursor-pointer" onclick="showDeviceDetail('${device.device_id}')">
            <div class="flex items-start justify-between mb-3">
                <div class="flex items-center space-x-3">
                    <div class="w-12 h-12 bg-emerald-100 rounded-full flex items-center justify-center text-2xl">
                        📱
                    </div>
                    <div>
                        <h4 class="font-semibold text-gray-800">${device.device_name}</h4>
                        <span class="text-xs text-gray-500">${device.device_type}</span>
                    </div>
                </div>
                <div class="flex items-center space-x-2">
                    <span class="online-dot ${device.is_online ? 'online' : 'offline'}"></span>
                    <span class="text-xs ${device.is_online ? 'text-emerald-600' : 'text-gray-400'}">
                        ${device.is_online ? 'Online' : 'Offline'}
                    </span>
                </div>
            </div>
            <div class="text-xs text-gray-400 space-y-1">
                <p><i class="fas fa-tag mr-1"></i>ID: ${device.device_id.substring(0, 8)}...</p>
                <p><i class="fas fa-comment mr-1"></i>Topic: ${device.mqtt_topic || 'N/A'}</p>
                ${device.last_seen_at ? `<p><i class="fas fa-clock mr-1"></i>Last seen: ${new Date(device.last_seen_at).toLocaleString()}</p>` : ''}
            </div>
            <div class="mt-3 pt-3 border-t border-gray-100 text-center">
                <span class="text-emerald-600 text-sm font-medium">View Details →</span>
            </div>
        </div>
    `).join('');
}

function showClaimDeviceModal() {
    document.getElementById('claim-modal').classList.remove('hidden');
}

function hideClaimDeviceModal() {
    document.getElementById('claim-modal').classList.add('hidden');
    document.getElementById('claim-form').reset();
}

async function handleClaimDevice(event) {
    event.preventDefault();
    const uid = document.getElementById('claim-uid').value;
    const name = document.getElementById('claim-name').value;

    const submitBtn = event.target.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Claiming...';

    try {
        const response = await api.claimDevice(uid, name);
        const data = await response.json();

        if (response.ok) {
            showToast(`Device "${name}" claimed successfully!`);
            hideClaimDeviceModal();
            loadDevices();
        } else {
            const detail = data.detail || 'Failed to claim device';
            showToast(detail, 'error');
        }
    } catch (error) {
        showToast('Network error', 'error');
    } finally {
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<i class="fas fa-check mr-1"></i>Claim';
    }
}

async function showDeviceDetail(deviceId) {
    try {
        const response = await api.getDeviceDetail(deviceId);
        if (!response.ok) {
            if (response.status === 401) {
                handleLogout();
                return;
            }
            showToast('Failed to load device details', 'error');
            return;
        }
        const device = await response.json();

        // Create a modal-like detail view
        const telemetryHtml = device.latest_telemetry && device.latest_telemetry.length > 0
            ? device.latest_telemetry.map(t => `
                <div class="flex justify-between py-2 border-b border-gray-100">
                    <span class="text-gray-600">${t.sensor_type}</span>
                    <span class="font-medium">${t.value} ${t.unit}</span>
                </div>
            `).join('')
            : '<p class="text-gray-400 text-sm">No telemetry data yet</p>';

        const detailHtml = `
            <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onclick="event.target === this && closeDetail()">
                <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 max-h-[80vh] overflow-y-auto">
                    <div class="p-6">
                        <div class="flex justify-between items-start mb-4">
                            <div>
                                <h3 class="text-xl font-bold text-gray-800">${device.device_name}</h3>
                                <span class="text-sm text-gray-500">${device.device_type}</span>
                            </div>
                            <button onclick="closeDetail()" class="text-gray-400 hover:text-gray-600">
                                <i class="fas fa-times text-xl"></i>
                            </button>
                        </div>

                        <div class="grid grid-cols-2 gap-4 mb-4 p-4 bg-gray-50 rounded-lg">
                            <div>
                                <span class="text-xs text-gray-500">Status</span>
                                <div class="flex items-center space-x-2">
                                    <span class="online-dot ${device.is_online ? 'online' : 'offline'}"></span>
                                    <span class="font-medium">${device.is_online ? 'Online' : 'Offline'}</span>
                                </div>
                            </div>
                            <div>
                                <span class="text-xs text-gray-500">Firmware</span>
                                <p class="font-medium">${device.firmware_ver || 'N/A'}</p>
                            </div>
                            <div>
                                <span class="text-xs text-gray-500">MQTT Topic</span>
                                <p class="font-medium text-sm">${device.mqtt_topic || 'N/A'}</p>
                            </div>
                            <div>
                                <span class="text-xs text-gray-500">Device ID</span>
                                <p class="font-medium text-xs font-mono">${device.device_id}</p>
                            </div>
                        </div>

                        <h4 class="font-semibold text-gray-700 mb-2">Recent Telemetry</h4>
                        <div class="mb-4">${telemetryHtml}</div>

                        <button onclick="closeDetail()" class="w-full bg-gray-100 text-gray-700 py-2 rounded-lg font-medium hover:bg-gray-200 transition">
                            Close
                        </button>
                    </div>
                </div>
            </div>
        `;

        const detailEl = document.createElement('div');
        detailEl.id = 'device-detail-modal';
        detailEl.innerHTML = detailHtml;
        document.body.appendChild(detailEl);
    } catch (error) {
        showToast('Failed to load device details', 'error');
    }
}

function closeDetail() {
    const modal = document.getElementById('device-detail-modal');
    if (modal) {
        modal.remove();
    }
}