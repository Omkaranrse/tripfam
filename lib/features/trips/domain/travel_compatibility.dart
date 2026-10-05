abstract final class TravelCompatibility {
  /// Computes human-friendly compatibility labels between two travellers.
  /// Strictly outputs plain descriptive badges (NO numerical scores or percentages).
  static List<String> computeLabels({
    required Map<String, dynamic> userStyle,
    required Map<String, dynamic> hostStyle,
  }) {
    if (userStyle.isEmpty || hostStyle.isEmpty) {
      return const ['Open-minded solo explorers'];
    }

    final labels = <String>[];

    // 1. Morning Rhythm
    final userWake = (userStyle['wake_up_time'] as String? ?? '').toLowerCase();
    final hostWake = (hostStyle['wake_up_time'] as String? ?? '').toLowerCase();

    if (userWake.isNotEmpty && hostWake.isNotEmpty) {
      if (userWake.contains('early') && hostWake.contains('early')) {
        labels.add('Both early risers');
      } else if (userWake.contains('night') && hostWake.contains('night')) {
        labels.add('Both night owls');
      } else if (userWake.contains('balanced') &&
          hostWake.contains('balanced')) {
        labels.add('Similar morning rhythm');
      }
    }

    // 2. Budget Level
    final userBudget = (userStyle['budget_level'] as String? ?? '')
        .toLowerCase();
    final hostBudget = (hostStyle['budget_level'] as String? ?? '')
        .toLowerCase();

    if (userBudget.isNotEmpty && hostBudget.isNotEmpty) {
      if (userBudget.contains('backpacker') &&
          hostBudget.contains('backpacker')) {
        labels.add('Both backpackers');
      } else if (userBudget.contains('luxury') &&
          hostBudget.contains('luxury')) {
        labels.add('Both luxury travellers');
      } else if (userBudget.contains('balanced') &&
          hostBudget.contains('balanced')) {
        labels.add('Similar budget');
      }
    }

    // 3. Daily Pace
    final userPace = (userStyle['pace'] as String? ?? '').toLowerCase();
    final hostPace = (hostStyle['pace'] as String? ?? '').toLowerCase();

    if (userPace.isNotEmpty && hostPace.isNotEmpty) {
      if (userPace.contains('relaxed') && hostPace.contains('relaxed')) {
        labels.add('Both relaxed pace');
      } else if (userPace.contains('action') && hostPace.contains('action')) {
        labels.add('Both fast-paced explorers');
      } else if (userPace.contains('moderate') &&
          hostPace.contains('moderate')) {
        labels.add('Matching daily pace');
      }
    }

    // 4. Planning Style
    final userPlan = (userStyle['planning_style'] as String? ?? '')
        .toLowerCase();
    final hostPlan = (hostStyle['planning_style'] as String? ?? '')
        .toLowerCase();

    if (userPlan.isNotEmpty && hostPlan.isNotEmpty) {
      if (userPlan.contains('spontaneous') &&
          hostPlan.contains('spontaneous')) {
        labels.add('Both spontaneous');
      } else if (userPlan.contains('structured') &&
          hostPlan.contains('structured')) {
        labels.add('Both structured planners');
      } else if (userPlan.contains('semi') && hostPlan.contains('semi')) {
        labels.add('Matching planning style');
      }
    }

    if (labels.isEmpty) {
      labels.add('Adventurous spirits');
    }

    return labels;
  }
}
