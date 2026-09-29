import 'dart:math';

import 'package:flutter/material.dart';

import '../billing.dart';
import '../config.dart';
import '../game/gem_art.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class _Pack {
  final String id;
  final int coins;
  final String fallbackPrice;
  final String? badge;
  const _Pack(this.id, this.coins, this.fallbackPrice, [this.badge]);
}

const _packs = [
  _Pack(StoreConfig.coins550, 550, '₹180.00'),
  _Pack(StoreConfig.coins2750, 2750, '₹800.00', 'Popular'),
  _Pack(StoreConfig.coins5500, 5500, '₹1,600.00'),
  _Pack(StoreConfig.coins15000, 15000, '₹3,100.00'),
  _Pack(StoreConfig.coins27000, 27000, '₹5,300.00'),
  _Pack(StoreConfig.coins55000, 55000, '₹8,900.00', 'Best'),
];

/// Coin shop. Purchases go through Google Play Billing; prices are the
/// localised Play prices once product details have loaded.
class ShopScreen extends StatefulWidget {
  /// Product to start buying as soon as the shop opens (e.g. "No Ads").
  final String? autoBuy;
  const ShopScreen({super.key, this.autoBuy});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  @override
  void initState() {
    super.initState();
    Billing.I.addListener(_refresh);
    Progress.I.addListener(_refresh);
    Billing.I.dismiss();
    if (widget.autoBuy != null) WidgetsBinding.instance.addPostFrameCallback((_) => _buy(widget.autoBuy!));
  }

  @override
  void dispose() {
    Billing.I.removeListener(_refresh);
    Progress.I.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final s = Billing.I.state;
    if (s != PurchaseUiState.idle && s != PurchaseUiState.paying) Sfx.I.play(s == PurchaseUiState.success ? 'coin' : 'whoosh');
    setState(() {});
  }

  void _buy(String id) {
    if (id == StoreConfig.removeAds && Progress.I.adsFree) return;
    Billing.I.buy(id);
  }

  String _price(String id, String fallback) => Billing.I.priceOf(id, fallback);

  String? _storeNote() {
    final b = Billing.I;
    if (!b.ready) return 'Connecting to Google Play…';
    if (!b.available) return 'Google Play is not available on this device.';
    if (b.products.isEmpty) return 'Store items are not available yet.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = min(size.width, size.height * 0.56);
    final state = Billing.I.state;
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFF1),
      body: SafeArea(
        child: Stack(children: [
          Center(
            child: SizedBox(
              width: w,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: w * 0.07),
                child: Column(children: [
                  SizedBox(
                    height: w * 0.2,
                    child: Row(children: [
                      SizedBox(width: w * 0.16),
                      CoinPill(coins: Progress.I.coins, unit: w, plus: false),
                      const Spacer(),
                      CloseX(size: w * 0.08, onTap: () => Navigator.of(context).pop()),
                    ]),
                  ),
                  _bundle(w),
                  SizedBox(height: w * 0.035),
                  _removeAds(w),
                  SizedBox(height: w * 0.04),
                  Row(children: [
                    const Expanded(child: Divider(color: Color(0xFFD5D5DD), thickness: 1.5)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                      child: Text('Coins', style: titleStyle(w * 0.058, color: AppColors.lavenderDark)),
                    ),
                    const Expanded(child: Divider(color: Color(0xFFD5D5DD), thickness: 1.5)),
                  ]),
                  SizedBox(height: w * 0.04),
                  for (var row = 0; row < 2; row++)
                    Padding(
                      padding: EdgeInsets.only(bottom: w * 0.03),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        for (var col = 0; col < 3; col++) _packCard(row * 3 + col, w),
                      ]),
                    ),
                  if (_storeNote() != null)
                    Padding(
                      padding: EdgeInsets.only(top: w * 0.02),
                      child: Text(_storeNote()!,
                          textAlign: TextAlign.center, style: bodyStyle(w * 0.035, color: AppColors.textDark.withAlpha(140), weight: 500)),
                    ),
                  SizedBox(height: w * 0.05),
                ]),
              ),
            ),
          ),
          if (state == PurchaseUiState.paying) ...[
            Positioned.fill(child: GestureDetector(onTap: () {}, child: Container(color: Colors.black.withAlpha(170)))),
            Positioned.fill(
              child: IgnorePointer(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const _Spinner(),
                  SizedBox(height: w * 0.05),
                  Text('Payment in progress', style: TextStyle(color: Colors.white, fontSize: w * 0.05)),
                ]),
              ),
            ),
          ],
          if (state.index >= PurchaseUiState.pending.index) ...[
            Positioned.fill(child: GestureDetector(onTap: () {}, child: Container(color: AppColors.overlay))),
            Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(state),
                tween: Tween(begin: 0.7, end: 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: _resultCard(w, state),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _resultCard(double w, PurchaseUiState state) {
    final (title, text) = switch (state) {
      PurchaseUiState.success => ('Purchase Complete', 'Thank you! Your items\nhave been added.'),
      PurchaseUiState.pending => ('Payment Pending', "Your items will arrive once\nthe payment completes."),
      PurchaseUiState.canceled => ('Purchase Canceled', "Your account wasn't\ncharged."),
      PurchaseUiState.unavailable => ('Store Unavailable', 'Google Play is not available\nright now. Try again later.'),
      _ => ('Purchase Failed', "Something went wrong.\nYou weren't charged."),
    };
    final cw = w * 0.74;
    void close() => Billing.I.dismiss();
    return SizedBox(
      width: cw + w * 0.03,
      height: w * 0.6,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          top: w * 0.05,
          width: cw,
          height: w * 0.52,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.popupBg,
              borderRadius: BorderRadius.circular(w * 0.035),
              border: Border.all(color: AppColors.popupBorder, width: w * 0.012),
            ),
            padding: EdgeInsets.fromLTRB(w * 0.04, w * 0.09, w * 0.04, w * 0.04),
            child: Column(children: [
              Text(text, textAlign: TextAlign.center, style: bodyStyle(w * 0.05, weight: 500)),
              const Spacer(),
              ChunkyButton(
                color: AppColors.green,
                shade: AppColors.greenDark,
                width: w * 0.45,
                height: w * 0.13,
                whiteBorder: true,
                onTap: close,
                child: buttonLabel('OK', w * 0.075),
              ),
            ]),
          ),
        ),
        Positioned(left: 0, width: cw, top: 0, child: Center(child: TitleTab(text: title, unit: w * 0.85))),
        Positioned(right: 0, top: w * 0.025, child: CloseX(size: w * 0.07, onTap: close)),
      ]),
    );
  }

  Widget _removeAds(double w) {
    final owned = Progress.I.adsFree;
    return Container(
      padding: EdgeInsets.all(w * 0.022),
      decoration: BoxDecoration(
        color: AppColors.shopBlue,
        borderRadius: BorderRadius.circular(w * 0.03),
        boxShadow: [BoxShadow(color: AppColors.shopBlueDark, offset: Offset(0, w * 0.008))],
      ),
      child: Row(children: [
        Container(
          width: w * 0.14,
          height: w * 0.14,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(w * 0.025)),
          child: Stack(alignment: Alignment.center, children: [
            Text('AD', style: titleStyle(w * 0.05, color: AppColors.textDark)),
            Icon(Icons.block_rounded, color: AppColors.red, size: w * 0.12),
          ]),
        ),
        SizedBox(width: w * 0.03),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Remove Ads', style: titleStyle(w * 0.05)),
            Text('No more ads between levels', style: bodyStyle(w * 0.032, color: Colors.white.withAlpha(230), weight: 600)),
          ]),
        ),
        owned
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.03),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: w * 0.06),
                  SizedBox(width: w * 0.01),
                  Text('Owned', style: titleStyle(w * 0.045)),
                ]),
              )
            : ChunkyButton(
                color: AppColors.green,
                shade: AppColors.greenDark,
                width: w * 0.26,
                height: w * 0.085,
                whiteBorder: true,
                onTap: () => _buy(StoreConfig.removeAds),
                child: Text(_price(StoreConfig.removeAds, '₹250.00'), style: titleStyle(w * 0.04)),
              ),
      ]),
    );
  }

  Widget _bundle(double w) {
    Widget item(Widget icon, String n) => Container(
          width: w * 0.2,
          height: w * 0.062,
          decoration: BoxDecoration(color: const Color(0xFFF0F0F6), borderRadius: BorderRadius.circular(w * 0.015)),
          child: Row(children: [
            Transform.translate(offset: Offset(-w * 0.01, 0), child: icon),
            SizedBox(width: w * 0.01),
            Text(n, style: bodyStyle(w * 0.042)),
          ]),
        );
    return Container(
      padding: EdgeInsets.all(w * 0.022),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFD08DF0), Color(0xFFB690F2)]),
        borderRadius: BorderRadius.circular(w * 0.03),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Container(
          height: w * 0.23,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(w * 0.025)),
          child: Row(children: [
            SizedBox(
              width: w * 0.3,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.card_giftcard_rounded, size: w * 0.13, color: const Color(0xFFD65BD0)),
                Text('Bundle', style: bodyStyle(w * 0.04)),
              ]),
            ),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  item(CoinIcon(size: w * 0.065), '900'),
                  item(BoosterIcon(kind: 'wand', size: w * 0.065), '2'),
                ]),
                SizedBox(height: w * 0.02),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  item(BoosterIcon(kind: 'broom', size: w * 0.065), '2'),
                  item(BoosterIcon(kind: 'magnet', size: w * 0.065), '2'),
                ]),
              ]),
            ),
          ]),
        ),
        SizedBox(height: w * 0.02),
        Row(children: [
          SizedBox(width: w * 0.02),
          Expanded(child: Text('Booster Bundle', style: titleStyle(w * 0.045))),
          ChunkyButton(
            color: AppColors.green,
            shade: AppColors.greenDark,
            width: w * 0.3,
            height: w * 0.085,
            whiteBorder: true,
            onTap: () => _buy(StoreConfig.boosterBundle),
            child: Text(_price(StoreConfig.boosterBundle, '₹890.00'), style: titleStyle(w * 0.045)),
          ),
        ]),
      ]),
    );
  }

  Widget _packCard(int i, double w) {
    final p = _packs[i];
    final cw = w * 0.27;
    return Pressable(
      onTap: () => _buy(p.id),
      child: SizedBox(
        width: cw,
        height: cw * 1.0,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.shopBlue,
              borderRadius: BorderRadius.circular(w * 0.025),
              boxShadow: [BoxShadow(color: AppColors.shopBlueDark, offset: Offset(0, w * 0.008))],
            ),
            padding: EdgeInsets.all(w * 0.012),
            child: Column(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(w * 0.02)),
                  child: Column(children: [
                    Expanded(child: CustomPaint(painter: _PackArt(i), size: Size.infinite)),
                    Text('${p.coins}', style: bodyStyle(w * 0.042)),
                    SizedBox(height: w * 0.008),
                  ]),
                ),
              ),
              SizedBox(height: w * 0.008),
              FittedBox(child: Text(_price(p.id, p.fallbackPrice), style: titleStyle(w * 0.036))),
            ]),
          ),
          if (p.badge != null)
            Positioned(
              left: -w * 0.012,
              top: -w * 0.018,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.015, vertical: w * 0.003),
                decoration: BoxDecoration(
                  color: p.badge == 'Best' ? const Color(0xFFF23A83) : const Color(0xFFFF7A1A),
                  borderRadius: BorderRadius.circular(w * 0.012),
                ),
                child: Text(p.badge!, style: titleStyle(p.badge == 'Best' ? w * 0.036 : w * 0.026)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Coin piles of growing size, with a gift, sack or chest on bigger packs.
class _PackArt extends CustomPainter {
  final int tier;
  _PackArt(this.tier);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.62);
    final r = size.width * 0.12;
    void pile(Offset base, int n) {
      final rnd = Random(tier * 13 + n);
      for (var i = 0; i < n; i++) {
        final row = i < n / 2 ? 0 : 1;
        final o = base + Offset((rnd.nextDouble() - 0.5) * r * 3.2, -row * r * 0.9 - rnd.nextDouble() * r * 0.4);
        canvas.drawOval(Rect.fromCenter(center: o.translate(0, r * 0.2), width: r * 2, height: r * 1.2), Paint()..color = const Color(0xFFE08A00));
        canvas.drawOval(Rect.fromCenter(center: o, width: r * 2, height: r * 1.2), Paint()..color = const Color(0xFFFFC53A));
        canvas.drawOval(Rect.fromCenter(center: o, width: r * 1.3, height: r * 0.7), Paint()..color = const Color(0xFFFFD86B));
      }
    }

    switch (tier) {
      case 0:
        pile(c, 4);
        break;
      case 1:
        pile(c, 7);
        break;
      case 2:
        _box(canvas, c.translate(0, -r * 0.8), r * 2.6, const Color(0xFFE05BD6), const Color(0xFFFFD23F));
        pile(c.translate(0, r * 0.4), 5);
        break;
      case 3:
        _box(canvas, c.translate(r * 0.5, -r * 0.7), r * 2.4, const Color(0xFF55C24A), const Color(0xFFFFD23F));
        pile(c.translate(-r * 0.3, r * 0.4), 6);
        break;
      case 4:
        final sack = Path()
          ..moveTo(c.dx - r * 0.8, c.dy - r * 2)
          ..quadraticBezierTo(c.dx - r * 2.4, c.dy + r * 0.8, c.dx, c.dy + r * 0.8)
          ..quadraticBezierTo(c.dx + r * 2.4, c.dy + r * 0.8, c.dx + r * 0.8, c.dy - r * 2)
          ..close();
        canvas.drawPath(sack, Paint()..color = const Color(0xFFE2463C));
        canvas.drawCircle(c.translate(0, -r * 2.1), r * 0.7, Paint()..color = const Color(0xFFFFC53A));
        pile(c.translate(0, r * 0.6), 6);
        break;
      default:
        _box(canvas, c.translate(r * 0.4, -r * 0.8), r * 3, const Color(0xFF2E9E6E), const Color(0xFF2E7BF4));
        pile(c.translate(-r * 0.2, r * 0.5), 8);
    }
  }

  void _box(Canvas canvas, Offset c, double s, Color body, Color ribbon) {
    final rect = Rect.fromCenter(center: c, width: s, height: s * 0.8);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.1)), Paint()..color = body);
    canvas.drawRect(Rect.fromCenter(center: c, width: s * 0.18, height: s * 0.8), Paint()..color = ribbon);
    canvas.drawRect(Rect.fromCenter(center: c, width: s, height: s * 0.14), Paint()..color = ribbon);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Spinner extends StatefulWidget {
  const _Spinner();
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => SizedBox(
          width: 60,
          height: 60,
          child: CustomPaint(painter: _DotsPainter(_c.value)),
        ),
      );
}

class _DotsPainter extends CustomPainter {
  final double t;
  _DotsPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 8; i++) {
      final a = t * 2 * pi + i * pi / 4;
      final k = i / 8;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * size.width * 0.35, 2 + 4 * k, Paint()..color = Colors.white.withAlpha((80 + 175 * k).round()));
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.t != t;
}
