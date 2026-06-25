package com.smartkitchen.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.smartkitchen.data.api.RetrofitClient
import com.smartkitchen.data.model.AuthResponse
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import retrofit2.Response

sealed class RegisterState {
    object Idle : RegisterState()
    object Loading : RegisterState()
    data class Success(val data: AuthResponse) : RegisterState()
    data class Error(val message: String) : RegisterState()
}

class RegisterViewModel(application: Application) : AndroidViewModel(application) {
    private val _registerState = MutableStateFlow<RegisterState>(RegisterState.Idle)
    val registerState: StateFlow<RegisterState> = _registerState

    fun register(name: String, email: String, phone: String, password: String) {
        viewModelScope.launch {
            _registerState.value = RegisterState.Loading
            try {
                val response = RetrofitClient.apiService.register(
                    com.smartkitchen.data.model.RegisterRequest(name, email, phone, password)
                )
                if (response.isSuccessful && response.body() != null) {
                    _registerState.value = RegisterState.Success(response.body()!!)
                } else {
                    val errorBody = response.errorBody()?.string() ?: "Unknown error"
                    _registerState.value = RegisterState.Error(errorBody)
                }
            } catch (e: Exception) {
                _registerState.value = RegisterState.Error(e.message ?: "Network error")
            }
        }
    }

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _registerState.value = RegisterState.Loading
            try {
                val response = RetrofitClient.apiService.login(
                    com.smartkitchen.data.model.LoginRequest(email, password)
                )
                if (response.isSuccessful && response.body() != null) {
                    _registerState.value = RegisterState.Success(response.body()!!)
                } else {
                    val errorBody = response.errorBody()?.string() ?: "Unknown error"
                    _registerState.value = RegisterState.Error(errorBody)
                }
            } catch (e: Exception) {
                _registerState.value = RegisterState.Error(e.message ?: "Network error")
            }
        }
    }

    fun resetState() {
        _registerState.value = RegisterState.Idle
    }
}