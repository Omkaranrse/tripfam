import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Guidelines & Terms',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last updated: October 2026',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                ),
                const SizedBox(height: 24),

                _buildSection(
                  context,
                  title: '1. Safe & Respectful Community',
                  body:
                      'TripMate is a community for travellers seeking companions. All members agree to:\n\n'
                      '• Respect boundaries, diversity, and cultural customs.\n'
                      '• Complete an intro call before meeting in person.\n'
                      '• Never send unsolicited commercial messages, scams, or inappropriate content.',
                ),
                const SizedBox(height: 16),

                _buildSection(
                  context,
                  title: '2. Identity Verification & Authenticity',
                  body:
                      '• Verification badges are granted upon human review by TripMate staff ("Verified by review").\n'
                      '• Impersonation, false identities, or attempting to submit fraudulent photos results in permanent termination of your account.',
                ),
                const SizedBox(height: 16),

                _buildSection(
                  context,
                  title: '3. Trip Hosting & Financial Responsibility',
                  body:
                      '• TripMate is a coordination platform. We do not provide tour-operator insurance or process cash peer-to-peer payments.\n'
                      '• Travellers are responsible for booking their own tickets, visas, accommodation, and travel health insurance.',
                ),
                const SizedBox(height: 16),

                _buildSection(
                  context,
                  title: '4. Zero Tolerance for Harassment',
                  body: 'Harassment, stalking, or discriminatory behavior will result in immediate suspension, blocking, and potential escalation to authorities.',
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }
}
