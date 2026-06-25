package com.smartkitchen.data.model

data class RegisterRequest(
    val name: String,
    val email: String,
    val phone: String,
    val password: String
)

data class LoginRequest(
    val email: String,
    val password: String
)

data class AuthResponse(
    val user_id: String,
    val email: String,
    val household_id: String?,
    val access_token: String,
    val refresh_token: String,
    val name: String? = null,
    val phone: String? = null
)

data class UserProfile(
    val user_id: String,
    val name: String,
    val email: String,
    val phone: String,
    val household: HouseholdInfo?
)

data class HouseholdInfo(
    val household_id: String,
    val name: String?
)

data class DeviceInfo(
    val device_id: String,
    val name: String,
    val type: String
)

data class ClaimDeviceRequest(
    val device_id: String,
    val name: String
)

data class ApiError(
    val detail: String
)