package com.signal.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

object ChatTextStyles {
    // Message text styles
    val MessageText = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 22.4.sp
    )
    
    val MessageTextBold = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        lineHeight = 22.4.sp
    )
    
    // System message
    val SystemText = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 18.2.sp,
        color = ChatColors.TextSecondary
    )
    
    // Timestamp
    val TimestampText = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 12.sp,
        lineHeight = 14.4.sp,
        color = ChatColors.TextSecondary
    )
    
    // AppBar
    val AppBarTitle = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 18.sp,
        lineHeight = 21.6.sp,
        color = ChatColors.TextPrimary
    )
    
    val AppBarSubtitle = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 12.sp,
        lineHeight = 14.4.sp,
        color = ChatColors.Online
    )
    
    // Quick reply
    val QuickReplyText = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
        lineHeight = 18.2.sp,
        color = ChatColors.TextOnPrimary
    )
    
    // Input
    val InputText = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 22.4.sp,
        color = ChatColors.TextPrimary
    )
    
    val InputHint = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 22.4.sp,
        color = ChatColors.TextSecondary
    )
}

val Typography = Typography(
    bodyLarge = ChatTextStyles.MessageText,
    bodyMedium = ChatTextStyles.SystemText,
    bodySmall = ChatTextStyles.TimestampText,
    headlineMedium = ChatTextStyles.AppBarTitle,
    labelMedium = ChatTextStyles.QuickReplyText
)