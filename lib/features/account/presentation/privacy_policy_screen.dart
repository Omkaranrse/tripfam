import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TripMate Privacy Commitment',
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
                  title: '1. What Information We Collect',
                  body:
                      'We collect minimal necessary personal data to connect travellers safely:\n\n'
                      '• Account & Profile: Display name, approximate home city, bio, avatar, and travel style preferences.\n'
                      '• Trip Itineraries: Destination, departure/return dates, vibe tags, and group chat messages.\n'
                      '• Safety & Emergency: Up to 3 private trusted contacts (name, email, or phone) and optional check-in timestamps.\n'
                      '• Identity Verification: A live front-camera selfie used exclusively by our human moderation team to verify authenticity. Selfies are permanently deleted immediately after review.',
                ),
                const SizedBox(height: 16),

                _buildSection(
                  context,
                  title: '2. How Your Data Is Protected',
                  body:
                      '• Strict Row-Level Security (RLS): All database tables enforce database-level row access rules. No user can access or query another traveller\'s private data.\n'
                      '• Private Storage Buckets: Profile avatars and verification selfies are stored in private cloud buckets accessible strictly via short-lived signed URLs.\n'
                      '• No Data Selling: We never sell your personal information or behavioural data to advertisers or third-party brokers.',
                ),
                const SizedBox(height: 16),

                _buildSection(
                  context,
                  title: '3. Your Rights & Data Portability (GDPR / CCPA)',
                  body:
                      'You retain complete ownership over your information:\n\n'
                      '• Right to Portability: You can download a complete, machine-readable JSON copy of your profile, trips, messages, and check-ins at any time via "Export My Data".\n'
                      '• Right to Erasure: Tapping "Delete Account" runs an immediate server-side deletion of all personal records, photos, contacts, and active requests.',
                ),
                const SizedBox(height: 16),

                _buildSection(
                  context,
                  title: '4. Contact & Data Protection Officer',
                  body: 'If you have questions regarding our privacy practices or wish to request assistance, contact privacy@tripfam.example.com.',
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
