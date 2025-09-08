package com.signal.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.signal.app.features.auth.presentation.composables.AuthWrapper
import com.signal.app.features.auth.presentation.composables.WelcomeScreen
import com.signal.app.ui.screens.home.HomeScreen
import com.signal.app.ui.screens.signal.CreateSignalScreen

@Composable
fun SignalNavigation(navController: NavHostController) {
    NavHost(
        navController = navController,
        startDestination = "auth"
    ) {
        // Authentication flow
        composable("auth") {
            AuthWrapper(
                navigateToHome = {
                    navController.navigate("home") {
                        popUpTo("auth") { inclusive = true }
                    }
                },
                navigateToWelcome = {
                    navController.navigate("welcome")
                }
            )
        }

        composable("welcome") {
            WelcomeScreen(
                onContinueToApp = {
                    navController.navigate("home") {
                        popUpTo("welcome") { inclusive = true }
                    }
                }
            )
        }
        
        // Main
        composable("home") {
            HomeScreen(navController = navController)
        }
        
        // Signal
        composable("create_signal") {
            CreateSignalScreen(navController = navController)
        }
    }
}