import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:rafiq_app/core/paymob/constant.dart';
import 'package:url_launcher/url_launcher.dart';

class PayMobManager {
  Future<bool> getPaymentKey({
    required double amount,
    required String currency,
    required BuildContext context,
    required int placeId,
  }) async {
    try {
      // ملاحظة: السعر هنا هو القيمة الأكبر (مثل 100 إذا كان النطاق "30-100" في قاعدة البيانات)
      // لأن SuggestionItemModel.getPrice() تُرجع بالفعل القيمة الأكبر
      // التأكد من أن السعر ليس 0 لتجنب فشل الدفع
      double adjustedAmount = amount <= 0 ? 1.0 : amount;

      String authToken = await _getAuthToken();
      int orderId = await _getOrderId(
        token: authToken,
        amount: (100 * adjustedAmount).toString(),
        currency: currency,
        placeId: placeId,
      );
      String paymentKey = await _getPaymentKey(
        token: authToken,
        currency: currency,
        amount: (100 * adjustedAmount).toString(),
        orderId: orderId.toString(),
      );

      bool isPaymentSuccessful = await _launchPayMobPaymentPage(paymentKey);

      return isPaymentSuccessful;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _launchPayMobPaymentPage(String paymentKey) async {
    try {
      final url =
          "https://accept.paymob.com/api/acceptance/iframes/908197?payment_token=$paymentKey";
      bool isPaymentSuccessful = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      return isPaymentSuccessful;
    } catch (e) {
      return false;
    }
  }

  Future<String> _getAuthToken() async {
    try {
      Response response = await Dio().post(
        "https://accept.paymob.com/api/auth/tokens",
        data: {"api_key": PayMobConstant.apiKey},
      );
      return response.data["token"];
    } catch (e) {
      rethrow;
    }
  }

  Future<int> _getOrderId({
    required String token,
    required String amount,
    required String currency,
    required int placeId,
  }) async {
    try {
      Response response = await Dio().post(
        "https://accept.paymob.com/api/ecommerce/orders",
        data: {
          "auth_token": token,
          "delivery_needed": "false",
          "amount_cents": amount,
          "currency": currency,
          "items": [
            {
              "name": "Activity_$placeId",
              "amount_cents": amount,
              "description": "Payment for activity with ID: $placeId",
              "quantity": "1",
            }
          ],
        },
      );
      return response.data["id"];
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _getPaymentKey({
    required String token,
    required String orderId,
    required String amount,
    required String currency,
  }) async {
    try {
      Response response = await Dio().post(
        "https://accept.paymob.com/api/acceptance/payment_keys",
        data: {
          "auth_token": token,
          "amount_cents": amount,
          "order_id": orderId,
          "currency": currency,
          "integration_id": PayMobConstant.paymentIntegration,
          "expiration": "3600",
          "billing_data": {
            "first_name": "Omar",
            "last_name": "Elgmmal",
            "email": "omarelgmmal23@gmail.com",
            "phone_number": "01062156826",
            "apartment": "NA",
            "floor": "NA",
            "street": "NA",
            "building": "NA",
            "shipping_method": "NA",
            "postal_code": "NA",
            "city": "NA",
            "country": "NA",
            "state": "NA",
          },
        },
      );
      return response.data["token"];
    } catch (e) {
      rethrow;
    }
  }
}
