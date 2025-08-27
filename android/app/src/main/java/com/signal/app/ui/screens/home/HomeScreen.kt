package com.signal.app.ui.screens.home

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.navigation.NavController

@Composable
fun HomeScreen(navController: NavController) {
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        Text(
            text = "홈 화면",
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.padding(16.dp)
        )
        
        Button(
            onClick = {
                navController.navigate("create_signal")
            },
            modifier = Modifier.padding(16.dp)
        ) {
            Text("시그널 생성")
        }
    }
}