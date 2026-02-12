import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../utils/logger.dart';

/// Product ID for the training sessions one-time purchase.
/// This must match the product ID configured in App Store Connect.
const String kTrainingSessionsProductId = 'training_sessions_unlock';

/// Service to manage in-app purchases (Apple platforms only).
///
/// On non-Apple platforms, all features are unlocked by default.
/// On Apple platforms, the user must purchase [kTrainingSessionsProductId]
/// to unlock training session generator and saved training sessions.
/// Free ride mode is always free.
class InAppPurchaseService {
  static final InAppPurchaseService _instance =
      InAppPurchaseService._internal();

  factory InAppPurchaseService() => _instance;

  /// For testing: allows injecting a mock [InAppPurchase] instance.
  InAppPurchaseService.forTesting({
    required InAppPurchase inAppPurchase,
    bool? isApplePlatformOverride,
    bool? debugModeOverride,
  })  : _inAppPurchase = inAppPurchase,
        _isApplePlatformOverride = isApplePlatformOverride,
        _debugModeOverride = debugModeOverride;

  InAppPurchaseService._internal();

  InAppPurchase? _inAppPurchase;
  bool? _isApplePlatformOverride;
  bool? _debugModeOverride;

  InAppPurchase get _iap => _inAppPurchase ?? InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isInitialized = false;

  /// Whether the training sessions feature has been purchased.
  bool _isTrainingSessionsUnlocked = false;

  /// Product details for the training sessions purchase.
  ProductDetails? _trainingSessionsProduct;

  /// Stream controller to notify listeners when purchase state changes.
  final StreamController<bool> _purchaseStateController =
      StreamController<bool>.broadcast();

  /// Stream that emits `true` when training sessions are unlocked.
  Stream<bool> get purchaseStateStream => _purchaseStateController.stream;

  /// Whether the current platform is Apple (iOS or macOS).
  bool get isApplePlatform =>
      _isApplePlatformOverride ?? (Platform.isIOS || Platform.isMacOS);

  /// Whether training sessions (generator + saved sessions) are unlocked.
  ///
  /// Returns `true` on non-Apple platforms (always unlocked).
  /// Returns `true` on Apple platforms if the purchase has been made or in debug mode.
  bool get isTrainingSessionsUnlocked =>
      !isApplePlatform || 
      _isTrainingSessionsUnlocked || 
      (_debugModeOverride ?? kDebugMode);

  /// Whether the IAP store is available on this device.
  bool get isStoreAvailable => _trainingSessionsProduct != null;

  /// The localized price string for the training sessions product.
  /// Returns `null` if the product is not available.
  String? get trainingSessionsPrice => _trainingSessionsProduct?.price;

  /// Initialize the service: listen to purchase updates and load past purchases.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!isApplePlatform) {
      _isTrainingSessionsUnlocked = true;
      _isInitialized = true;
      return;
    }

    final isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      logger.w('In-app purchases not available on this device');
      _isInitialized = true;
      return;
    }

    // Listen to purchase updates
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) => logger.e('Purchase stream error: $error'),
    );

    // Load product details
    await _loadProducts();

    _isInitialized = true;
  }

  /// Load product details from the store.
  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails({kTrainingSessionsProductId});

      if (response.notFoundIDs.isNotEmpty) {
        logger.w('Products not found: ${response.notFoundIDs}');
      }

      if (response.productDetails.isNotEmpty) {
        _trainingSessionsProduct = response.productDetails.first;
        logger.i(
            'Training sessions product loaded: ${_trainingSessionsProduct!.price}');
      }
    } catch (e) {
      logger.e('Failed to load products: $e');
    }
  }

  /// Handle purchase update events.
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      _handlePurchase(purchase);
    }
  }

  /// Process a single purchase update.
  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.productID != kTrainingSessionsProductId) return;

    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        _isTrainingSessionsUnlocked = true;
        _purchaseStateController.add(true);
        logger.i('Training sessions unlocked (${purchase.status})');
        break;
      case PurchaseStatus.error:
        logger.e('Purchase error: ${purchase.error}');
        break;
      case PurchaseStatus.pending:
        logger.i('Purchase pending');
        break;
      case PurchaseStatus.canceled:
        logger.i('Purchase canceled');
        break;
    }

    // Complete the purchase if pending completion
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  /// Initiate the purchase flow for training sessions.
  ///
  /// Returns `true` if the purchase was successfully initiated,
  /// `false` if the product is not available.
  Future<bool> buyTrainingSessions() async {
    if (_trainingSessionsProduct == null) {
      logger.w('Training sessions product not available');
      return false;
    }

    final purchaseParam = PurchaseParam(
      productDetails: _trainingSessionsProduct!,
    );

    try {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      logger.e('Failed to initiate purchase: $e');
      return false;
    }
  }

  /// Restore previous purchases (e.g., after reinstall or new device).
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      logger.e('Failed to restore purchases: $e');
    }
  }

  /// Dispose of the service and cancel subscriptions.
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseStateController.close();
    _isInitialized = false;
  }

  /// Reset the singleton state (for testing only).
  void resetForTesting() {
    _isTrainingSessionsUnlocked = false;
    _trainingSessionsProduct = null;
    _isInitialized = false;
    _isApplePlatformOverride = null;
    _debugModeOverride = null;
    _inAppPurchase = null;
  }
}
