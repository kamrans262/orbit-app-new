package com.example.orbit_ui

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import com.android.billingclient.api.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

/** Native Play Billing. Never acknowledge on-device; server is authoritative.
 * Debug-only checkout; explicit Dart test-build and backend gates also apply.
 * License-test account provisioning is mandatory before exercising checkout. */
internal class OrbitStoreBilling(private val activity:FlutterActivity,private val channel:MethodChannel):PurchasesUpdatedListener {
    private var checkout:MethodChannel.Result?=null
    private var connected=false
    private var connecting=false
    private var closed=false
    private val client=BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection().build()
    private val sandboxBuild=(activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE)!=0
    init {
        channel.setMethodCallHandler { call,result ->
            if(!sandboxBuild || closed){result.error("disabled","Sandbox billing disabled",null);return@setMethodCallHandler}
            when(call.method){
                "products"->withClient(result){products(call,result)}
                "purchase"->withClient(result){purchase(call,result)}
                "recover"->withClient(result){recover(result)}
                "finish"->result.success(null) // Google acknowledgement owned by Laravel.
                "manage"->try {
                    activity.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://play.google.com/store/account/subscriptions?package="+activity.packageName)))
                    result.success(null)
                }catch(_:Exception){result.error("unavailable","Store management unavailable",null)}
                else->result.notImplemented()
            }
        }
    }
    private fun withClient(result:MethodChannel.Result,action:()->Unit){
        if(client.isReady){action();return}
        if(connecting){result.error("busy","Store connecting",null);return}
        connecting=true
        client.startConnection(object:BillingClientStateListener{
            override fun onBillingSetupFinished(r:BillingResult){
                connecting=false;connected=r.responseCode==BillingClient.BillingResponseCode.OK
                if(connected&&!closed)action() else result.error("unavailable","Store unavailable",null)
            }
            override fun onBillingServiceDisconnected(){connected=false}
        })
    }
    private fun query(ids:List<String>, result:MethodChannel.Result, action:(List<ProductDetails>)->Unit){
        if(ids.isEmpty()){action(emptyList());return}
        if(ids.size>16||ids.any{!it.matches(Regex("^[A-Za-z0-9._-]{1,150}$"))}){result.error("invalid","Invalid product",null);return}
        val params=QueryProductDetailsParams.newBuilder().setProductList(ids.distinct().map{
            QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(BillingClient.ProductType.SUBS).build()
        }).build()
        client.queryProductDetailsAsync(params){response,data->
            if(response.responseCode!=BillingClient.BillingResponseCode.OK||closed)result.error("unavailable","Store catalog unavailable",null)
            else action(data.productDetailsList)
        }
    }
    // Stage 1 is monthly only; refuse promotional/ambiguous base offers,
    // prepaid phases, trial pricing and non-monthly recurring offers.
    private fun offer(product:ProductDetails,base:String):ProductDetails.SubscriptionOfferDetails? {
        return product.subscriptionOfferDetails?.filter{ o->
            o.basePlanId==base&&o.offerId==null&&o.pricingPhases.pricingPhaseList.size==1&&
                o.pricingPhases.pricingPhaseList[0].billingPeriod=="P1M"&&
                o.pricingPhases.pricingPhaseList[0].recurrenceMode==ProductDetails.RecurrenceMode.INFINITE_RECURRING
        }?.singleOrNull()
    }
    private fun products(call:MethodCall,result:MethodChannel.Result){
        val mappings=call.argument<List<Map<String,Any?>>>("mappings")?:emptyList()
        val ids=mappings.mapNotNull{it["product_id"] as? String}
        query(ids,result){details->
            val output=mappings.mapNotNull{ m->
                val p=details.singleOrNull{it.productId==m["product_id"]}?:return@mapNotNull null
                val base=m["base_plan_id"] as? String?:return@mapNotNull null
                val o=offer(p,base)?:return@mapNotNull null
                mapOf("id" to m["id"],"product_id" to p.productId,"base_plan_id" to base,"price" to o.pricingPhases.pricingPhaseList[0].formattedPrice)
            }
            result.success(output)
        }
    }
    private fun purchase(call:MethodCall,result:MethodChannel.Result){
        val id=call.argument<String>("product_id")
        val base=call.argument<String>("base_plan_id")
        val binding=call.argument<String>("account_binding")
        if(call.argument<String>("environment")!="sandbox"||id==null||base==null||binding==null||!binding.matches(Regex("^[a-f0-9]{64}$"))||checkout!=null){
            result.error("invalid","Purchase context unavailable",null);return
        }
        query(listOf(id),result){details->
            val product=details.singleOrNull{it.productId==id}
            val o=product?.let{offer(it,base)}
            if(product==null||o==null||checkout!=null){result.error("unavailable","Product unavailable",null);return@query}
            // Re-query current purchases immediately before checkout; do not
            // launch a second subscription on an existing Play account.
            client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()){r,purchases->
                if(r.responseCode!=BillingClient.BillingResponseCode.OK||purchases.isNotEmpty()||checkout!=null||closed){
                    result.error("recover","Restore or manage existing purchases",null);return@queryPurchasesAsync
                }
                val params=BillingFlowParams.newBuilder().setObfuscatedAccountId(binding).setProductDetailsParamsList(listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product).setOfferToken(o.offerToken).build()
                )).build()
                checkout=result
                val launched=client.launchBillingFlow(activity,params)
                if(launched.responseCode!=BillingClient.BillingResponseCode.OK){
                    checkout=null
                    if(launched.responseCode==BillingClient.BillingResponseCode.USER_CANCELED)result.success("cancelled")
                    else result.error("unavailable","Purchase unavailable",null)
                }
            }
        }
    }
    override fun onPurchasesUpdated(r:BillingResult,purchases:MutableList<Purchase>?){
        val result=checkout?:return;checkout=null
        when(r.responseCode){
            BillingClient.BillingResponseCode.USER_CANCELED->result.success("cancelled")
            BillingClient.BillingResponseCode.OK->result.success(if(purchases?.any{it.purchaseState==Purchase.PurchaseState.PENDING}==true)"pending" else "purchased")
            else->result.error("unavailable","Purchase not confirmed",null)
        }
    }
    private fun recover(result:MethodChannel.Result){
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()){r,purchases->
            if(r.responseCode!=BillingClient.BillingResponseCode.OK||closed){result.error("unavailable","Restore unavailable",null);return@queryPurchasesAsync}
            if(purchases.size>64){result.error("invalid","Purchase list exceeds limit",null);return@queryPurchasesAsync}
            result.success(purchases.filter{it.products.size==1}.map{p->
                mapOf("proof" to p.purchaseToken,"product_id" to p.products[0],"binding" to p.accountIdentifiers?.obfuscatedAccountId,
                    "state" to when(p.purchaseState){Purchase.PurchaseState.PURCHASED->"purchased";Purchase.PurchaseState.PENDING->"pending";else->"unknown"})
            })
        }
    }
    fun close(){
        closed=true;checkout?.error("interrupted","Purchase interrupted; restore later",null);checkout=null
        channel.setMethodCallHandler(null);client.endConnection()
    }
}
