import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/in_app_purchase_service.dart';
import 'package:ftms/core/widgets/purchase_gated_button.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// A minimal mock [InAppPurchase] for widget tests.
class _MockInAppPurchase implements InAppPurchase {
  final StreamController<List<PurchaseDetails>> purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      purchaseStreamController.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: kTrainingSessionsProductId,
          title: 'Training Sessions',
          description: 'Unlock all training sessions',
          price: '\$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
      ],
      notFoundIDs: [],
      error: null,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async =>
      false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<String> countryCode() async => 'US';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void dispose() {
    purchaseStreamController.close();
  }
}

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('PurchaseGatedButton', () {
    testWidgets('shows child when unlocked (non-Apple platform)', (tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      await tester.pumpWidget(
        _buildTestApp(
          child: PurchaseGatedButton(
            service: service,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Start'),
            ),
          ),
        ),
      );

      expect(find.text('Start'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);

      mockIAP.dispose();
    });

    testWidgets('shows lock button when locked (Apple platform)', (tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: true,
        debugModeOverride: false,
      );
      await service.initialize();

      await tester.pumpWidget(
        _buildTestApp(
          child: PurchaseGatedButton(
            service: service,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Start'),
            ),
          ),
        ),
      );

      // Should show the lock icon and price, not the child
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.textContaining('\$4.99'), findsOneWidget);

      mockIAP.dispose();
    });

    testWidgets('transitions to child after purchase', (tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: true,
        debugModeOverride: false,
      );
      await service.initialize();

      await tester.pumpWidget(
        _buildTestApp(
          child: PurchaseGatedButton(
            service: service,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Start'),
            ),
          ),
        ),
      );

      // Initially locked
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Simulate a successful purchase
      mockIAP.purchaseStreamController.add([
        PurchaseDetails(
          productID: kTrainingSessionsProductId,
          verificationData: PurchaseVerificationData(
            localVerificationData: 'test',
            serverVerificationData: 'test',
            source: 'test',
          ),
          transactionDate: DateTime.now().toIso8601String(),
          status: PurchaseStatus.purchased,
          purchaseID: 'test_id',
        )..pendingCompletePurchase = true,
      ]);

      await tester.pump(const Duration(milliseconds: 200));

      // Now should show the child
      expect(find.text('Start'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);

      mockIAP.dispose();
    });

    testWidgets('shows unlock text when no price available', (tester) async {
      final mockIAP = _MockInAppPurchase();
      // Override to return no products (so price is null)
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: _NoPriceInAppPurchase(),
        isApplePlatformOverride: true,
        debugModeOverride: false,
      );
      await service.initialize();

      await tester.pumpWidget(
        _buildTestApp(
          child: PurchaseGatedButton(
            service: service,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Start'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock), findsOneWidget);
      // Should show "Unlock" text since no price is available
      expect(find.text('Unlock'), findsOneWidget);

      mockIAP.dispose();
    });
  });
}

/// A mock that returns no products so price is null.
class _NoPriceInAppPurchase implements InAppPurchase {
  final StreamController<List<PurchaseDetails>> _streamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _streamController.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(
      productDetails: [],
      notFoundIDs: identifiers.toList(),
      error: null,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async =>
      false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<String> countryCode() async => 'US';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
