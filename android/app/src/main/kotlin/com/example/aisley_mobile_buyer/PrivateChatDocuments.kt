package com.example.aisley_mobile_buyer

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/** Two-phase SAF export: the system picker never holds private file bytes. */
class PrivateChatDocuments(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "aisley/private_chat_documents")
    private var pending: MethodChannel.Result? = null
    private var chosen: Uri? = null
    private var id: String? = null
    @Volatile private var cancelled = false
    private var writing = false
    private var pickerOpen = false
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "choose" -> {
                    if (pending != null || chosen != null || writing || pickerOpen) {
                        result.error("BUSY", "Finish the current download.", null)
                    } else {
                        cancelled = false
                        pending = result
                        pickerOpen = true
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mimeType") ?: "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("filename") ?: "attachment")
                        }
                        try { activity.startActivityForResult(intent, 8174) }
                        catch (_: Exception) { pending = null; pickerOpen = false; result.error("UNAVAILABLE", "Save picker unavailable.", null) }
                    }
                }
                "write" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val destination = chosen
                    if (cancelled || writing || destination == null || call.argument<String>("id") != id ||
                        bytes == null || bytes.isEmpty() || bytes.size > 10485760) {
                        result.error("UNAVAILABLE", "Download unavailable.", null)
                    } else {
                        writing = true
                        Thread {
                            var ok = false
                            try {
                                activity.contentResolver.openOutputStream(destination, "wt")?.use { stream ->
                                    var offset = 0
                                    while (offset < bytes.size && !cancelled) {
                                        val count = minOf(65536, bytes.size - offset)
                                        stream.write(bytes, offset, count)
                                        offset += count
                                    }
                                    ok = offset == bytes.size && !cancelled
                                }
                            } catch (_: Exception) { }
                            bytes.fill(0)
                            if (!ok) remove(destination)
                            activity.runOnUiThread {
                                writing = false
                                chosen = null; id = null
                                if (ok) result.success(null) else result.error("UNAVAILABLE", "Download unavailable.", null)
                            }
                        }.start()
                    }
                }
                "cancel" -> { cancelled = true; discard(); result.success(null) }
                "release" -> { if (!writing) discard(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    fun result(request: Int, code: Int, data: Intent?): Boolean {
        if (request != 8174) return false
        val reply = pending; pending = null; pickerOpen = false
        val uri = if (code == Activity.RESULT_OK) data?.data else null
        if (reply == null || cancelled) { if (uri != null) remove(uri); reply?.success(null) }
        else if (uri == null) reply.success(null)
        else { chosen = uri; id = UUID.randomUUID().toString(); reply.success(id) }
        return true
    }
    private fun remove(uri: Uri) {
        try { android.provider.DocumentsContract.deleteDocument(activity.contentResolver, uri) } catch (_: Exception) { }
    }
    private fun discard() {
        pending?.success(null); pending = null
        if (!writing) { chosen?.let { remove(it) }; chosen = null; id = null }
    }
    fun close() { cancelled = true; discard(); channel.setMethodCallHandler(null) }
}
