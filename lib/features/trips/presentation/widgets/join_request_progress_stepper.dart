import 'package:flutter/material.dart';

import '../../domain/join_request.dart';

class JoinRequestProgressStepper extends StatelessWidget {
  const JoinRequestProgressStepper({required this.stage, super.key});

  final JoinRequestStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStep = stage.stepIndex; // 0 (declined/cancelled), 1, 2, 3, 4

    if (stage == JoinRequestStage.declined ||
        stage == JoinRequestStage.cancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.error.withAlpha(50)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 20,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              stage == JoinRequestStage.declined
                  ? 'Request was declined'
                  : 'Request was cancelled',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    const steps = [
      _StepInfo(1, 'Requested', Icons.send_rounded),
      _StepInfo(2, 'Accepted', Icons.check_circle_outline_rounded),
      _StepInfo(3, 'Call Set', Icons.video_camera_front_outlined),
      _StepInfo(4, 'Chat Unlocked', Icons.chat_bubble_outline_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _buildStepItem(context, steps[i], currentStep),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: currentStep > steps[i].index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withAlpha(80),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: stage == JoinRequestStage.bothConfirmed
                ? Colors.green.withAlpha(20)
                : theme.colorScheme.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                stage == JoinRequestStage.bothConfirmed
                    ? Icons.lock_open_rounded
                    : Icons.info_outline_rounded,
                size: 14,
                color: stage == JoinRequestStage.bothConfirmed
                    ? Colors.green
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getStageDescription(stage),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    color: stage == JoinRequestStage.bothConfirmed
                        ? Colors.green.shade800
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(BuildContext context, _StepInfo step, int currentStep) {
    final theme = Theme.of(context);
    final isDone = currentStep > step.index;
    final isCurrent = currentStep == step.index;

    Color bg;
    Color fg;
    if (isDone) {
      bg = theme.colorScheme.primary;
      fg = Colors.white;
    } else if (isCurrent) {
      bg = theme.colorScheme.primary.withAlpha(30);
      fg = theme.colorScheme.primary;
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurface.withAlpha(100);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : null,
          ),
          child: Icon(isDone ? Icons.check : step.icon, size: 13, color: fg),
        ),
        const SizedBox(height: 3),
        Text(
          step.label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9.5,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            color: isCurrent
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
    );
  }

  String _getStageDescription(JoinRequestStage stage) {
    switch (stage) {
      case JoinRequestStage.requested:
        return 'Request is pending review by the trip host.';
      case JoinRequestStage.accepted:
        return 'Request accepted! Schedule an intro call to get to know each other.';
      case JoinRequestStage.callScheduled:
        return 'Intro call scheduled. Join the call and confirm to unlock group chat.';
      case JoinRequestStage.bothConfirmed:
        return 'Intro call confirmed by both! Trip chat is now unlocked.';
      case JoinRequestStage.declined:
        return 'Request was declined.';
      case JoinRequestStage.cancelled:
        return 'Request was cancelled.';
    }
  }
}

class _StepInfo {
  const _StepInfo(this.index, this.label, this.icon);
  final int index;
  final String label;
  final IconData icon;
}
