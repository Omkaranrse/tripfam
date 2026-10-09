import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'avatar_stack.dart';
import 'destination_image.dart';
import 'status_pill.dart';

class TripCard extends StatefulWidget {
  const TripCard({
    required this.tripId,
    required this.destination,
    required this.dateRange,
    super.key,
    this.status,
    this.memberAvatars = const [],
    this.membersLabel,
    this.budget,
    this.onTap,
    this.isForestStyle = false,
  });

  final String tripId;
  final String destination;
  final String dateRange;
  final String? status;
  final List<String> memberAvatars;
  final String? membersLabel;
  final String? budget;
  final VoidCallback? onTap;
  final bool isForestStyle;

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final cardBg = widget.isForestStyle
        ? const Color(0xFF1B3124)
        : theme.colorScheme.surface;

    final onCardText = widget.isForestStyle
        ? Colors.white
        : theme.colorScheme.onSurface;

    final onCardMuted = widget.isForestStyle
        ? Colors.white.withAlpha(180)
        : theme.colorScheme.onSurface.withAlpha(160);

    return AnimatedScale(
      scale: _isPressed && !disableAnimations && widget.onTap != null ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: AppRadius.border20,
          border: Border.all(
            color: widget.isForestStyle
                ? Colors.white.withAlpha(25)
                : theme.colorScheme.outline.withAlpha(50),
          ),
          boxShadow: AppShadows.subtle(context),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.border20,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
            onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
            onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
            borderRadius: AppRadius.border20,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  // Photo Thumbnail with rounded corners
                  ClipRRect(
                    borderRadius: AppRadius.border12,
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: DestinationImage(
                        tripId: widget.tripId,
                        destination: widget.destination,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),

                  // Destination Details & Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.destination,
                                style: AppTypography.cardTitle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: onCardText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.status != null) ...[
                              const SizedBox(width: AppSpacing.s8),
                              StatusPill.fromStatus(widget.status!),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: onCardMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.dateRange,
                                style: AppTypography.caption.copyWith(
                                  color: onCardMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (widget.memberAvatars.isNotEmpty)
                              AvatarStack(
                                totalMembers: widget.memberAvatars.length,
                                avatarUrls: widget.memberAvatars,
                                isVerifiedViewer: true,
                                avatarSize: 24,
                                borderColor: cardBg,
                              )
                            else if (widget.membersLabel != null)
                              Text(
                                widget.membersLabel!,
                                style: AppTypography.caption.copyWith(
                                  color: onCardMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            if (widget.budget != null)
                              Text(
                                widget.budget!,
                                style: AppTypography.label.copyWith(
                                  color: widget.isForestStyle
                                      ? const Color(0xFFC6E062) // Lime accent
                                      : theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Subtle Chevron / Action indicator
                  const SizedBox(width: AppSpacing.s8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: onCardMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
