import 'package:flutter/foundation.dart';

import '../../features/trips/domain/trip.dart';
import 'demo_images.dart';
import 'demo_users.dart';

/// Curated realistic Indian trips focused on Mumbai and surrounding weekend & holiday destinations.
abstract final class DemoTrips {
  static bool get isEnabled => kDebugMode;

  /// Destination images map for backwards-compatibility.
  static const Map<String, String> destinationImages = {
    'alibaug': DemoImages.alibaug1,
    'goa': DemoImages.goa1,
    'lonavala': DemoImages.lonavala1,
    'rajmachi': DemoImages.rajmachi1,
    'kasol': DemoImages.kasol1,
    'manali': DemoImages.manali1,
    'rishikesh': DemoImages.rishikesh1,
    'gokarna': DemoImages.gokarna1,
    'munnar': DemoImages.munnar1,
    'coorg': DemoImages.coorg1,
    'kashmir': DemoImages.kashmir1,
    'jaipur': DemoImages.jaipur1,
    'udaipur': DemoImages.udaipur1,
    'spiti': DemoImages.spiti1,
    'mahabaleshwar': DemoImages.mahabaleshwar1,
    'khandala': DemoImages.khandala1,
  };

  /// Returns 18 diverse, internally consistent demo trips.
  static List<Trip> get all {
    final now = DateTime.now();

    // Dynamically calculate this weekend and next weekend
    final daysUntilSaturday = (DateTime.saturday - now.weekday + 7) % 7 == 0
        ? 7
        : (DateTime.saturday - now.weekday + 7) % 7;
    final thisSaturday = now.add(Duration(days: daysUntilSaturday));
    final thisSunday = thisSaturday.add(const Duration(days: 1));

    final nextSaturday = thisSaturday.add(const Duration(days: 7));
    final nextSunday = nextSaturday.add(const Duration(days: 1));

    return [
      // 1. Alibaug Weekend (This Weekend, Open, 2 spots left)
      Trip(
        id: 'trip-alibaug',
        hostId: DemoUsers.aarav.id,
        destination: 'Alibaug, Maharashtra',
        startDate: thisSaturday,
        endDate: thisSunday,
        budget: 4500.0,
        maxMembers: 4,
        confirmedMembersCount: 2,
        description:
            'Leaving Mumbai early Saturday morning via Mandwa Ro-Pax ferry. Spending the weekend exploring secluded Alibaug beaches, fort views, coastal cycling, and fresh seafood cafés before returning Sunday evening.',
        tags: const ['Beach', 'Weekend', 'Road trip'],
        status: 'published',
        hostDisplayName: DemoUsers.aarav.displayName,
        hostAvatarPath: DemoUsers.aarav.avatarPath,
        hostIsVerified: DemoUsers.aarav.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (6-8 AM)',
          'budget_level': 'Balanced (₹5k-₹10k)',
          'pace': 'Relaxed (1-2 spots/day)',
          'planning_style': 'Semi-planned (key anchors only)',
          'compatibility': ['Similar budget', 'Weekend friendly', 'Adventure lover'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 4)),
      ),

      // 2. Goa Beach & Sunset Weekend (Next 4 Days, Almost full - 1 spot left)
      Trip(
        id: 'trip-goa',
        hostId: DemoUsers.riya.id,
        destination: 'North Goa',
        startDate: now.add(const Duration(days: 4)),
        endDate: now.add(const Duration(days: 8)),
        budget: 8500.0,
        maxMembers: 5,
        confirmedMembersCount: 4,
        description:
            'Coastal road trip down to Vagator and Morjim. Sunsets at cliffside shacks, boutique homestay with pool, night markets, and scooter rides along quiet coastal roads. Chilled out vibe.',
        tags: const ['Beach', 'Weekend', 'Road trip'],
        status: 'published',
        hostDisplayName: DemoUsers.riya.displayName,
        hostAvatarPath: DemoUsers.riya.avatarPath,
        hostIsVerified: DemoUsers.riya.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Balanced (8-10 AM)',
          'budget_level': 'Comfort (₹5k-₹10k)',
          'pace': 'Relaxed (1-2 spots/day)',
          'planning_style': 'Spontaneous (go with flow)',
          'compatibility': ['Beach lover', 'Sunset chaser', 'Foodie'],
        },
        requiresVerifiedMembers: true,
        createdAt: now.subtract(const Duration(days: 6)),
      ),

      // 3. Monsoon Trek to Rajmachi (Next Weekend, Almost full - 1 spot left)
      Trip(
        id: 'trip-rajmachi',
        hostId: DemoUsers.neha.id,
        destination: 'Rajmachi Fort, Lonavala',
        startDate: nextSaturday,
        endDate: nextSunday,
        budget: 2800.0,
        maxMembers: 6,
        confirmedMembersCount: 5,
        description:
            'Overnight trek to ancient twin forts Shrivardhan and Manaranjan. Walking through lush Sahyadri trails, misty plateau, village homestay, and traditional Maharashtrian pithla-bhakri.',
        tags: const ['Trek', 'Adventure', 'Nature'],
        status: 'published',
        hostDisplayName: DemoUsers.neha.displayName,
        hostAvatarPath: DemoUsers.neha.avatarPath,
        hostIsVerified: DemoUsers.neha.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (5-7 AM)',
          'budget_level': 'Budget Friendly (₹2k-₹5k)',
          'pace': 'Action-Packed (all day)',
          'planning_style': 'Structured (detailed itinerary)',
          'compatibility': ['Sahyadri hiker', 'Monsoon lover', 'Budget friendly'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 3)),
      ),

      // 4. Kasol Backpacking & Chalal (In 14 Days, Open - 2 spots left)
      Trip(
        id: 'trip-kasol',
        hostId: DemoUsers.ishaan.id,
        destination: 'Kasol, Himachal Pradesh',
        startDate: now.add(const Duration(days: 14)),
        endDate: now.add(const Duration(days: 19)),
        budget: 12000.0,
        maxMembers: 4,
        confirmedMembersCount: 2,
        description:
            'Parvati valley escape: riverside walks through pine forests to Chalal village, hot springs at Manikaran, cozy wooden cafes, and an optional day hike towards Tosh.',
        tags: const ['Nature', 'Trek', 'Adventure'],
        status: 'published',
        hostDisplayName: DemoUsers.ishaan.displayName,
        hostAvatarPath: DemoUsers.ishaan.avatarPath,
        hostIsVerified: DemoUsers.ishaan.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Night Owl (10 AM+)',
          'budget_level': 'Balanced (₹10k-₹20k)',
          'pace': 'Relaxed (1-2 spots/day)',
          'planning_style': 'Spontaneous (go with flow)',
          'compatibility': ['Himalaya lover', 'Backpacker', 'Cafes'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 5)),
      ),

      // 5. Rishikesh River Rafting & Cliff Jump (Next 7 Days, Open - 3 spots left)
      Trip(
        id: 'trip-rishikesh',
        hostId: DemoUsers.siddharth.id,
        destination: 'Rishikesh, Uttarakhand',
        startDate: now.add(const Duration(days: 6)),
        endDate: now.add(const Duration(days: 10)),
        budget: 11500.0,
        maxMembers: 6,
        confirmedMembersCount: 3,
        description:
            'Adrenaline packed getaway on the Ganges: 26km Grade III+ white-water rafting from Marine Drive, cliff jumping, Ganga aarti at Parmarth Niketan, and beach volleyball by riverside camps.',
        tags: const ['Adventure', 'Nature', 'Weekend'],
        status: 'published',
        hostDisplayName: DemoUsers.siddharth.displayName,
        hostAvatarPath: DemoUsers.siddharth.avatarPath,
        hostIsVerified: DemoUsers.siddharth.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (6-8 AM)',
          'budget_level': 'Balanced (₹10k-₹20k)',
          'pace': 'Action-Packed (all day)',
          'planning_style': 'Structured (detailed itinerary)',
          'compatibility': ['Adrenaline seeker', 'Water sports', 'Adventure'],
        },
        requiresVerifiedMembers: true,
        createdAt: now.subtract(const Duration(days: 8)),
      ),

      // 6. Manali Mountain Escape & Solang (In 20 Days, FULL - 0 spots left)
      Trip(
        id: 'trip-manali',
        hostId: DemoUsers.kabir.id,
        destination: 'Manali, Himachal Pradesh',
        startDate: now.add(const Duration(days: 20)),
        endDate: now.add(const Duration(days: 26)),
        budget: 16500.0,
        maxMembers: 4,
        confirmedMembersCount: 4,
        description:
            'Scenic drive up to Solang Valley, day hike to Jogini Waterfalls through deodar forests, exploring Old Manali cafes, and driving up to Atal Tunnel for mountain views.',
        tags: const ['Nature', 'Road trip', 'Adventure'],
        status: 'published',
        hostDisplayName: DemoUsers.kabir.displayName,
        hostAvatarPath: DemoUsers.kabir.avatarPath,
        hostIsVerified: DemoUsers.kabir.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (5-7 AM)',
          'budget_level': 'Balanced (₹10k-₹20k)',
          'pace': 'Action-Packed (all day)',
          'planning_style': 'Structured (detailed itinerary)',
          'compatibility': ['Mountain explorer', 'Pine forests', 'Active'],
        },
        requiresVerifiedMembers: true,
        createdAt: now.subtract(const Duration(days: 12)),
      ),

      // 7. Road Trip to Mahabaleshwar & Panchgani (This Weekend, Open - 1 spot left)
      Trip(
        id: 'trip-mahabaleshwar',
        hostId: DemoUsers.rohan.id,
        destination: 'Mahabaleshwar, Maharashtra',
        startDate: thisSaturday,
        endDate: thisSunday,
        budget: 5200.0,
        maxMembers: 4,
        confirmedMembersCount: 3,
        description:
            'Mumbai to Mahabaleshwar scenic highway drive. Fresh strawberry farms at Mapro Garden, panoramic valley viewpoints, Kate\'s Point, and misty evening at Venna Lake.',
        tags: const ['Road trip', 'Weekend', 'Nature'],
        status: 'published',
        hostDisplayName: DemoUsers.rohan.displayName,
        hostAvatarPath: DemoUsers.rohan.avatarPath,
        hostIsVerified: DemoUsers.rohan.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (6-8 AM)',
          'budget_level': 'Comfort (₹5k-₹10k)',
          'pace': 'Balanced (2-3 spots/day)',
          'planning_style': 'Semi-planned (key anchors only)',
          'compatibility': ['Road tripper', 'Scenic views', 'Foodie'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 2)),
      ),

      // 8. Gokarna Beach Trek & Cliffside Cafés (Next Month, Open - 3 spots left)
      Trip(
        id: 'trip-gokarna',
        hostId: DemoUsers.meera.id,
        destination: 'Gokarna, Karnataka',
        startDate: now.add(const Duration(days: 28)),
        endDate: now.add(const Duration(days: 32)),
        budget: 7800.0,
        maxMembers: 5,
        confirmedMembersCount: 2,
        description:
            'Trekking the five beaches: Om Beach, Half Moon Beach, Paradise Beach, and Kudle. Cliff jumping, beachside camping, watching dolphins at sunrise, and relaxing with books.',
        tags: const ['Beach', 'Trek', 'Nature'],
        status: 'published',
        hostDisplayName: DemoUsers.meera.displayName,
        hostAvatarPath: DemoUsers.meera.avatarPath,
        hostIsVerified: DemoUsers.meera.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (6-8 AM)',
          'budget_level': 'Balanced (₹5k-₹10k)',
          'pace': 'Relaxed (1-2 spots/day)',
          'planning_style': 'Spontaneous (go with flow)',
          'compatibility': ['Beach trekker', 'Peaceful vibe', 'Yoga friendly'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 7)),
      ),

      // 9. Udaipur Royal Lakes & Heritage Walk (In 16 Days, Open - 2 spots left)
      Trip(
        id: 'trip-udaipur',
        hostId: DemoUsers.vikram.id,
        destination: 'Udaipur, Rajasthan',
        startDate: now.add(const Duration(days: 16)),
        endDate: now.add(const Duration(days: 19)),
        budget: 14500.0,
        maxMembers: 4,
        confirmedMembersCount: 2,
        description:
            'City of Lakes: boat ride to Jagmandir palace, sunset dinner at Ambrai Ghat overlooking City Palace, visiting artisan workshops, and exploring Sajjangarh Monsoon Palace.',
        tags: const ['Culture', 'City', 'Weekend'],
        status: 'published',
        hostDisplayName: DemoUsers.vikram.displayName,
        hostAvatarPath: DemoUsers.vikram.avatarPath,
        hostIsVerified: DemoUsers.vikram.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Balanced (8-10 AM)',
          'budget_level': 'Comfort (₹10k-₹20k)',
          'pace': 'Relaxed (1-2 spots/day)',
          'planning_style': 'Structured (detailed itinerary)',
          'compatibility': ['Heritage lover', 'Palace architecture', 'Photography'],
        },
        requiresVerifiedMembers: true,
        createdAt: now.subtract(const Duration(days: 9)),
      ),

      // 10. Coorg Coffee Estate Trails (Next 10 Days, Open - 2 spots left)
      Trip(
        id: 'trip-coorg',
        hostId: DemoUsers.pooja.id,
        destination: 'Coorg, Karnataka',
        startDate: now.add(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 14)),
        budget: 9800.0,
        maxMembers: 5,
        confirmedMembersCount: 3,
        description:
            'Stay inside a 50-acre heritage coffee estate. Cupping sessions, walking along misty streams, visiting Abbey Falls, and savoring homemade Kodava cuisine.',
        tags: const ['Nature', 'Weekend', 'Road trip'],
        status: 'published',
        hostDisplayName: DemoUsers.pooja.displayName,
        hostAvatarPath: DemoUsers.pooja.avatarPath,
        hostIsVerified: DemoUsers.pooja.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (6-8 AM)',
          'budget_level': 'Balanced (₹5k-₹10k)',
          'pace': 'Relaxed (1-2 spots/day)',
          'planning_style': 'Semi-planned (key anchors only)',
          'compatibility': ['Coffee lover', 'Nature walks', 'Peaceful'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 4)),
      ),

      // 11. Spiti Valley High Altitude 4x4 Circuit (Next Month, Open - 2 spots left)
      Trip(
        id: 'trip-spiti',
        hostId: DemoUsers.varun.id,
        destination: 'Spiti Valley, Himachal Pradesh',
        startDate: now.add(const Duration(days: 35)),
        endDate: now.add(const Duration(days: 44)),
        budget: 26500.0,
        maxMembers: 5,
        confirmedMembersCount: 3,
        description:
            'Full 4x4 overland expedition via Shimla, Kinnaur, Tabo Monastery, Key Gompa, and Chandratal lake. Stargazing at Komic (world\'s highest motorable village) and high-pass crossings.',
        tags: const ['Road trip', 'Adventure', 'Nature'],
        status: 'published',
        hostDisplayName: DemoUsers.varun.displayName,
        hostAvatarPath: DemoUsers.varun.avatarPath,
        hostIsVerified: DemoUsers.varun.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (5-7 AM)',
          'budget_level': 'Premium (₹20k+)',
          'pace': 'Action-Packed (all day)',
          'planning_style': 'Structured (detailed itinerary)',
          'compatibility': ['Overlanding', 'High altitude', 'Astro photographer'],
        },
        requiresVerifiedMembers: true,
        createdAt: now.subtract(const Duration(days: 15)),
      ),

      // 12. Kashmir Autumn Dal Lake & Valleys (In 22 Days, Open - 2 spots left)
      Trip(
        id: 'trip-kashmir',
        hostId: DemoUsers.shreya.id,
        destination: 'Srinagar & Pahalgam, Kashmir',
        startDate: now.add(const Duration(days: 22)),
        endDate: now.add(const Duration(days: 28)),
        budget: 24000.0,
        maxMembers: 4,
        confirmedMembersCount: 2,
        description:
            'Chasing golden chinar trees in Kashmir: traditional wooden houseboat stay on Dal Lake, early morning floating flower market, Betaab Valley, and Aru Valley nature walks.',
        tags: const ['Nature', 'Culture', 'Photography'],
        status: 'published',
        hostDisplayName: DemoUsers.shreya.displayName,
        hostAvatarPath: DemoUsers.shreya.avatarPath,
        hostIsVerified: DemoUsers.shreya.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (6-8 AM)',
          'budget_level': 'Premium (₹20k+)',
          'pace': 'Balanced (2-3 spots/day)',
          'planning_style': 'Structured (detailed itinerary)',
          'compatibility': ['Photographer', 'Scenic valleys', 'Houseboat stay'],
        },
        requiresVerifiedMembers: true,
        createdAt: now.subtract(const Duration(days: 10)),
      ),

      // 13. Lonavala Sunrise Trek & Waterfalls (Next 5 Days, Open - 2 spots left)
      Trip(
        id: 'trip-lonavala',
        hostId: DemoUsers.kunal.id,
        destination: 'Lonavala & Khandala Ghats',
        startDate: now.add(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 6)),
        budget: 2200.0,
        maxMembers: 6,
        confirmedMembersCount: 4,
        description:
            'Early morning sunrise drive from Mumbai to Tiger Point. Easy waterfall hike, stopping for piping hot chai and sweet corn, visiting Bhushi Dam, and returning before evening traffic.',
        tags: const ['Trek', 'Weekend', 'Nature'],
        status: 'published',
        hostDisplayName: DemoUsers.kunal.displayName,
        hostAvatarPath: DemoUsers.kunal.avatarPath,
        hostIsVerified: DemoUsers.kunal.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (5-7 AM)',
          'budget_level': 'Budget Friendly (₹2k-₹5k)',
          'pace': 'Action-Packed (all day)',
          'planning_style': 'Structured (detailed itinerary)',
          'compatibility': ['Morning person', 'Weekend getaway', 'Trekker'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 1)),
      ),

      // 14. Jaipur Pink City Heritage Walk (In 18 Days, Open - 1 spot left)
      Trip(
        id: 'trip-jaipur',
        hostId: DemoUsers.tanvi.id,
        destination: 'Jaipur, Rajasthan',
        startDate: now.add(const Duration(days: 18)),
        endDate: now.add(const Duration(days: 21)),
        budget: 8900.0,
        maxMembers: 4,
        confirmedMembersCount: 3,
        description:
            'Exploring the Pink City\'s gems: Amer Fort light show, rooftop chai facing Hawa Mahal, block-printing workshops at Bagru, and Rajasthani feast at LMB.',
        tags: const ['Culture', 'City', 'Weekend'],
        status: 'published',
        hostDisplayName: DemoUsers.tanvi.displayName,
        hostAvatarPath: DemoUsers.tanvi.avatarPath,
        hostIsVerified: DemoUsers.tanvi.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Balanced (8-10 AM)',
          'budget_level': 'Comfort (₹5k-₹10k)',
          'pace': 'Balanced (2-3 spots/day)',
          'planning_style': 'Semi-planned (key anchors only)',
          'compatibility': ['Culture explorer', 'Street food', 'Art & craft'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 6)),
      ),

      // 15. Munnar Misty Hills & Tea Plantations (In 25 Days, Open - 2 spots left)
      Trip(
        id: 'trip-munnar',
        hostId: DemoUsers.divya.id,
        destination: 'Munnar, Kerala',
        startDate: now.add(const Duration(days: 25)),
        endDate: now.add(const Duration(days: 29)),
        budget: 13500.0,
        maxMembers: 4,
        confirmedMembersCount: 2,
        description:
            'Walk through emerald green tea plantations of Kolukkumalai (world\'s highest organic tea garden). Sunrise jeep safari, visiting Eravikulam National Park, and homemade Kerala meals.',
        tags: const ['Nature', 'Weekend', 'Road trip'],
        status: 'published',
        hostDisplayName: DemoUsers.divya.displayName,
        hostAvatarPath: DemoUsers.divya.avatarPath,
        hostIsVerified: DemoUsers.divya.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Early Bird (6-8 AM)',
          'budget_level': 'Balanced (₹10k-₹20k)',
          'pace': 'Relaxed (1-2 spots/day)',
          'planning_style': 'Semi-planned (key anchors only)',
          'compatibility': ['Nature lover', 'Tea gardens', 'Peaceful'],
        },
        requiresVerifiedMembers: true,
        createdAt: now.subtract(const Duration(days: 11)),
      ),

      // 16. Khandala Cliffside Camping & Stargazing (Hosted by Omkar - Current User!)
      Trip(
        id: 'trip-khandala',
        hostId: DemoUsers.currentUser.id,
        destination: 'Khandala, Maharashtra',
        startDate: nextSaturday,
        endDate: nextSunday,
        budget: 3500.0,
        maxMembers: 4,
        confirmedMembersCount: 2,
        description:
            'Overnight cliffside campsite overlooking the Western Ghats. Campfire barbecue, acoustic music, telescope for stargazing, and an unhurried morning espresso above the clouds.',
        tags: const ['Weekend', 'Adventure', 'Nature'],
        status: 'published',
        hostDisplayName: DemoUsers.currentUser.displayName,
        hostAvatarPath: DemoUsers.currentUser.avatarPath,
        hostIsVerified: DemoUsers.currentUser.isVerified,
        hostTravelStyle: DemoUsers.currentUser.travelStyle,
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 3)),
      ),

      // 17. Dudhsagar Waterfalls Monsoon Drive (Hosted by Omkar - Current User!)
      Trip(
        id: 'trip-dudhsagar',
        hostId: DemoUsers.currentUser.id,
        destination: 'Dudhsagar, Goa Border',
        startDate: now.add(const Duration(days: 12)),
        endDate: now.add(const Duration(days: 15)),
        budget: 6800.0,
        maxMembers: 4,
        confirmedMembersCount: 3,
        description:
            'Off-road 4x4 trail to the base of the mighty four-tiered Dudhsagar waterfall. Swimming in natural pools, dense Bhagwan Mahavir sanctuary trails, and spicy Goan curries.',
        tags: const ['Road trip', 'Adventure', 'Nature'],
        status: 'published',
        hostDisplayName: DemoUsers.currentUser.displayName,
        hostAvatarPath: DemoUsers.currentUser.avatarPath,
        hostIsVerified: DemoUsers.currentUser.isVerified,
        hostTravelStyle: DemoUsers.currentUser.travelStyle,
        requiresVerifiedMembers: true,
        createdAt: now.subtract(const Duration(days: 5)),
      ),

      // 18. Pawna Lake Sunset Kayaking (Completed Past Trip!)
      Trip(
        id: 'trip-pawna',
        hostId: DemoUsers.ananya.id,
        destination: 'Pawna Lake, Pune',
        startDate: now.subtract(const Duration(days: 14)),
        endDate: now.subtract(const Duration(days: 13)),
        budget: 2900.0,
        maxMembers: 5,
        confirmedMembersCount: 5,
        description:
            'Lakeside glamping, sunset kayaking across tranquil waters, open-air movie screening under fairy lights, and morning breakfast by the water.',
        tags: const ['Weekend', 'Adventure', 'Nature'],
        status: 'completed',
        hostDisplayName: DemoUsers.ananya.displayName,
        hostAvatarPath: DemoUsers.ananya.avatarPath,
        hostIsVerified: DemoUsers.ananya.isVerified,
        hostTravelStyle: const {
          'wake_up_time': 'Night Owl (10 AM+)',
          'budget_level': 'Budget Friendly (₹2k-₹5k)',
          'pace': 'Relaxed (1-2 spots/day)',
          'planning_style': 'Semi-planned (key anchors only)',
          'compatibility': ['Lake lover', 'Kayaking', 'Chill weekend'],
        },
        requiresVerifiedMembers: false,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ];
  }

  /// Helper to lookup trip by ID
  static Trip? getById(String id) {
    if (id == 'demo-1') {
      return Trip(
        id: 'demo-1',
        hostId: 'host-1',
        destination: 'Lisbon, Portugal',
        startDate: DateTime.now().add(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 37)),
        budget: 950.0,
        maxMembers: 5,
        description: 'Coastal walks and neighborhood dinners.',
        tags: const ['Beach', 'City'],
      );
    }
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
