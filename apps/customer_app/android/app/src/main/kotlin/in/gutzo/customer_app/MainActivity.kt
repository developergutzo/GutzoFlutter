package `in`.gutzo.customer_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.paytm.pgsdk.PaytmPaymentTransactionCallback
import com.paytm.pgsdk.PaytmOrder
import com.paytm.pgsdk.TransactionManager
import android.os.Bundle
import android.content.Intent

class MainActivity : FlutterActivity() {
    private val CHANNEL = "in.gutzo.customer_app/paytm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startTransaction") {
                val mid = call.argument<String>("mid")!!
                val orderId = call.argument<String>("orderId")!!
                val amount = call.argument<String>("amount")!!
                val txnToken = call.argument<String>("txnToken")!!
                val callbackUrl = call.argument<String>("callbackUrl")!!
                val isStaging = call.argument<Boolean>("isStaging")!!
                val restrictAppInvoke = call.argument<Boolean>("restrictAppInvoke")!!

                startPaytmTransaction(mid, orderId, amount, txnToken, callbackUrl, isStaging, restrictAppInvoke, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startPaytmTransaction(
        mid: String,
        orderId: String,
        amount: String,
        txnToken: String,
        callbackUrl: String,
        isStaging: Boolean,
        restrictAppInvoke: Boolean,
        flutterResult: MethodChannel.Result
    ) {
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

        val paytmOrder = PaytmOrder(orderId, mid, txnToken, amount, fullCallbackUrl)
        
        val transactionManager = TransactionManager(paytmOrder, object : PaytmPaymentTransactionCallback {
            override fun onTransactionResponse(bundle: Bundle?) {
                val responseMap = mutableMapOf<String, Any?>()
                bundle?.keySet()?.forEach { key ->
                    responseMap[key] = bundle.get(key)
                }
                flutterResult.success(responseMap)
            }

            override fun networkNotAvailable() {
                flutterResult.error("NETWORK_ERROR", "Network not available", null)
            }

            override fun onErrorProceed(s: String?) {
                flutterResult.error("ERROR", s ?: "Unknown error", null)
            }

            override fun clientAuthenticationFailed(s: String?) {
                flutterResult.error("AUTH_FAILED", s ?: "Client authentication failed", null)
            }

            override fun someUIErrorOccurred(s: String?) {
                flutterResult.error("UI_ERROR", s ?: "UI error occurred", null)
            }

            override fun onErrorLoadingWebPage(p0: Int, p1: String?, p2: String?) {
                flutterResult.error("WEB_PAGE_ERROR", "Error loading web page: $p1", null)
            }

            override fun onBackPressedCancelTransaction() {
                flutterResult.success(mapOf("STATUS" to "TXN_FAILURE", "RESPMSG" to "User cancelled transaction"))
            }

            override fun onTransactionCancel(s: String?, bundle: Bundle?) {
                val responseMap = mutableMapOf<String, Any?>()
                bundle?.keySet()?.forEach { key ->
                    responseMap[key] = bundle.get(key)
                }
                flutterResult.success(responseMap)
            }
        })

        transactionManager.startTransaction(this, 101)
    }
}
