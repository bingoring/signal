package com.signal.app.core.services

import android.content.Intent
import android.net.Uri
import com.signal.app.features.auth.data.services.AuthService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeepLinkService @Inject constructor(
    private val authService: AuthService
) {
    private var onAuthSuccess: ((String, Boolean) -> Unit)? = null
    private var onAuthError: ((String) -> Unit)? = null

    fun setAuthCallbacks(
        onSuccess: ((String, Boolean) -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        onAuthSuccess = onSuccess
        onAuthError = onError
    }

    fun handleIntent(intent: Intent?) {
        intent?.let { 
            if (Intent.ACTION_VIEW == it.action) {
                val uri = it.data
                uri?.let { deepLinkUri ->
                    handleDeepLink(deepLinkUri)
                }
            }
        }
    }

    private fun handleDeepLink(uri: Uri) {
        when (uri.path) {
            "/auth/verify" -> {
                val token = uri.getQueryParameter("token")
                if (token != null) {
                    handleAuthVerification(token)
                } else {
                    onAuthError?.invoke("Invalid authentication link")
                }
            }
        }
    }

    private fun handleAuthVerification(token: String) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val response = authService.verifyMagicLink(token)
                CoroutineScope(Dispatchers.Main).launch {
                    onAuthSuccess?.invoke(response.token, response.isNewUser)
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    onAuthError?.invoke(e.message?.replace("Exception: ", "") ?: "Authentication failed")
                }
            }
        }
    }
}