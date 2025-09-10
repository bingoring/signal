package com.signal.app.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

object ChatShadows {
    val SoftElevation = 2.dp
    val SoftColor = Color(0x10000000)
    
    val MediumElevation = 4.dp
    val MediumColor = Color(0x15000000)
    
    val StrongElevation = 8.dp
    val StrongColor = Color(0x20000000)
    
    // Predefined shadow configurations
    val Card = SoftElevation
    val Popup = MediumElevation
    val Modal = StrongElevation
}