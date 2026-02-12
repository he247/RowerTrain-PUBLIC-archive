import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/in_app_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// A mock implementation of [InAppPurchase] for testing.
class MockInAppPurchase implements InAppPurchase {
  bool isAvailableResult = true;
  ProductDetailsResponse? queryProductDetailsResult;
  bool buyNonConsumableResult = true;
  bool completePurchaseCalled = false;
  bool restorePurchasesCalled = false;

  final StreamController<List<PurchaseDetails>> purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Future<bool> isAvailable() async => isAvailableResult;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      purchaseStreamController.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return queryProductDetailsResult ??
        ProductDetailsResponse(
          productDetails: [],
          notFoundIDs: identifiers.toList(),
          error: null,
        );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return buyNonConsumableResult;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    return false;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completePurchaseCalled = true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCalled = true;
  }

  @override
  Future<String> countryCode() async => 'US';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void dispose() {
    purchaseStreamController.close();
  }
}

/// A fake [ProductDetails] for testing.
ProductDetails _fakeProductDetails({
  String id = kTrainingSessionsProductId,
  String title = 'Training Sessions',
  String description = 'Unlock all training sessions',
  String price = '\$4.99',
  double rawPrice = 4.99,
  String currencyCode = 'USD',
}) {
  return ProductDetails(
    id: id,
    title: title,
    description: description,
    price: price,
    rawPrice: rawPrice,
    currencyCode: currencyCode,
  );
}

/// A fake [PurchaseDetails] for testing.
PurchaseDetails _fakePurchaseDetails({
  String productID = kTrainingSessionsProductId,
  PurchaseStatus status = PurchaseStatus.purchased,
  bool pendingCompletePurchase = true,
}) {
  return PurchaseDetails(
    productID: productID,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'test',
      serverVerificationData: 'test',
      source: 'test',
    ),
    transactionDate: DateTime.now().toIso8601String(),
    status: status,
    purchaseID: 'test_purchase_id',
  )..pendingCompletePurchase = pendingCompletePurchase;
}

void main() {
  group('InAppPurchaseService', () {
    late MockInAppPurchase mockIAP;
    late InAppPurchaseService service;

    setUp(() {
      mockIAP = MockInAppPurchase();
    });

    tearDown(() {
      mockIAP.dispose();
    });

    group('Singleton Pattern', () {
      test('factory constructor returns same instance', () {
        final a = InAppPurchaseService();
        final b = InAppPurchaseService();
        expect(identical(a, b), isTrue);
        a.resetForTesting();
      });
    });

    group('Non-Apple Platform', () {
      test('everything is unlocked on non-Apple platforms', () {
        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: false,
        );

        expect(service.isTrainingSessionsUnlocked, isTrue);
        expect(service.isApplePlatform, isFalse);
      });

      test('initialize sets unlocked immediately on non-Apple', () async {
        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: false,
        );

        await service.initialize();
        expect(service.isTrainingSessionsUnlocked, isTrue);
      });
    });

    group('Apple Platform - Store Unavailable', () {
      test('gracefully handles store not available', () async {
        mockIAP.isAvailableResult = false;

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();
        expect(service.isTrainingSessionsUnlocked, isFalse);
        expect(service.isStoreAvailable, isFalse);
        expect(service.trainingSessionsPrice, isNull);
      });
    });

    group('Apple Platform - Store Available', () {
      setUp(() {
        mockIAP.isAvailableResult = true;
      });

      test('loads product details on initialize', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();

        expect(service.isStoreAvailable, isTrue);
        expect(service.trainingSessionsPrice, equals('\$4.99'));
        expect(service.isTrainingSessionsUnlocked, isFalse);
      });

      test('handles product not found', () async {
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [],
          notFoundIDs: [kTrainingSessionsProductId],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
        );

        await service.initialize();

        expect(service.isStoreAvailable, isFalse);
        expect(service.trainingSessionsPrice, isNull);
      });

      test('unlocks on successful purchase', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();
        expect(service.isTrainingSessionsUnlocked, isFalse);

        // Simulate a successful purchase
        final purchase = _fakePurchaseDetails(
          status: PurchaseStatus.purchased,
        );
        mockIAP.purchaseStreamController.add([purchase]);

        // Wait for the stream to process
        await Future.delayed(const Duration(milliseconds: 100));

        expect(service.isTrainingSessionsUnlocked, isTrue);
        expect(mockIAP.completePurchaseCalled, isTrue);
      });

      test('unlocks on restored purchase', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();

        // Simulate a restored purchase
        final purchase = _fakePurchaseDetails(
          status: PurchaseStatus.restored,
        );
        mockIAP.purchaseStreamController.add([purchase]);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(service.isTrainingSessionsUnlocked, isTrue);
      });

      test('emits on purchaseStateStream when unlocked', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();

        final completer = Completer<bool>();
        service.purchaseStateStream.listen((unlocked) {
          if (!completer.isCompleted) {
            completer.complete(unlocked);
          }
        });

        final purchase = _fakePurchaseDetails(
          status: PurchaseStatus.purchased,
        );
        mockIAP.purchaseStreamController.add([purchase]);

        final result = await completer.future.timeout(
          const Duration(seconds: 2),
        );
        expect(result, isTrue);
      });

      test('does not unlock on error status', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();

        final purchase = _fakePurchaseDetails(
          status: PurchaseStatus.error,
        );
        mockIAP.purchaseStreamController.add([purchase]);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(service.isTrainingSessionsUnlocked, isFalse);
      });

      test('does not unlock on canceled status', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();

        final purchase = _fakePurchaseDetails(
          status: PurchaseStatus.canceled,
        );
        mockIAP.purchaseStreamController.add([purchase]);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(service.isTrainingSessionsUnlocked, isFalse);
      });

      test('does not unlock on pending status', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();

        final purchase = _fakePurchaseDetails(
          status: PurchaseStatus.pending,
          pendingCompletePurchase: false,
        );
        mockIAP.purchaseStreamController.add([purchase]);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(service.isTrainingSessionsUnlocked, isFalse);
      });

      test('ignores purchases for other product IDs', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();

        final purchase = _fakePurchaseDetails(
          productID: 'some_other_product',
          status: PurchaseStatus.purchased,
        );
        mockIAP.purchaseStreamController.add([purchase]);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(service.isTrainingSessionsUnlocked, isFalse);
      });
    });

    group('buyTrainingSessions', () {
      test('returns false when product is not loaded', () async {
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [],
          notFoundIDs: [kTrainingSessionsProductId],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
          debugModeOverride: false,
        );

        await service.initialize();

        final result = await service.buyTrainingSessions();
        expect(result, isFalse);
      });

      test('returns true when purchase initiated successfully', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );
        mockIAP.buyNonConsumableResult = true;

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
        );

        await service.initialize();

        final result = await service.buyTrainingSessions();
        expect(result, isTrue);
      });
    });

    group('restorePurchases', () {
      test('calls restore on IAP instance', () async {
        final product = _fakeProductDetails();
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
        );

        await service.initialize();
        await service.restorePurchases();

        expect(mockIAP.restorePurchasesCalled, isTrue);
      });
    });

    group('initialize idempotency', () {
      test('calling initialize twice does not re-subscribe', () async {
        mockIAP.queryProductDetailsResult = ProductDetailsResponse(
          productDetails: [_fakeProductDetails()],
          notFoundIDs: [],
          error: null,
        );

        service = InAppPurchaseService.forTesting(
          inAppPurchase: mockIAP,
          isApplePlatformOverride: true,
        );

        await service.initialize();
        await service.initialize(); // Should be a no-op

        expect(service.isStoreAvailable, isTrue);
      });
    });
  });
}
