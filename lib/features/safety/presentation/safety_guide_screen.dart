import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';

class SafetyGuideScreen extends StatelessWidget {
  const SafetyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final safetyTips = [
      (
        icon: Icons.video_call_outlined,
        title: 'Always Complete an Intro Call',
        description: 'Never meet in person without first having a 15-minute video intro call (Google Meet, Zoom, or WhatsApp) to align on expectations, budget, and travel tempo.',
      ),
      (
        icon: Icons.verified_user_outlined,
        title: 'Prioritize Verified Travellers',
        description: 'Look for the "Verified by review" shield on profiles and departures. Hosts can restrict trips to verified travellers for extra peace of mind.',
      ),
      (
        icon: Icons.contact_emergency_outlined,
        title: 'Set Up 3 Trusted Contacts',
        description: 'Add your family or close friends in Safety Settings. If you ever miss an active trip check-in deadline, they will be automatically notified with your trip details.',
      ),
      (
        icon: Icons.payments_outlined,
        title: 'Pay Direct, Never Wire Cash',
        description: 'Never transfer money to co-travellers for shared bookings before meeting. Book your own flights and hotel rooms directly with recognized providers.',
      ),
      (
        icon: Icons.meeting_room_outlined,
        title: 'First Meetups in Public Places',
        description: 'Meet in busy, well-lit public spots (airport arrivals, hotel lobbies, prominent cafes). Keep your phone charged and local emergency numbers saved.',
      ),
      (
        icon: Icons.block_outlined,
        title: 'Block and Report Bad Actors',
        description: 'If someone behaves inappropriately, use the in-chat or profile menu to Block and Report them immediately. Blocked users are muted and cannot contact you.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Community Safety Guide')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Travel Smart, Stay Safe',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Our golden rules for safe, unforgettable companion travel.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(
                                  160,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  for (final tip in safetyTips) ...[
                    AppCard(
                      variant: AppCardVariant.outlined,
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            tip.icon,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tip.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tip.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(190),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
