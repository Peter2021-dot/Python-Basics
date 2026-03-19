import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // IMPORTANT: Replace with your actual publishable key from Stripe Dashboard
  final String _publishableKey = 'pk_test_51PXXXXXXXXXXXXX'; // Placeholder

  Future<void> init() async {
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
  }

  Future<Map<String, dynamic>> _createPaymentIntent(String amount, String currency) async {
    try {
      // In a real application, YOU MUST call your backend to create the PaymentIntent.
      // NEVER create it directly from the client with your Secret Key!
      // This is just a placeholder for the backend call.
      
      /*
      final response = await http.post(
        Uri.parse('YOUR_BACKEND_URL/create-payment-intent'),
        body: {
          'amount': amount,
          'currency': currency,
        },
      );
      return jsonDecode(response.body);
      */
      
      // Mocking a response for demonstration purposes
      return {
        'paymentIntent': 'pi_mock_123',
        'ephemeralKey': 'ek_mock_123',
        'customer': 'cus_mock_123',
        'publishableKey': _publishableKey,
      };
    } catch (err) {
      throw Exception('Failed to create payment intent: $err');
    }
  }

  Future<void> makePayment({
    required BuildContext context,
    required String amount,
    required String currency,
  }) async {
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payments are not yet supported on the web version of WeThere.')),
        );
      }
      return;
    }
    try {
      // 1. Create Payment Intent on backend
      final paymentIntentData = await _createPaymentIntent(amount, currency);

      // 2. Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['paymentIntent'],
          customerEphemeralKeySecret: paymentIntentData['ephemeralKey'],
          customerId: paymentIntentData['customer'],
          merchantDisplayName: 'WeThere',
          style: ThemeMode.system,
        ),
      );

      // 3. Display Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on StripeException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stripe Error: ${e.error.localizedMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
