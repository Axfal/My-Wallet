package com.mywallet.app.my_wallet

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.mywallet.app/ledger_export"
    private val createDocumentRequest = 7142
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveCsv") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("BUSY", "A save dialog is already open", null)
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                if (name.isNullOrBlank() || bytes == null) {
                    result.error("INVALID", "Missing file name or data", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                pendingBytes = bytes
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/csv"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, createDocumentRequest)
                } catch (error: Exception) {
                    pendingResult = null
                    pendingBytes = null
                    result.error("PICKER_FAILED", error.message, null)
                }
            }
    }

    @Deprecated("Used for Android document picker compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createDocumentRequest) return
        val result = pendingResult
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(false)
            return
        }
        try {
            val uri = data.data!!
            contentResolver.openOutputStream(uri)?.use { it.write(bytes ?: byteArrayOf()) }
                ?: throw IllegalStateException("Could not open the selected file")
            result?.success(true)
        } catch (error: Exception) {
            result?.error("SAVE_FAILED", error.message, null)
        }
    }
}
