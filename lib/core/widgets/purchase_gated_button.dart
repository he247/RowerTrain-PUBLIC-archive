import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/in_app_purchase_service.dart';
import '../../../l10n/app_localizations.dart';

/// A widget that wraps a child button and shows a purchase overlay
/// when the training sessions feature is locked (Apple platforms only).
///
/// On non-Apple platforms, the child is displayed as-is.
/// On Apple platforms, if the feature is not purchased, shows a lock icon
/// and triggers a purchase flow on tap.
class PurchaseGatedButton extends StatefulWidget {
  /// The child widget to display when the feature is unlocked.
  final Widget child;

  /// Optional callback to invoke after a successful purchase.
  final VoidCallback? onPurchased;

  /// The IAP service instance (injectable for testing).
  final InAppPurchaseService? service;

  const PurchaseGatedButton({
    super.key,
    required this.child,
    this.onPurchased,
    this.service,
  });

  @override
  State<PurchaseGatedButton> createState() => _PurchaseGatedButtonState();
}

class _PurchaseGatedButtonState extends State<PurchaseGatedButton> {
  late InAppPurchaseService _service;
  StreamSubscription<bool>? _purchaseSubscription;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? InAppPurchaseService();
    _isUnlocked = _service.isTrainingSessionsUnlocked;
    _purchaseSubscription = _service.purchaseStateStream.listen((unlocked) {
      if (mounted) {
        setState(() {
          _isUnlocked = unlocked;
        });
        if (unlocked && widget.onPurchased != null) {
          widget.onPurchased!();
        }
      }
    });
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return widget.child;
    }

    final price = _service.trainingSessionsPrice;

    return ElevatedButton.icon(
      icon: const Icon(Icons.lock, size: 16),
      label: Text(
        price != null
            ? AppLocalizations.of(context)!.purchaseFor(price)
            : AppLocalizations.of(context)!.unlockFeature,
        style: const TextStyle(fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      onPressed: () => _handlePurchase(context),
    );
  }

  Future<void> _handlePurchase(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final success = await _service.buyTrainingSessions();
    if (!success && mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.purchaseFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
