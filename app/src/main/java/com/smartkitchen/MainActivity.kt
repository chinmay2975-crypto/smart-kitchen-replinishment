package com.smartkitchen

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Alignment
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.smartkitchen.ui.theme.SmartKitchenTheme
import com.smartkitchen.ui.viewmodel.RegisterState
import com.smartkitchen.ui.viewmodel.RegisterViewModel
import kotlinx.coroutines.flow.collectLatest

class MainActivity : ComponentActivity() {
    private val viewModel: RegisterViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SmartKitchenTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MainScreen(viewModel = viewModel)
                }
            }
        }
    }
}

@Composable
fun MainScreen(viewModel: RegisterViewModel) {
    val registerState = viewModel.registerState.collectAsState()
    val snackBarHostState = remember { SnackbarHostState() }
    val (screenMode, setScreenMode) = remember { mutableStateOf("register") }

    LaunchedEffect(viewModel) {
        viewModel.registerState.collectLatest { state ->
            if (state is RegisterState.Error) {
                snackBarHostState.showSnackbar(state.message)
                viewModel.resetState()
            }
        }
    }

    when (val state = registerState.value) {
        is RegisterState.Success -> {
            WelcomeScreen(name = state.data.name ?: state.data.email)
        }
        else -> {
            Scaffold(snackbarHost = { SnackbarHost(hostState = snackBarHostState) }) {
                screens.RegisterScreen(
                    mode = screenMode,
                    onRegisterClick = { name, email, phone, password ->
                        viewModel.register(name, email, phone, password)
                    },
                    onLoginClick = { email, password ->
                        viewModel.login(email, password)
                    },
                    onModeChange = { mode ->
                        setScreenMode(mode)
                    }
                )
            }
        }
    }
}

@Composable
fun WelcomeScreen(name: String) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        androidx.compose.material3.Text(
            text = "Welcome $name",
            style = MaterialTheme.typography.headlineMedium
        )
    }
}