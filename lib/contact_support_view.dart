import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'for_ads/ads/ads_variable.dart';
import 'for_ads/utils/firebase_analysis.dart';
import 'ui/themes/app_theme.dart';

enum _Category {
  featureRequest('Feature Request', Icons.lightbulb_outline_rounded),
  bugReport('Bug Report', Icons.bug_report_outlined),
  premiumSupport('Premium Support', Icons.workspace_premium_outlined),
  general('General', Icons.chat_bubble_outline_rounded),
  other('Other', Icons.more_horiz_rounded);

  const _Category(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  _Category _selected = _Category.general;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  bool _sending = false;

  static const int _maxChars = 2000;
  static const Color _primaryPurple = Color(0xFF794DEB);
  static const Color _secondaryPurple = Color(0xFF512CB8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseAnalyticsService.logEvent(eventName: 'CONTACT_SUPPORT_SCREEN');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Please write your message before submitting.');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });

    final String email = AdsVariable.supportContactEmail;
    final isPremium = AdsVariable.isPurchase;
    final tier = isPremium ? 'Premium' : 'Free';
    final subject = 'Universal Remote Feedback · ${_selected.label} · $tier';
    final body = message;

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeMailtoQuery({'subject': subject, 'body': body}),
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showFallbackToast(email);
      }
    } catch (_) {
      if (mounted) _showFallbackToast(email);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _encodeMailtoQuery(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  void _showFallbackToast(String email) {
    Fluttertoast.showToast(
      msg: 'No email client found. You can reach us at: $email',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.surfaceElevated,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _controller.text.length;
    final isOverLimit = charCount > _maxChars;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Contact Support',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryPurple.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.headset_mic_outlined,
                      color: _primaryPurple,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "We're Here to Help",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Send feedback, report issues, or request new features.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Category label
            Text(
              "What's this about?",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.6,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),

            // Category chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _Category.values.map((cat) {
                  final isActive = cat == _selected;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _primaryPurple
                              : AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? _primaryPurple
                                : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 16,
                              color: isActive ? Colors.white : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.label,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Message label
            Text(
              'Tell us more',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.6,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),

            // Message text field
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: _error != null
                      ? AppTheme.error
                      : _focusNode.hasFocus
                          ? _primaryPurple
                          : AppTheme.border,
                  width: _focusNode.hasFocus || _error != null ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 5,
                    maxLines: 12,
                    maxLength: _maxChars,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => null,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                    decoration: InputDecoration(
                      hintText:
                          "Describe the feature you'd love to see, the bug you found, or anything on your mind…",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  // Character counter
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$charCount / $_maxChars',
                          style: TextStyle(
                            color: isOverLimit
                                ? AppTheme.error
                                : Colors.white.withOpacity(0.4),
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Inline error
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Subject preview
            Builder(
              builder: (ctx) {
                final isPremium = AdsVariable.isPurchase;
                final tier = isPremium ? 'Premium' : 'Free';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppTheme.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Subject: Universal Remote Feedback · ${_selected.label} · $tier',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),
            Text(
              'You can edit the subject and body in your email app before sending.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
                fontFamily: 'Inter',
              ),
            ),

            const SizedBox(height: 32),

            // Submit gradient button
            GestureDetector(
              onTap: (_sending || isOverLimit) ? null : _submit,
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: (_sending || isOverLimit)
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_primaryPurple, _secondaryPurple],
                        ),
                  color: (_sending || isOverLimit)
                      ? Colors.white.withOpacity(0.12)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _sending ? 'Opening email…' : 'Open in Email App',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
