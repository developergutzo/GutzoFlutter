package `in`.gutzo.customer_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.paytm.pgsdk.PaytmPaymentTransactionCallback
import com.paytm.pgsdk.PaytmOrder
import com.paytm.pgsdk.TransactionManager
import android.os.Bundle
import android.content.Intent
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "in.gutzo.customer_app/paytm"

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i("GutzoPaytm", "🏛️ [Native] configureFlutterEngine CALLED")
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.i("GutzoPaytm", "📡 [Native] Method Call: ${call.method}")
            if (call.method == "startTransaction") {
                try {
                    val mid = call.argument<String>("mid")!!
                    val orderId = call.argument<String>("orderId")!!
                    val amount = call.argument<String>("amount")!!
                    val txnToken = call.argument<String>("txnToken")!!
                    val callbackUrl = call.argument<String>("callbackUrl")!!
                    val isStaging = call.argument<Boolean>("isStaging")!!
                    val restrictAppInvoke = call.argument<Boolean>("restrictAppInvoke")!!

                    pendingResult = result
                    startPaytmTransaction(mid, orderId, amount, txnToken, callbackUrl, isStaging, restrictAppInvoke)
                } catch (e: Exception) {
                    Log.e("GutzoPaytm", "❌ [Native] Handler Crash: ${e.message}")
                    result.error("HANDLER_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendResult(data: Any?) {
        Log.i("GutzoPaytm", "✅ [Native] Sending Result back to Flutter")
        pendingResult?.success(data)
        pendingResult = null
    }

    private fun startPaytmTransaction(
        mid: String,
        orderId: String,
        amount: String,
        txnToken: String,
        callbackUrl: String,
        isStaging: Boolean,
        restrictAppInvoke: Boolean
    ) {
        try {
            val host = if (isStaging) {
                "https://securestage.paytmpayments.com/"
            } else {
                "https://securegw.paytm.in/"
            }
            val fullCallbackUrl = if (callbackUrl.isEmpty()) {
                "${host}theia/paytmCallback?ORDER_ID=$orderId"
            } else {
                callbackUrl
            }

            Log.i("GutzoPaytm", "📡 [Native] Order: $orderId, Amt: $amount, MID: $mid")
            val paytmOrder = PaytmOrder(orderId, mid, txnToken, amount, fullCallbackUrl)
            
            val transactionManager = TransactionManager(paytmOrder, object : PaytmPaymentTransactionCallback {
                override fun onTransactionResponse(bundle: Bundle?) {
                    Log.i("GutzoPaytm", "📡 [Native] Response Received: $bundle")
                    val responseMap = mutableMapOf<String, Any?>()
                    bundle?.keySet()?.forEach { key ->
                        responseMap[key] = bundle.get(key)
                    }
                    sendResult(responseMap)
                }
        
                override fun networkNotAvailable() {
                    Log.e("GutzoPaytm", "❌ [Native] Network Not Available")
                    pendingResult?.error("NETWORK_ERROR", "Network not available", null)
                    pendingResult = null
                }
        
                override fun onErrorProceed(error: String?) {
                    Log.e("GutzoPaytm", "❌ [Native] Error Proceed: $error")
                    pendingResult?.error("SDK_ERROR", error ?: "Unknown SDK Error", null)
                    pendingResult = null
                }
        
                override fun clientAuthenticationFailed(message: String?) {
                    Log.e("GutzoPaytm", "❌ [Native] Client Auth Failed: $message")
                    pendingResult?.error("AUTH_FAILED", message ?: "Auth Failed", null)
                    pendingResult = null
                }
        
                override fun someUIErrorOccurred(error: String?) {
                    Log.e("GutzoPaytm", "❌ [Native] UI Error: $error")
                    pendingResult?.error("UI_ERROR", error ?: "UI Error", null)
                    pendingResult = null
                }
        
                override fun onErrorLoadingWebPage(p0: Int, p1: String?, p2: String?) {
                    Log.e("GutzoPaytm", "❌ [Native] Web Page Error: $p1")
                    pendingResult?.error("WEB_PAGE_ERROR", "Error loading web page: $p1", null)
                    pendingResult = null
                }
        
                override fun onBackPressedCancelTransaction() {
                    Log.w("GutzoPaytm", "⚠️ [Native] User back-pressed")
                    sendResult(mapOf("STATUS" to "TXN_FAILURE", "RESPMSG" to "User cancelled transaction"))
                }

                override fun onTransactionCancel(s: String?, bundle: Bundle?) {
                    Log.w("GutzoPaytm", "⚠️ [Native] Transaction cancelled: $s")
                    val responseMap = mutableMapOf<String, Any?>()
                    bundle?.keySet()?.forEach { key ->
                        responseMap[key] = bundle.get(key)
                    }
                    sendResult(responseMap)
                }
            })

            Log.i("GutzoPaytm", "🚀 [Native] Starting Transaction activity...")
            transactionManager.startTransaction(this, 101)
        } catch (e: Exception) {
            Log.e("GutzoPaytm", "❌ [Native] SDK Init Crash: ${e.message}")
            pendingResult?.error("SDK_INIT_ERROR", e.message, null)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 101 && data != null) {
            val response = data.getStringExtra("nativeSdkForMerchantMessage")
            val bundle = data.extras
            Log.d("GutzoPaytm", "📡 [Native] onActivityResult: $response")
            
            if (pendingResult != null) {
                val responseMap = mutableMapOf<String, Any?>()
                bundle?.keySet()?.forEach { key ->
                    responseMap[key] = bundle.get(key)
                }
                sendResult(responseMap)
            }
        }
    }
}
