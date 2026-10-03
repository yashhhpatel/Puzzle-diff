import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads.dart';
import '../config.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

/// Opens the hosted privacy policy in the browser.
Future<void> openPrivacyPolicy(BuildContext context) async {
  if (kPrivacyPolicyUrl.isEmpty) {
    _snack(context, 'Privacy policy coming soon.');
    return;
  }
  Ads.I.quietNextResume();
  final ok = await launchUrl(Uri.parse(kPrivacyPolicyUrl), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) _snack(context, 'Could not open the browser.');
}

void openContact(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder(
    pageBuilder: (_, __, ___) => const ContactScreen(),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// "Privacy Policy · Contact Us" text links for settings popups.
class LegalLinks extends StatelessWidget {
  final double unit;
  final Color color;
  const LegalLinks({super.key, required this.unit, this.color = AppColors.lavenderDark});
  @override
  Widget build(BuildContext context) {
    final style = bodyStyle(unit * 0.036, color: color, weight: 700).copyWith(decoration: TextDecoration.underline, decorationColor: color);
    return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
      Pressable(onTap: () => openPrivacyPolicy(context), child: Text('Privacy Policy', style: style)),
      Text('   •   ', style: bodyStyle(unit * 0.036, color: color)),
      Pressable(onTap: () => openContact(context), child: Text('Contact Us', style: style)),
    ]));
  }
}

class _Topic {
  final IconData icon;
  final String label, subject;
  const _Topic(this.icon, this.label, this.subject);
}

const _topics = [
  _Topic(Icons.receipt_long_rounded, 'Purchase problem', 'Purchase problem'),
  _Topic(Icons.bug_report_rounded, 'Report a bug', 'Bug report'),
  _Topic(Icons.lightbulb_rounded, 'Feedback & ideas', 'Feedback'),
  _Topic(Icons.privacy_tip_rounded, 'Privacy request', 'Privacy request'),
];

/// Contact Us: one-tap email topics to the support address.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _email(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      // Uri encodes spaces as '+' in queryParameters, which mail apps show
      // literally, so build the query by hand.
      query: 'subject=${Uri.encodeComponent('[Jewel Sort] $subject')}'
          '&body=${Uri.encodeComponent('\n\n---\nApp version: ${AppInfo.label}\nLevel: ${Progress.I.level}')}',
    );
    Ads.I.quietNextResume();
    final ok = await launchUrl(uri).catchError((_) => false);
    if (!ok && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: kSupportEmail));
      if (context.mounted) _snack(context, 'No email app found. Address copied: $kSupportEmail');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final u = min(size.width, size.height * 0.56);
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Center(
            child: SizedBox(
              width: u,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: u * 0.06),
                child: Column(children: [
                  SizedBox(
                    height: u * 0.2,
                    child: Row(children: [
                      Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: u * 0.1,
                          height: u * 0.1,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.arrow_back_rounded, color: AppColors.lavenderDark, size: u * 0.065),
                        ),
                      ),
                      Expanded(child: Center(child: TitleTab(text: 'Contact Us', unit: u))),
                      SizedBox(width: u * 0.1),
                    ]),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(u * 0.05),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(240),
                      borderRadius: BorderRadius.circular(u * 0.05),
                      border: Border.all(color: AppColors.popupBorder, width: u * 0.008),
                    ),
                    child: Column(children: [
                      Container(
                        width: u * 0.2,
                        height: u * 0.2,
                        decoration: BoxDecoration(color: AppColors.popupBg, shape: BoxShape.circle, border: Border.all(color: AppColors.popupBorder, width: 2)),
                        child: Icon(Icons.mark_email_unread_rounded, color: AppColors.lavenderDark, size: u * 0.11),
                      ),
                      SizedBox(height: u * 0.03),
                      Text("We'd love to hear from you!", textAlign: TextAlign.center, style: titleStyle(u * 0.06, color: AppColors.textDark)),
                      SizedBox(height: u * 0.015),
                      Text('Pick a topic and we will reply by email, usually within 2 working days.',
                          textAlign: TextAlign.center, style: bodyStyle(u * 0.04, color: AppColors.textDark.withAlpha(180), weight: 600)),
                      SizedBox(height: u * 0.03),
                      Pressable(
                        onTap: () async {
                          await Clipboard.setData(const ClipboardData(text: kSupportEmail));
                          if (context.mounted) _snack(context, 'Email address copied');
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: u * 0.04, vertical: u * 0.02),
                          decoration: BoxDecoration(color: AppColors.popupBg, borderRadius: BorderRadius.circular(u)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(child: Text(kSupportEmail, overflow: TextOverflow.ellipsis, style: bodyStyle(u * 0.038))),
                            SizedBox(width: u * 0.02),
                            Icon(Icons.copy_rounded, size: u * 0.045, color: AppColors.lavenderDark),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  SizedBox(height: u * 0.05),
                  for (final t in _topics)
                    Padding(
                      padding: EdgeInsets.only(bottom: u * 0.03),
                      child: Pressable(
                        onTap: () => _email(context, t.subject),
                        child: Container(
                          height: u * 0.15,
                          padding: EdgeInsets.symmetric(horizontal: u * 0.04),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(u * 0.04),
                            boxShadow: [BoxShadow(color: AppColors.lavenderDark.withAlpha(35), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Row(children: [
                            Icon(t.icon, color: AppColors.lavenderDark, size: u * 0.07),
                            SizedBox(width: u * 0.04),
                            Expanded(child: Text(t.label, style: bodyStyle(u * 0.047))),
                            Icon(Icons.chevron_right_rounded, color: AppColors.lavender, size: u * 0.07),
                          ]),
                        ),
                      ),
                    ),
                  SizedBox(height: u * 0.02),
                  Pressable(
                    onTap: () => openPrivacyPolicy(context),
                    child: Text('Privacy Policy',
                        style: bodyStyle(u * 0.04, color: AppColors.lavenderDark)
                            .copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.lavenderDark)),
                  ),
                  SizedBox(height: u * 0.06),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
