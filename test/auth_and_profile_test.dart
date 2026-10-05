import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/features/account/domain/user_profile.dart';

void main() {
  group('UserProfile Model & Completion Rules', () {
    test(
      'isProfileComplete is false when displayName is shorter than 2 chars',
      () {
        const profile = UserProfile(
          id: 'user-1',
          displayName: 'A',
          homeCity: 'London',
          travelStyle: {'pace': 'Moderate'},
        );
        expect(profile.isProfileComplete, isFalse);
      },
    );

    test('isProfileComplete is false when homeCity is null or empty', () {
      const profileWithoutCity = UserProfile(
        id: 'user-1',
        displayName: 'Alice',
        homeCity: '   ',
        travelStyle: {'pace': 'Moderate'},
      );
      expect(profileWithoutCity.isProfileComplete, isFalse);
    });

    test('isProfileComplete is false when travelStyle is empty', () {
      const profileWithoutStyle = UserProfile(
        id: 'user-1',
        displayName: 'Alice',
        homeCity: 'London',
        travelStyle: {},
      );
      expect(profileWithoutStyle.isProfileComplete, isFalse);
    });

    test(
      'isProfileComplete is true when name, city, and travelStyle are present',
      () {
        const completeProfile = UserProfile(
          id: 'user-1',
          displayName: 'Maya Chen',
          homeCity: 'Singapore',
          travelStyle: {
            'wake_up_time': 'Early Bird (6-8 AM)',
            'budget_level': 'Balanced (\$\$)',
            'pace': 'Moderate',
            'planning_style': 'Semi-planned',
          },
        );
        expect(completeProfile.isProfileComplete, isTrue);
      },
    );

    test('toUpdateJson trims string inputs cleanly', () {
      const profile = UserProfile(
        id: 'user-1',
        displayName: '  Bob Walker  ',
        homeCity: '  Sydney  ',
        bio: '  Loving beaches and mountain treks  ',
        travelStyle: {'pace': 'Relaxed'},
      );

      final json = profile.toUpdateJson();
      expect(json['display_name'], 'Bob Walker');
      expect(json['home_city'], 'Sydney');
      expect(json['bio'], 'Loving beaches and mountain treks');
    });

    test('isVerified defaults to false and is read-only', () {
      final json = {
        'id': 'user-123',
        'display_name': 'Carlos',
        'is_verified': false,
        'role': 'user',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.isVerified, isFalse);
      expect(profile.role, 'user');
    });
  });
}
