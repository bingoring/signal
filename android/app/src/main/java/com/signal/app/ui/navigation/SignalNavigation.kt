package com.signal.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.signal.app.ui.screens.auth.LoginScreen
import com.signal.app.ui.screens.home.HomeScreen
import com.signal.app.ui.screens.signal.CreateSignalScreen

@Composable
fun SignalNavigation(navController: NavHostController) {
    NavHost(
        navController = navController,
        startDestination = "login"
    ) {
        // Auth
        composable("login") {
            LoginScreen(navController = navController)
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