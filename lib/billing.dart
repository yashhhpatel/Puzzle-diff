import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'ads.dart';
import 'config.dart';
import 'services.dart';

enum PurchaseUiState { idle, paying, pending, success, canceled, failed, unavailable }

/// Google Play Billing through the official `in_app_purchase` plugin.
///
/// Purchases are verified only locally (known product ID, one grant per
/// purchase ID). For real revenue protection add server-side verification of
/// `purchase.verificationData.serverVerificationData` against the Google Play
/// Developer API before granting.
class Billing extends ChangeNotifier {
  static final Billing I = Billing._();
  Billing._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> products = {};
  bool available = false;
  bool _initialised = false;

  /// True once the store connection attempt has finished (either way).
  bool ready = false;

  PurchaseUiState state = PurchaseUiState.idle;
  String? lastProduct;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      // Listen before anything else so purchases that completed while the
      // app was closed are delivered and acknowledged.
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        debugPrint('purchase stream error: $e');
      });
      available = await _iap.isAvailable();
      if (!available) {
        ready = true;
        notifyListeners();
        return;
      }
      final resp = await _iap.queryProductDetails(StoreConfig.allIds);
      for (final p in resp.productDetails) {
        products[p.id] = p;
      }
      if (resp.notFoundIDs.isNotEmpty) debugPrint('billing: products not found ${resp.notFoundIDs}');
      // Brings back the Remove Ads entitlement after a reinstall.
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('billing init failed: $e');
      available = false;
    }
    ready = true;
    notifyListeners();
  }

  /// Localised Play price, or [fallback] until product details load.
  String priceOf(String id, String fallback) => products[id]?.price ?? fallback;

  Future<void> buy(String id) async {
    lastProduct = id;
    final details = products[id];
    if (!available || details == null) {
      _set(PurchaseUiState.unavailable);
      return;
    }
    _set(PurchaseUiState.paying);
    // The Play purchase sheet pauses the app; returning isn't an "app open".
    Ads.I.quietNextResume();
    final param = PurchaseParam(productDetails: details);
    try {
      final started = id == StoreConfig.removeAds
          ? await _iap.buyNonConsumable(purchaseParam: param)
          : await _iap.buyConsumable(purchaseParam: param);
      if (!started) _set(PurchaseUiState.failed);
    } catch (e) {
      debugPrint('buy failed: $e');
      _set(PurchaseUiState.failed);
    }
  }

  void dismiss() => _set(PurchaseUiState.idle);

  void _set(PurchaseUiState s) {
    state = s;
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          if (p.productID == lastProduct) _set(PurchaseUiState.pending);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = grant(p.productID, p.purchaseID ?? p.verificationData.serverVerificationData, Progress.I);
          if (p.productID == lastProduct && p.status == PurchaseStatus.purchased) {
            _set(ok ? PurchaseUiState.success : PurchaseUiState.failed);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('purchase error: ${p.error}');
          if (p.productID == lastProduct) _set(PurchaseUiState.failed);
          break;
        case PurchaseStatus.canceled:
          if (p.productID == lastProduct) _set(PurchaseUiState.canceled);
          break;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('completePurchase failed: $e');
        }
      }
    }
  }

  /// Delivers the content of [productId] once per [purchaseId]. Returns
  /// false for unknown products.
  static bool grant(String productId, String purchaseId, Progress progress) {
    if (productId == StoreConfig.removeAds) {
      progress.adsFree = true;
      progress.save();
      return true;
    }
    final coins = StoreConfig.consumables[productId];
    if (coins == null) return false;
    if (progress.grantedPurchases.contains(purchaseId)) return true;
    progress.coins += coins;
    if (productId == StoreConfig.boosterBundle) {
      for (final k in progress.boosters.keys.toList()) {
        progress.boosters[k] = progress.boosters[k]! + 2;
      }
    }
    progress.grantedPurchases = [...progress.grantedPurchases, purchaseId];
    if (progress.grantedPurchases.length > 200) {
      progress.grantedPurchases = progress.grantedPurchases.sublist(progress.grantedPurchases.length - 200);
    }
    progress.save();
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
