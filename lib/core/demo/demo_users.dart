import '../../features/account/domain/user_profile.dart';
import 'demo_images.dart';

/// Curated fictional travellers representing an active Mumbai-first travel network.
abstract final class DemoUsers {
  /// The logged-in primary demo user.
  static final UserProfile currentUser = UserProfile(
    id: 'user-omkar',
    displayName: 'Omkar Anarse',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarOmkar,
    isVerified: true,
    bio:
        'Building apps, chasing sunsets and always planning the next weekend escape across Maharashtra and the Himalayas.',
    travelStyle: const {
      'pace': 'Balanced (2-3 spots/day)',
      'wake_up_time': 'Early Bird (6-8 AM)',
      'budget_level': 'Balanced (₹5k-₹10k)',
      'planning_style': 'Semi-planned (key anchors only)',
      'travel_type': 'Adventure & Road Trips',
      'trips_completed': 8,
      'trips_hosted': 3,
      'safety_status': 'Protected',
    },
    createdAt: DateTime(2024, 1, 15),
  );

  /// Aarav Mehta - Weekend explorer & adventure seeker (Verified)
  static final UserProfile aarav = UserProfile(
    id: 'user-aarav',
    displayName: 'Aarav Mehta',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarAarav,
    isVerified: true,
    bio:
        'Weekend explorer who loves mountains, coastal drives and discovering underrated cafés in Alibaug and Goa.',
    travelStyle: const {
      'pace': 'Balanced (2-3 spots/day)',
      'wake_up_time': 'Early Bird (6-8 AM)',
      'budget_level': 'Balanced (₹5k-₹10k)',
      'planning_style': 'Semi-planned (key anchors only)',
      'travel_type': 'Adventure, Trek, Road Trip',
      'age': 24,
      'trips_completed': 11,
      'trips_hosted': 4,
    },
    createdAt: DateTime(2024, 2, 10),
  );

  /// Riya Sen - Coastal lover, photographer & beach sunsets (Verified)
  static final UserProfile riya = UserProfile(
    id: 'user-riya',
    displayName: 'Riya Sen',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarRiya,
    isVerified: true,
    bio:
        'Architectural photographer. Chasing golden hour on Goan shores, boutique stays, and coastal road trips.',
    travelStyle: const {
      'pace': 'Relaxed (1-2 spots/day)',
      'wake_up_time': 'Balanced (8-10 AM)',
      'budget_level': 'Comfort (₹10k-₹20k)',
      'planning_style': 'Spontaneous (go with flow)',
      'travel_type': 'Beach, Culture, Photography',
      'age': 26,
      'trips_completed': 14,
      'trips_hosted': 5,
    },
    createdAt: DateTime(2024, 3, 5),
  );

  /// Kabir Malhotra - Himalayan trekker & high passes (Pending Review)
  static final UserProfile kabir = UserProfile(
    id: 'user-kabir',
    displayName: 'Kabir Malhotra',
    homeCity: 'Pune',
    avatarPath: DemoImages.avatarKabir,
    isVerified: false,
    bio:
        'Passionate about off-grid trails, Spiti circuits and high-altitude hiking. Always ready for a camp out under the stars.',
    travelStyle: const {
      'pace': 'Action-Packed (all day)',
      'wake_up_time': 'Early Bird (5-7 AM)',
      'budget_level': 'Backpacker (₹5k-₹10k)',
      'planning_style': 'Structured (detailed itinerary)',
      'travel_type': 'Trek, Adventure, Road Trip',
      'age': 28,
      'trips_completed': 9,
      'trips_hosted': 2,
    },
    createdAt: DateTime(2024, 4, 18),
  );

  /// Ananya Sharma - Cafe hopper & weekend getaways (Verified)
  static final UserProfile ananya = UserProfile(
    id: 'user-ananya',
    displayName: 'Ananya Sharma',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarAnanya,
    isVerified: true,
    bio:
        'UI designer. Love slow weekend retreats, artisanal coffee, and exploring the Western Ghats during monsoon.',
    travelStyle: const {
      'pace': 'Relaxed (1-2 spots/day)',
      'wake_up_time': 'Night Owl (10 AM+)',
      'budget_level': 'Budget Friendly (₹2k-₹5k)',
      'planning_style': 'Semi-planned (key anchors only)',
      'travel_type': 'Weekend, Nature, Cafes',
      'age': 23,
      'trips_completed': 6,
      'trips_hosted': 1,
    },
    createdAt: DateTime(2024, 5, 2),
  );

  /// Rohan Kapoor - Road trip enthusiast & foodie (Verified)
  static final UserProfile rohan = UserProfile(
    id: 'user-rohan',
    displayName: 'Rohan Kapoor',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarRohan,
    isVerified: true,
    bio:
        'SUV driver and food seeker. Always up for Konkan coastal drives, Kolhapuri food stops, and scenic detours.',
    travelStyle: const {
      'pace': 'Balanced (2-3 spots/day)',
      'wake_up_time': 'Early Bird (6-8 AM)',
      'budget_level': 'Comfort (₹10k-₹20k)',
      'planning_style': 'Semi-planned (key anchors only)',
      'travel_type': 'Road Trip, Nature, Foodie',
      'age': 27,
      'trips_completed': 12,
      'trips_hosted': 3,
    },
    createdAt: DateTime(2024, 1, 20),
  );

  /// Neha Joshi - Sahyadri monsoon hiker (Not Verified)
  static final UserProfile neha = UserProfile(
    id: 'user-neha',
    displayName: 'Neha Joshi',
    homeCity: 'Pune',
    avatarPath: DemoImages.avatarNeha,
    isVerified: false,
    bio:
        'Exploring Sahyadri forts, Rajmachi, Harishchandragad, and monsoon waterfalls. Budget-conscious solo backpacker.',
    travelStyle: const {
      'pace': 'Action-Packed (all day)',
      'wake_up_time': 'Early Bird (5-7 AM)',
      'budget_level': 'Budget Friendly (₹2k-₹5k)',
      'planning_style': 'Structured (detailed itinerary)',
      'travel_type': 'Trek, Monsoon, Nature',
      'age': 25,
      'trips_completed': 7,
      'trips_hosted': 2,
    },
    createdAt: DateTime(2024, 6, 12),
  );

  /// Vikram Singhania - Heritage lover & cultural explorer (Verified)
  static final UserProfile vikram = UserProfile(
    id: 'user-vikram',
    displayName: 'Vikram Singhania',
    homeCity: 'Pune',
    avatarPath: DemoImages.avatarVikram,
    isVerified: true,
    bio:
        'Historian at heart. Fond of royal palace architecture in Rajasthan, havelis in Udaipur, and local crafts.',
    travelStyle: const {
      'pace': 'Relaxed (1-2 spots/day)',
      'wake_up_time': 'Balanced (8-10 AM)',
      'budget_level': 'Comfort (₹10k-₹20k)',
      'planning_style': 'Structured (detailed itinerary)',
      'travel_type': 'Culture, Heritage, City',
      'age': 32,
      'trips_completed': 19,
      'trips_hosted': 6,
    },
    createdAt: DateTime(2023, 11, 4),
  );

  /// Pooja Kulkarni - Coffee lover & nature retreat explorer (Verified)
  static final UserProfile pooja = UserProfile(
    id: 'user-pooja',
    displayName: 'Pooja Kulkarni',
    homeCity: 'Pune',
    avatarPath: DemoImages.avatarPooja,
    isVerified: true,
    bio:
        'Nature retreats in Coorg and Chikmagalur. Enjoy quiet mornings with artisanal filter coffee and lush green trails.',
    travelStyle: const {
      'pace': 'Relaxed (1-2 spots/day)',
      'wake_up_time': 'Early Bird (6-8 AM)',
      'budget_level': 'Balanced (₹5k-₹10k)',
      'planning_style': 'Semi-planned (key anchors only)',
      'travel_type': 'Nature, Relaxed, Coffee',
      'age': 24,
      'trips_completed': 8,
      'trips_hosted': 2,
    },
    createdAt: DateTime(2024, 3, 22),
  );

  /// Siddharth Nair - Adventure & river rafting junkie (Verified)
  static final UserProfile siddharth = UserProfile(
    id: 'user-siddharth',
    displayName: 'Siddharth Nair',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarSiddharth,
    isVerified: true,
    bio:
        'White-water rafting in Rishikesh, cliff diving, and bungee jumping. Seeking fellow adrenaline seekers.',
    travelStyle: const {
      'pace': 'Action-Packed (all day)',
      'wake_up_time': 'Early Bird (6-8 AM)',
      'budget_level': 'Premium (₹20k+)',
      'planning_style': 'Structured (detailed itinerary)',
      'travel_type': 'Adventure, Sports, Water',
      'age': 29,
      'trips_completed': 15,
      'trips_hosted': 4,
    },
    createdAt: DateTime(2023, 9, 14),
  );

  /// Tanvi Deshmukh - Pink City enthusiast & foodie (Verified)
  static final UserProfile tanvi = UserProfile(
    id: 'user-tanvi',
    displayName: 'Tanvi Deshmukh',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarTanvi,
    isVerified: true,
    bio:
        'Fashion stylist exploring Jaipur bazaars, Rajasthani thalis, and Udaipur rooftop sunsets.',
    travelStyle: const {
      'pace': 'Balanced (2-3 spots/day)',
      'wake_up_time': 'Balanced (8-10 AM)',
      'budget_level': 'Comfort (₹10k-₹20k)',
      'planning_style': 'Semi-planned (key anchors only)',
      'travel_type': 'Culture, City, Shopping',
      'age': 26,
      'trips_completed': 10,
      'trips_hosted': 3,
    },
    createdAt: DateTime(2024, 2, 28),
  );

  /// Aditya Varma - Biker & Spiti road explorer (Pending Review)
  static final UserProfile aditya = UserProfile(
    id: 'user-aditya',
    displayName: 'Aditya Varma',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarAditya,
    isVerified: false,
    bio:
        'Cruiser motorcycle rider. Riding the Manali-Leh-Spiti loop and Western Ghats twisties.',
    travelStyle: const {
      'pace': 'Action-Packed (all day)',
      'wake_up_time': 'Early Bird (5-7 AM)',
      'budget_level': 'Premium (₹20k+)',
      'planning_style': 'Semi-planned (key anchors only)',
      'travel_type': 'Road Trip, Biking, Mountains',
      'age': 30,
      'trips_completed': 13,
      'trips_hosted': 2,
    },
    createdAt: DateTime(2024, 6, 1),
  );

  /// Meera Patel - Gokarna cliff walker & beach camper (Verified)
  static final UserProfile meera = UserProfile(
    id: 'user-meera',
    displayName: 'Meera Patel',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarMeera,
    isVerified: true,
    bio:
        'Beach hopper who prefers peaceful Gokarna Kudle beach and Om beach over crowded spots. Loves yoga and reading by the waves.',
    travelStyle: const {
      'pace': 'Relaxed (1-2 spots/day)',
      'wake_up_time': 'Early Bird (6-8 AM)',
      'budget_level': 'Balanced (₹5k-₹10k)',
      'planning_style': 'Spontaneous (go with flow)',
      'travel_type': 'Beach, Trek, Sunset',
      'age': 27,
      'trips_completed': 11,
      'trips_hosted': 3,
    },
    createdAt: DateTime(2024, 4, 11),
  );

  /// Ishaan Roy - Kasol backpacker (Not Verified)
  static final UserProfile ishaan = UserProfile(
    id: 'user-ishaan',
    displayName: 'Ishaan Roy',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarArjun,
    isVerified: false,
    bio:
        'Parvati valley regular. Trekking to Kheerganga, Tosh, and Chalal. Staying in cozy riverside wooden homestays.',
    travelStyle: const {
      'pace': 'Relaxed (1-2 spots/day)',
      'wake_up_time': 'Night Owl (10 AM+)',
      'budget_level': 'Budget Friendly (₹2k-₹5k)',
      'planning_style': 'Spontaneous (go with flow)',
      'travel_type': 'Backpacking, Nature, Trek',
      'age': 25,
      'trips_completed': 5,
      'trips_hosted': 1,
    },
    createdAt: DateTime(2024, 7, 1),
  );

  /// Shreya Bhatt - Kashmir & mountain visual creator (Verified)
  static final UserProfile shreya = UserProfile(
    id: 'user-shreya',
    displayName: 'Shreya Bhatt',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarShreya,
    isVerified: true,
    bio:
        'Documenting the golden chinar trees of Kashmir, shikaras on Dal lake, and mountain valleys. Seeking travel buddies with a camera.',
    travelStyle: const {
      'pace': 'Balanced (2-3 spots/day)',
      'wake_up_time': 'Early Bird (6-8 AM)',
      'budget_level': 'Premium (₹20k+)',
      'planning_style': 'Structured (detailed itinerary)',
      'travel_type': 'Nature, Photography, Valleys',
      'age': 24,
      'trips_completed': 9,
      'trips_hosted': 2,
    },
    createdAt: DateTime(2024, 3, 14),
  );

  /// Kunal Patil - Lonavala waterfall chaser & cyclist (Verified)
  static final UserProfile kunal = UserProfile(
    id: 'user-kunal',
    displayName: 'Kunal Patil',
    homeCity: 'Pune',
    avatarPath: DemoImages.avatarKunal,
    isVerified: true,
    bio:
        'Cycling up Bhor Ghat, trail running in Lonavala and discovering secret waterfalls around Khandala.',
    travelStyle: const {
      'pace': 'Action-Packed (all day)',
      'wake_up_time': 'Early Bird (5-7 AM)',
      'budget_level': 'Balanced (₹5k-₹10k)',
      'planning_style': 'Structured (detailed itinerary)',
      'travel_type': 'Trek, Weekend, Cycling',
      'age': 28,
      'trips_completed': 16,
      'trips_hosted': 5,
    },
    createdAt: DateTime(2023, 12, 10),
  );

  /// Divya Rao - Tea garden walker & Kerala explorer (Verified)
  static final UserProfile divya = UserProfile(
    id: 'user-divya',
    displayName: 'Divya Rao',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarDevika,
    isVerified: true,
    bio:
        'Misty tea gardens of Munnar, spice plantations, and Ayurvedic wellness stays. Quiet and contemplative travel.',
    travelStyle: const {
      'pace': 'Relaxed (1-2 spots/day)',
      'wake_up_time': 'Early Bird (6-8 AM)',
      'budget_level': 'Comfort (₹10k-₹20k)',
      'planning_style': 'Semi-planned (key anchors only)',
      'travel_type': 'Nature, Relaxed, Wellness',
      'age': 29,
      'trips_completed': 12,
      'trips_hosted': 3,
    },
    createdAt: DateTime(2024, 1, 30),
  );

  /// Nikhil Shah - Nightlife, food trails & weekend trips (Pending Review)
  static final UserProfile nikhil = UserProfile(
    id: 'user-nikhil',
    displayName: 'Nikhil Shah',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarRahul,
    isVerified: false,
    bio:
        'Exploring Goa shacks, Pune microbreweries, and Mumbai street food legends. Good vibes only.',
    travelStyle: const {
      'pace': 'Balanced (2-3 spots/day)',
      'wake_up_time': 'Night Owl (10 AM+)',
      'budget_level': 'Balanced (₹5k-₹10k)',
      'planning_style': 'Spontaneous (go with flow)',
      'travel_type': 'Foodie, Nightlife, Weekend',
      'age': 26,
      'trips_completed': 7,
      'trips_hosted': 1,
    },
    createdAt: DateTime(2024, 6, 20),
  );

  /// Sneha More - Budget Sahyadri hiker (Not Verified)
  static final UserProfile sneha = UserProfile(
    id: 'user-sneha',
    displayName: 'Sneha More',
    homeCity: 'Pune',
    avatarPath: DemoImages.avatarSneha,
    isVerified: false,
    bio:
        'Student trekker exploring Lohagad, Visapur, and Devkund on state transport buses and sharing rides.',
    travelStyle: const {
      'pace': 'Action-Packed (all day)',
      'wake_up_time': 'Early Bird (5-7 AM)',
      'budget_level': 'Budget Friendly (₹2k-₹5k)',
      'planning_style': 'Spontaneous (go with flow)',
      'travel_type': 'Trek, Budget, Nature',
      'age': 23,
      'trips_completed': 4,
      'trips_hosted': 0,
    },
    createdAt: DateTime(2024, 8, 5),
  );

  /// Varun Iyer - High-altitude Himalayan expeditioner (Verified)
  static final UserProfile varun = UserProfile(
    id: 'user-varun',
    displayName: 'Varun Iyer',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarVarun,
    isVerified: true,
    bio:
        'Spiti Valley 4x4 overland guide and astro-photographer. Passionate about rough terrains and clear night skies.',
    travelStyle: const {
      'pace': 'Action-Packed (all day)',
      'wake_up_time': 'Early Bird (5-7 AM)',
      'budget_level': 'Premium (₹20k+)',
      'planning_style': 'Structured (detailed itinerary)',
      'travel_type': 'Road Trip, High Altitude, Astro',
      'age': 31,
      'trips_completed': 22,
      'trips_hosted': 8,
    },
    createdAt: DateTime(2023, 8, 19),
  );

  /// Natasha Sethi - Boutique retreats & palace stays (Verified)
  static final UserProfile natasha = UserProfile(
    id: 'user-natasha',
    displayName: 'Natasha Sethi',
    homeCity: 'Mumbai',
    avatarPath: DemoImages.avatarIshita,
    isVerified: true,
    bio:
        'Curating boutique haveli stays in Udaipur and beach villas in South Goa. Love slow luxury and rich architecture.',
    travelStyle: const {
      'pace': 'Relaxed (1-2 spots/day)',
      'wake_up_time': 'Balanced (8-10 AM)',
      'budget_level': 'Premium (₹20k+)',
      'planning_style': 'Structured (detailed itinerary)',
      'travel_type': 'Luxury, Heritage, Relaxed',
      'age': 28,
      'trips_completed': 17,
      'trips_hosted': 4,
    },
    createdAt: DateTime(2023, 10, 25),
  );

  /// Complete list of all 21 demo travellers.
  static final List<UserProfile> all = [
    currentUser,
    aarav,
    riya,
    kabir,
    ananya,
    rohan,
    neha,
    vikram,
    pooja,
    siddharth,
    tanvi,
    aditya,
    meera,
    ishaan,
    shreya,
    kunal,
    divya,
    nikhil,
    sneha,
    varun,
    natasha,
  ];

  /// Lookup a traveller profile by ID with fallback.
  static UserProfile getById(String id) {
    if (id == currentUser.id) return currentUser;
    return all.firstWhere(
      (u) => u.id == id,
      orElse: () => UserProfile(
        id: id,
        displayName: 'Fellow Traveller',
        homeCity: 'Mumbai',
        avatarPath: DemoImages.forUserId(id),
        isVerified: true,
      ),
    );
  }
}
