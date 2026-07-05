// Devices functions
let devicesRefreshInterval = null;

function startDevicesRefresh() {
    if (devicesRefreshInterval) clearInterval(devicesRefreshInterval);
    devicesRefreshInterval = setInterval(loadDevices, 5000);
}

function stopDevicesRefresh() {
    if (devicesRefreshInterval) {
        clearInterval(devicesRefreshInterval);
        devicesRefreshInterval = null;
    }
}

async function loadDevices() {
    if (!api.isAuthenticated()) {
        console.warn('Devices load skipped: no auth token available');
        return;
    }

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

    grid.innerHTML = devices.map(device => createContainerCard(device)).join('');
}

function buildContainerSvg(uid, fillPct, markerPct, isLow) {
    // Body interior spans y=22..130 (height 108) inside a 96x140 viewBox.
    const bodyTop = 22;
    const bodyHeight = 108;
    const bodyBottom = bodyTop + bodyHeight;
    const fillHeight = bodyHeight * (Math.max(0, Math.min(100, fillPct)) / 100);
    const fillY = bodyBottom - fillHeight;
    const markerY = markerPct !== null ? bodyBottom - bodyHeight * (Math.min(100, markerPct) / 100) : null;
    const borderColor = isLow ? '#ef4444' : '#94a3b8';
    const ticks = [25, 50, 75].map(p => {
        const y = bodyBottom - bodyHeight * (p / 100);
        return `<line x1="10" y1="${y}" x2="15" y2="${y}" stroke="#cbd5e1" stroke-width="1.5"/>`;
    }).join('');

    // A subtle wavy line right at the fill surface so it reads as loose
    // material settling rather than a flat, static block of color.
    const waveTop = fillHeight > 0 ? fillY : null;

    return `
        <svg width="96" height="140" viewBox="0 0 96 140" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <pattern id="grain-${uid}" width="7" height="7" patternUnits="userSpaceOnUse">
                    <rect width="7" height="7" fill="#ecdfc0"/>
                    <ellipse cx="2" cy="2" rx="1.4" ry="0.8" fill="#cbb583"/>
                    <ellipse cx="5" cy="5" rx="1.4" ry="0.8" fill="#cbb583"/>
                </pattern>
                <linearGradient id="shade-${uid}" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stop-color="#ffffff" stop-opacity="0.35"/>
                    <stop offset="15%" stop-color="#ffffff" stop-opacity="0"/>
                    <stop offset="100%" stop-color="#8a7541" stop-opacity="0.25"/>
                </linearGradient>
                <clipPath id="clip-${uid}">
                    <rect x="11" y="${bodyTop}" width="74" height="${bodyHeight}" rx="6"/>
                </clipPath>
            </defs>

            <!-- lid -->
            <rect x="30" y="0" width="36" height="8" rx="3" fill="#e2e8f0" stroke="#94a3b8" stroke-width="1"/>
            <rect x="17" y="6" width="62" height="14" rx="4" fill="#cbd5e1" stroke="#94a3b8" stroke-width="1"/>

            <!-- body outline -->
            <rect x="11" y="${bodyTop}" width="74" height="${bodyHeight}" rx="6" fill="#f8fafc" stroke="${borderColor}" stroke-width="2"/>

            <!-- fill -->
            <g clip-path="url(#clip-${uid})">
                <rect x="11" y="${fillY}" width="74" height="${fillHeight}" fill="url(#grain-${uid})"/>
                <rect x="11" y="${fillY}" width="74" height="${fillHeight}" fill="url(#shade-${uid})"/>
                ${waveTop !== null ? `<path d="M 11 ${waveTop} Q 28 ${waveTop - 2.5} 48 ${waveTop} T 85 ${waveTop}" fill="none" stroke="#8a7541" stroke-opacity="0.4" stroke-width="1.5"/>` : ''}
            </g>

            <!-- glass highlight for a less flat look -->
            <rect x="15" y="${bodyTop + 4}" width="6" height="${bodyHeight - 8}" rx="3" fill="#ffffff" opacity="0.25"/>

            <!-- measurement ticks -->
            ${ticks}

            <!-- reorder marker -->
            ${markerY !== null ? `<line x1="11" y1="${markerY}" x2="85" y2="${markerY}" stroke="#ef4444" stroke-width="1.5" stroke-dasharray="4 2"/>` : ''}

            <!-- re-draw outline on top so the fill/clip doesn't bleed over the border -->
            <rect x="11" y="${bodyTop}" width="74" height="${bodyHeight}" rx="6" fill="none" stroke="${borderColor}" stroke-width="2"/>
        </svg>
    `;
}

function createContainerCard(device) {
    const current = device.current_quantity;
    const reorderLevel = device.reorder_level;
    const capacity = reorderLevel ? reorderLevel * 2 : Math.max(current || 0, 100);
    const fillPct = current != null ? (current / capacity) * 100 : 0;
    const markerPct = reorderLevel != null ? (reorderLevel / capacity) * 100 : null;
    const isLow = reorderLevel != null && current != null && current < reorderLevel;
    const safeName = device.device_name.replace(/'/g, "\\'");
    const uid = device.device_id.replace(/[^a-zA-Z0-9]/g, '');

    return `
        <div class="device-card bg-white rounded-xl shadow-sm p-5 border border-gray-100 relative">
            <button onclick="event.stopPropagation(); handleDeleteDevice('${device.device_id}', '${safeName}')" class="absolute top-3 right-3 text-gray-300 hover:text-red-500 transition z-10" title="Delete device">
                <i class="fas fa-trash"></i>
            </button>
            ${isLow ? '<span class="absolute top-3 left-3 bg-red-100 text-red-600 text-xs font-semibold px-2 py-0.5 rounded-full z-10">Low</span>' : ''}
            <div class="cursor-pointer" onclick="showDeviceDetail('${device.device_id}')">
                <div class="flex justify-center mb-2 mt-2">
                    ${buildContainerSvg(uid, fillPct, markerPct, isLow)}
                </div>
                <h4 class="font-semibold text-gray-800 text-center">${device.device_name}</h4>
                <span class="text-xs text-gray-500 block text-center mb-2">${device.device_type}</span>
                <div class="text-center mb-2">
                    ${current != null
                        ? `<span class="text-lg font-bold ${isLow ? 'text-red-600' : 'text-gray-800'}">${current.toFixed(0)}g</span>`
                        : '<span class="text-sm text-gray-400">No readings yet</span>'}
                    ${reorderLevel != null ? `<div class="text-xs text-gray-400">Reorder below ${reorderLevel}g</div>` : ''}
                </div>
                <div class="flex items-center justify-center space-x-2 mb-2">
                    <span class="online-dot ${device.is_online ? 'online' : 'offline'}"></span>
                    <span class="text-xs ${device.is_online ? 'text-emerald-600' : 'text-gray-400'}">
                        ${device.is_online ? 'Online' : 'Offline'}
                    </span>
                </div>
                <div class="pt-2 border-t border-gray-100 text-center">
                    <span class="text-emerald-600 text-sm font-medium">View Details →</span>
                </div>
            </div>
        </div>
    `;
}

async function handleDeleteDevice(deviceId, deviceName) {
    if (!confirm(`Delete device "${deviceName}"? This cannot be undone.`)) {
        return;
    }

    try {
        const response = await api.deleteDevice(deviceId);
        if (response.ok) {
            showToast(`Device "${deviceName}" deleted`, 'success');
            loadDevices();
            loadDashboard();
        } else {
            const data = await response.json().catch(() => ({}));
            showToast(data.detail || 'Failed to delete device', 'error');
        }
    } catch (error) {
        console.error('Error deleting device:', error);
        showToast('Network error while deleting device', 'error');
    }
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
    const reorderLevelRaw = document.getElementById('claim-reorder-level').value;
    const reorderQuantityRaw = document.getElementById('claim-reorder-quantity').value;
    const reorderLevel = reorderLevelRaw !== '' ? parseFloat(reorderLevelRaw) : null;
    const reorderQuantity = reorderQuantityRaw !== '' ? parseFloat(reorderQuantityRaw) : null;

    const submitBtn = event.target.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Claiming...';

    try {
        const response = await api.claimDevice(uid, name, reorderLevel, reorderQuantity);
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

        // Fetch telemetry data
        const telemetryResponse = await api.getDeviceTelemetry(deviceId, 50);
        let telemetryData = [];
        let summary = null;
        
        if (telemetryResponse.ok) {
            const telemetryResult = await telemetryResponse.json();
            telemetryData = telemetryResult.telemetry || [];
            summary = telemetryResult.summary;
        }

        // Create a modal-like detail view with chart
        const detailHtml = `
            <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onclick="event.target === this && closeDetail()">
                <div class="bg-white rounded-2xl shadow-2xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
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
                            <div>
                                <span class="text-xs text-gray-500">Reorder Level</span>
                                <p class="font-medium">${device.reorder_level ?? 'Not set'}</p>
                            </div>
                            <div>
                                <span class="text-xs text-gray-500">Reorder Quantity</span>
                                <p class="font-medium">${device.reorder_quantity ?? 'Not set'}</p>
                            </div>
                            <div>
                                <span class="text-xs text-gray-500">Current Quantity</span>
                                <p class="font-medium">${device.current_quantity != null ? `${device.current_quantity.toFixed(0)}g` : 'No data'}</p>
                            </div>
                        </div>

                        ${summary ? `
                        <div class="grid grid-cols-5 gap-3 mb-4">
                            <div class="bg-blue-50 p-3 rounded-lg text-center">
                                <div class="text-xs text-gray-500">Readings</div>
                                <div class="text-lg font-bold text-blue-600">${summary.count}</div>
                            </div>
                            <div class="bg-green-50 p-3 rounded-lg text-center">
                                <div class="text-xs text-gray-500">Latest</div>
                                <div class="text-lg font-bold text-green-600">${summary.latest?.toFixed(1) || 'N/A'}</div>
                            </div>
                            <div class="bg-yellow-50 p-3 rounded-lg text-center">
                                <div class="text-xs text-gray-500">Average</div>
                                <div class="text-lg font-bold text-yellow-600">${summary.avg?.toFixed(1) || 'N/A'}</div>
                            </div>
                            <div class="bg-purple-50 p-3 rounded-lg text-center">
                                <div class="text-xs text-gray-500">Min</div>
                                <div class="text-lg font-bold text-purple-600">${summary.min?.toFixed(1) || 'N/A'}</div>
                            </div>
                            <div class="bg-red-50 p-3 rounded-lg text-center">
                                <div class="text-xs text-gray-500">Max</div>
                                <div class="text-lg font-bold text-red-600">${summary.max?.toFixed(1) || 'N/A'}</div>
                            </div>
                        </div>
                        ` : ''}

                        <h4 class="font-semibold text-gray-700 mb-2">Weight Telemetry Over Time</h4>
                        <div class="mb-4 bg-white border border-gray-200 rounded-lg p-4">
                            <canvas id="telemetry-chart" height="80"></canvas>
                        </div>

                        <h4 class="font-semibold text-gray-700 mb-2">Recent Readings</h4>
                        <div class="mb-4 max-h-48 overflow-y-auto">
                            ${telemetryData.length > 0 ? telemetryData.slice(0, 10).map(t => `
                                <div class="flex justify-between py-2 border-b border-gray-100 text-sm">
                                    <span class="text-gray-600">${t.sensor_type}</span>
                                    <span class="font-medium">${t.value.toFixed(2)} ${t.unit}</span>
                                    <span class="text-gray-400 text-xs">${new Date(t.recorded_at).toLocaleTimeString()}</span>
                                </div>
                            `).join('') : '<p class="text-gray-400 text-sm">No telemetry data yet. Data will appear as the device receives readings.</p>'}
                        </div>

                        <div class="mb-4 p-4 bg-amber-50 rounded-lg border border-amber-100">
                            <h4 class="font-semibold text-gray-700 mb-2">Send Test Reading</h4>
                            <p class="text-xs text-gray-500 mb-2">
                                Reorder level: ${device.reorder_level ?? 'not set'}.
                                Submitting a value below it will add an item to your Cart.
                            </p>
                            <div class="flex space-x-2">
                                <input type="number" id="test-reading-value" min="0" step="0.01" placeholder="e.g. 50" class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none">
                                <button onclick="sendTestReading('${device.device_id}')" class="bg-amber-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-amber-700 transition">
                                    <i class="fas fa-paper-plane mr-1"></i>Send
                                </button>
                            </div>
                        </div>

                        <button onclick="generateDemoData('${device.device_id}')" class="w-full bg-emerald-600 text-white py-2 rounded-lg font-medium hover:bg-emerald-700 transition mb-2">
                            <i class="fas fa-magic mr-1"></i>Generate Demo Data
                        </button>
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

        // Render chart if telemetry data exists
        if (telemetryData.length > 0) {
            renderTelemetryChart(telemetryData);
        }
    } catch (error) {
        showToast('Failed to load device details', 'error');
    }
}

async function sendTestReading(deviceId) {
    const input = document.getElementById('test-reading-value');
    const value = parseFloat(input.value);

    if (isNaN(value) || value < 0) {
        showToast('Enter a valid non-negative reading value', 'error');
        return;
    }

    try {
        const response = await api.sendDeviceReading(deviceId, value);
        const data = await response.json();

        if (response.ok) {
            showToast(`Reading ${value} sent successfully!`, 'success');
            input.value = '';
            loadCart();
            closeDetail();
            showDeviceDetail(deviceId);
        } else {
            showToast(data.detail || 'Failed to send reading', 'error');
        }
    } catch (error) {
        console.error('Error sending test reading:', error);
        showToast('Network error while sending reading', 'error');
    }
}

function renderTelemetryChart(telemetryData) {
    const ctx = document.getElementById('telemetry-chart');
    if (!ctx) return;

    // Reverse data to show chronological order (oldest to newest)
    const reversedData = [...telemetryData].reverse();
    
    const labels = reversedData.map(t => new Date(t.recorded_at).toLocaleTimeString());
    const values = reversedData.map(t => t.value);

    new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Weight (grams)',
                data: values,
                borderColor: 'rgb(16, 185, 129)',
                backgroundColor: 'rgba(16, 185, 129, 0.1)',
                tension: 0.4,
                fill: true,
                pointRadius: 3,
                pointHoverRadius: 5,
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return context.parsed.y.toFixed(2) + ' grams';
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: false,
                    ticks: {
                        callback: function(value) {
                            return value + 'g';
                        }
                    }
                },
                x: {
                    ticks: {
                        maxRotation: 45,
                        minRotation: 45
                    }
                }
            }
        }
    });
}

async function generateDemoData(deviceId) {
    try {
        showToast('Generating demo data...', 'info');
        
        // Use the new demo generation endpoint with force=true to regenerate
        const response = await api.generateDemoData(true);
        const data = await response.json();
        
        if (response.ok) {
            showToast(data.message, 'success');
            // Refresh the device detail view after 1 second
            setTimeout(() => {
                closeDetail();
                showDeviceDetail(deviceId);
            }, 1000);
        } else {
            showToast(data.detail || data.message || 'Failed to generate demo data', 'error');
        }
    } catch (error) {
        console.error('Error generating demo data:', error);
        showToast('Failed to generate demo data. Please check your connection.', 'error');
    }
}

function closeDetail() {
    const modal = document.getElementById('device-detail-modal');
    if (modal) {
        modal.remove();
    }
}
