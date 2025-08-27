package com.signal.app.ui.screens.signal

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController

@Composable
fun CreateSignalScreen(navController: NavController) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            text = "시그널 생성",
            style = MaterialTheme.typography.headlineMedium
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text("시그널 생성 페이지 - 구현 예정")
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(
            onClick = {
                navController.navigateUp()
            }
        ) {
            Text("뒤로 가기")
        }
    }
}