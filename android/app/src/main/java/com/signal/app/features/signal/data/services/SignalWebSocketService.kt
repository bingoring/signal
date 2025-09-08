package com.signal.app.features.signal.data.services

import android.util.Log
import com.google.gson.Gson
import com.signal.app.features.signal.data.models.Signal
import com.signal.app.features.signal.data.models.SignalWithDistance
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import okhttp3.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Signal WebSocket 서비스
 * Flutter SignalWebSocketService와 동일한 기능을 Android에서 제공
 */
@Singleton
class SignalWebSocketService @Inject constructor(
    private val okHttpClient: OkHttpClient,
    private val gson: Gson
) {
    private var webSocket: WebSocket? = null
    private var listener: WebSocketListener? = null
    
    companion object {
        private const val TAG = "SignalWebSocketService"
        private const val WS_BASE_URL = "ws://localhost:8080" // 실제 서버 URL로 변경 필요
    }

    /**
     * WebSocket 연결
     */
    fun connect(userId: String? = null): Flow<WebSocketMessage> = callbackFlow {
        val url = if (userId != null) {
            "$WS_BASE_URL/ws/signals?user_id=$userId"
        } else {
            "$WS_BASE_URL/ws/signals"
        }

        val request = Request.Builder()
            .url(url)
            .build()

        listener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket 연결 성공")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "WebSocket 메시지 수신: $text")
                try {
                    val message = parseWebSocketMessage(text)
                    if (message != null) {
                        trySend(message)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "메시지 파싱 실패: ${e.message}")
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket 연결 종료 중: $code, $reason")
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket 연결 종료됨: $code, $reason")
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket 연결 실패: ${t.message}")
                close(t)
            }
        }

        webSocket = okHttpClient.newWebSocket(request, listener!!)

        awaitClose {
            disconnect()
        }
    }

    /**
     * WebSocket 메시지 파싱
     */
    private fun parseWebSocketMessage(text: String): WebSocketMessage? {
        return try {
            val data = gson.fromJson(text, Map::class.java) as Map<String, Any>
            val type = data["type"] as? String ?: return null

            when (type) {
                "signal_created" -> {
                    val signalData = data["signal"] as? Map<String, Any>
                    if (signalData != null) {
                        val signalWithDistance = gson.fromJson(
                            gson.toJson(signalData), 
                            SignalWithDistance::class.java
                        )
                        WebSocketMessage.SignalCreated(signalWithDistance)
                    } else null
                }
                "signal_updated" -> {
                    val signalData = data["signal"] as? Map<String, Any>
                    if (signalData != null) {
                        val signalWithDistance = gson.fromJson(
                            gson.toJson(signalData), 
                            SignalWithDistance::class.java
                        )
                        WebSocketMessage.SignalUpdated(signalWithDistance)
                    } else null
                }
                "signal_deleted" -> {
                    val signalId = (data["signal_id"] as? Double)?.toInt()
                    if (signalId != null) {
                        WebSocketMessage.SignalDeleted(signalId)
                    } else null
                }
                "signal_joined" -> {
                    val signalId = (data["signal_id"] as? Double)?.toInt()
                    val currentParticipants = (data["current_participants"] as? Double)?.toInt()
                    val userId = (data["user_id"] as? Double)?.toInt()
                    val userName = data["user_name"] as? String
                    if (signalId != null && currentParticipants != null) {
                        WebSocketMessage.SignalJoined(signalId, currentParticipants, userId, userName)
                    } else null
                }
                "signal_left" -> {
                    val signalId = (data["signal_id"] as? Double)?.toInt()
                    val currentParticipants = (data["current_participants"] as? Double)?.toInt()
                    val userId = (data["user_id"] as? Double)?.toInt()
                    val userName = data["user_name"] as? String
                    if (signalId != null && currentParticipants != null) {
                        WebSocketMessage.SignalLeft(signalId, currentParticipants, userId, userName)
                    } else null
                }
                "location_update_response" -> {
                    val status = data["status"] as? String
                    val nearbyCount = (data["nearby_signals_count"] as? Double)?.toInt()
                    WebSocketMessage.LocationUpdateResponse(status ?: "unknown", nearbyCount)
                }
                "error" -> {
                    val message = data["message"] as? String ?: "Unknown error"
                    WebSocketMessage.Error(message)
                }
                else -> {
                    Log.w(TAG, "알 수 없는 메시지 타입: $type")
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "메시지 파싱 중 오류: ${e.message}")
            null
        }
    }

    /**
     * 위치 업데이트 전송
     */
    fun sendLocationUpdate(latitude: Double, longitude: Double, radius: Double = 1000.0) {
        val message = mapOf(
            "type" to "location_update",
            "latitude" to latitude,
            "longitude" to longitude,
            "radius" to radius
        )
        sendMessage(gson.toJson(message))
    }

    /**
     * 메시지 전송
     */
    fun sendMessage(message: String): Boolean {
        return webSocket?.send(message) ?: false
    }

    /**
     * WebSocket 연결 해제
     */
    fun disconnect() {
        webSocket?.close(1000, "Manual disconnect")
        webSocket = null
        listener = null
    }

    /**
     * 연결 상태 확인
     */
    fun isConnected(): Boolean {
        return webSocket != null
    }
}

/**
 * WebSocket 메시지 타입
 */
sealed class WebSocketMessage {
    data class SignalCreated(val signal: SignalWithDistance) : WebSocketMessage()
    data class SignalUpdated(val signal: SignalWithDistance) : WebSocketMessage()
    data class SignalDeleted(val signalId: Int) : WebSocketMessage()
    data class SignalJoined(
        val signalId: Int, 
        val currentParticipants: Int,
        val userId: Int? = null,
        val userName: String? = null
    ) : WebSocketMessage()
    data class SignalLeft(
        val signalId: Int, 
        val currentParticipants: Int,
        val userId: Int? = null,
        val userName: String? = null
    ) : WebSocketMessage()
    data class LocationUpdateResponse(
        val status: String,
        val nearbyCount: Int? = null
    ) : WebSocketMessage()
    data class Error(val message: String) : WebSocketMessage()
}