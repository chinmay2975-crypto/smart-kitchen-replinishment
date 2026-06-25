package com.smartkitchen.data.api

import com.smartkitchen.data.model.*
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST

interface ApiService {
    @POST("api/v1/auth/register")
    suspend fun register(@Body req: RegisterRequest): Response<AuthResponse>

    @POST("api/v1/auth/login")
    suspend fun login(@Body req: LoginRequest): Response<AuthResponse>

    @GET("api/v1/profile")
    suspend fun getProfile(@Header("Authorization") auth: String): Response<UserProfile>

    @GET("api/v1/devices")
    suspend fun getDevices(@Header("Authorization") auth: String): Response<List<DeviceInfo>>

    @POST("api/v1/devices/claim")
    suspend fun claimDevice(
        @Header("Authorization") auth: String,
        @Body req: ClaimDeviceRequest
    ): Response<DeviceInfo>
}