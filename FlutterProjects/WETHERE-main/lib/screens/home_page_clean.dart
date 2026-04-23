import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:wethere/screens/create_journey_page.dart';
import 'package:provider/provider.dart';
import 'package:wethere/providers/journey_provider.dart';
import 'package:wethere/models/journey_model.dart' as jm;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wethere/screens/login_page.dart';
import 'package:wethere/screens/create_profile_page.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/services/journey_service.dart';
import 'package:wethere/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;
  Position? _userPosition;
  List<Journey> _pastJourneysCache = [];
  StreamSubscription<List<jm.JourneyModel>>? _pastJourneysSub;
  List<Journey> _activeJourneysCache = [];
  StreamSubscription<List<jm.JourneyModel>>? _activeJourneysSub;
  StreamSubscription<List<jm.JourneyModel>>? _exploreSub;
  List<Journey> _createdJourneysCache = [];
  StreamSubscription<List<jm.JourneyModel>>? _createdJourneysSub;

  StreamSubscription<List<jm.JourneyModel>>? _appliedJourneysSub;
  List<Journey> _appliedJourneysCache = [];
  Set<String> _appliedJourneyIds = {};
  Set<String> _likedJourneyIds = {};
  
  final Map<String, jm.JourneyModel> _journeyModelsById = {};
  Map<String, String> _myApplicationStatus = {};
  StreamSubscription<QuerySnapshot>? _myApplicationsSub;

  int _unreadMessageCount = 0;
  StreamSubscription<QuerySnapshot>? _inboxSub;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  bool _emailVerified = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _checkEmailVerification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToExploreJourneys();
      
      final provider = Provider.of<JourneyProvider>(context, listen: false);
      _pastJourneysSub = provider.getMyPastJourneysStream().listen((models) {
        try {
          final converted = models.map((m) => _convertModelToJourney(m)).toList();
          if (converted.isNotEmpty && mounted) {
            setState(() {
              _pastJourneysCache = converted;
            });
          }
        } catch (e) {
          print('past subscription parse error: $e');
        }
      });

      _activeJourneysSub = provider.getMyJourneysStream().listen((models) {
        try {
          final converted = models.map((m) => _convertModelToJourney(m)).toList();
          if (converted.isNotEmpty && mounted) {
            setState(() {
              _activeJourneysCache = converted;
            });
          }
        } catch (e) {
          print('active subscription parse error: $e');
        }
      });

      _createdJourneysSub = provider.getMyAllJourneysStream().listen((models) {
        try {
          final converted = models.map((m) => _convertModelToJourney(m)).toList();
          if (converted.isNotEmpty && mounted) {
            setState(() {
              _createdJourneysCache = converted;
            });
          }
        } catch (e) {
          print('created subscription parse error: $e');
        }
      });
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        _appliedJourneysSub = provider.getAppliedJourneysStream(userId).listen((models) {
           if (mounted) {
             setState(() {
              _appliedJourneysCache = models.map((m) => _convertModelToJourney(m)).toList();
               _appliedJourneyIds = models
                   .where((m) => m.id != null)
                   .map((m) => m.id!)
                   .toSet();
             });
           }
        });

        final chatService = ChatService();
        _inboxSub = chatService.getInboxStream().listen((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
             final data = doc.data() as Map<String, dynamic>;
             count += (data['unreadCount_$userId'] ?? 0) as int;
          }
          if (mounted) {
            setState(() {
              _unreadMessageCount = count;
            });
          }
        });
      }
      
      if (userId != null) {
        final appProvider = Provider.of<ApplicationProvider>(context, listen: false);
        _myApplicationsSub = appProvider.getUserApplications(userId).listen((snapshot) {
           if (mounted) {
             setState(() {
               for (var doc in snapshot.docs) {
                 final data = doc.data() as Map<String, dynamic>;
                 final jId = data['journeyId'] as String?;
                 final status = data['status'] as String?;
                 if (jId != null && status != null) {
                   _myApplicationStatus[jId] = status;
                 }
               }
             });
           }
        });

        provider.getLikedJourneyIdsStream().listen((ids) {
          if (mounted) {
            setState(() {
              _likedJourneyIds = ids;
            });
          }
        });
      }
    });
  }

  Future<void> _openMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encodedAddress";
    final url = Uri.parse(googleMapsUrl);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps. Please check your browser.')),
        );
      }
    } catch (e) {
      debugPrint('Error launching maps: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _exploreSub?.cancel();
    _pastJourneysSub?.cancel();
    _activeJourneysSub?.cancel();
    _createdJourneysSub?.cancel();
    _appliedJourneysSub?.cancel();
    _myApplicationsSub?.cancel();
    _inboxSub?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (mounted) {
        setState(() {
          _emailVerified = refreshed?.emailVerified ?? false;
        });
      }
    }
  }

  Set<jm.CompensationType> _selectedCompensationFilters = {};
  String _priceRangeFilter = 'any';
  String _dateFilter = 'any';
  String _sortOption = 'recent';
  String _filterLocationText = '';
  GeoPoint? _filterCoordinates;

  List<Journey> _fetchedJourneys = [];
  List<Journey> get journeys => [..._sampleJourneys, ..._fetchedJourneys];

  final List<Journey> _sampleJourneys = [
    Journey(
      id: 1,
      hostName: 'Togetherness',
      hostAvatar: null,
      reviews: 7,
      rating: 5.0,
      imageUrl: 'assets/images/groceries.jpg',
      title: 'Join me for groceries shopping',
      location: 'Costco in Union, NJ',
      meetingPoint: 'in front of the store',
      date: 'November 18',
      time: '17-19h',
      compensationType: jm.CompensationType.withoutRemuneration,
    ),
    Journey(
      id: 2,
      hostName: 'Mike T.',
      hostAvatar: null,
      reviews: 12,
      rating: 4.8,
      imageUrl: 'assets/images/concert.jpg',
      title: 'Concert at Madison Square',
      location: 'Madison Square Garden, NYC',
      meetingPoint: 'main entrance',
      date: 'November 20',
      time: '19-23h',
      compensationType: jm.CompensationType.withGift,
      giftDescription: 'Free Ticket',
      giftEmoji: '🎫',
    ),
    Journey(
      id: 3,
      hostName: 'Sarah K.',
      hostAvatar: null,
      reviews: 5,
      rating: 5.0,
      imageUrl: 'assets/images/dinner.jpg',
      title: 'Dinner companion needed',
      location: 'Nice Italian Restaurant, NYC',
      meetingPoint: 'inside near window',
      date: 'November 19',
      time: '19-21h',
      compensationType: jm.CompensationType.withGift,
      giftDescription: 'Dinner Covered',
      giftEmoji: '🍽️',
    ),
    Journey(
      id: 4,
      hostName: 'Alex M.',
      hostAvatar: null,
      reviews: 8,
      rating: 4.9,
      imageUrl: 'assets/images/movie.jpg',
      title: 'Movie night buddy',
      location: 'AMC Theater, Brooklyn',
      meetingPoint: 'theater lobby',
      date: 'November 21',
      time: '20-23h',
      compensationType: jm.CompensationType.withGift,
      giftDescription: 'Free Movie',
      giftEmoji: '🎬',
    ),
    Journey(
      id: 5,
      hostName: 'Jake R.',
      hostAvatar: null,
      reviews: 15,
      rating: 4.7,
      imageUrl: 'assets/images/hiking.jpg',
      title: 'Weekend hiking adventure',
      location: 'Bear Mountain, NY',
      meetingPoint: 'parking lot entrance',
      date: 'November 20',
      time: '8-14h',
      compensationType: jm.CompensationType.withoutRemuneration,
    ),
    Journey(
      id: 6,
      hostName: 'Lisa P.',
      hostAvatar: null,
      reviews: 3,
      rating: 5.0,
      imageUrl: 'assets/images/coffee.jpg',
      title: 'Coffee & conversation',
      location: 'Starbucks Downtown',
      meetingPoint: 'inside near window',
      date: 'November 19',
      time: '10-12h',
      compensationType: jm.CompensationType.withGift,
      giftDescription: 'Coffee On Me',
      giftEmoji: '☕',
    ),
    Journey(
      id: 7,
      hostName: 'Tom H.',
      hostAvatar: null,
      reviews: 9,
      rating: 4.6,
      imageUrl: 'assets/images/basketball.jpg',
      title: 'Basketball game companion',
      location: 'Barclays Center, Brooklyn',
      meetingPoint: 'gate 3 entrance',
      date: 'November 22',
      time: '19-22h',
      compensationType: jm.CompensationType.withGift,
      giftDescription: 'Free Ticket',
      giftEmoji: '🏀',
    ),
    Journey(
      id: 8,
      hostName: 'Chris B.',
      hostAvatar: null,
      reviews: 4,
      rating: 4.8,
      imageUrl: 'assets/images/gym.jpg',
      title: 'Gym workout buddy',
      location: 'Planet Fitness, Manhattan',
      meetingPoint: 'front desk',
      date: 'November 18',
      time: '7-9h',
      compensationType: jm.CompensationType.withoutRemuneration,
    ),
    Journey(
      id: 9,
      hostName: 'Emily W.',
      hostAvatar: null,
      reviews: 6,
      rating: 5.0,
      imageUrl: 'assets/images/brunch.jpg',
      title: 'Sunday brunch companion',
      location: 'The Breakfast Club, SoHo',
      meetingPoint: 'front entrance',
      date: 'November 24',
      time: '11-13h',
      compensationType: jm.CompensationType.withGift,
      giftDescription: 'Brunch',
      giftEmoji: '🥞',
    ),
    Journey(
      id: 10,
      hostName: 'David L.',
      hostAvatar: null,
      reviews: 11,
      rating: 4.9,
      imageUrl: 'assets/images/museum.jpg',
      title: 'Museum visit together',
      location: 'MoMA, NYC',
      meetingPoint: 'main lobby',
      date: 'November 23',
      time: '14-17h',
      compensationType: jm.CompensationType.withGift,
      giftDescription: 'Free Entry',
      giftEmoji: '🎨',
    ),
  ];

  void _subscribeToExploreJourneys() {
    final provider = Provider.of<JourneyProvider>(context, listen: false);
    _exploreSub?.cancel();
    _exploreSub = provider.getJourneysStream(
      compensationFilters: _selectedCompensationFilters.toList(),
      priceRange: _priceRangeFilter == 'any' ? null : _priceRangeFilter,
      dateFilter: _dateFilter == 'any' ? null : _dateFilter,
      sortBy: _sortOption,
      searchQuery: _searchQuery,
    ).listen((models) {
      if (mounted) {
        setState(() {
          _fetchedJourneys = models.map((m) => _convertModelToJourney(m)).toList();
        });
      }
    });
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return;
      } 

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userPosition = position;
        });
        
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          try {
             FirebaseFirestore.instance.collection('users').doc(uid).update({
              'lastLocation': GeoPoint(position.latitude, position.longitude),
              'locationUpdatedAt': FieldValue.serverTimestamp(),
            });
          } catch(e) {
             print('Could not update user location: $e');
          }
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Journey _convertModelToJourney(jm.JourneyModel m) {
    if (m.id != null) {
      _journeyModelsById[m.id!] = m;
    }
    
    final DateTime start = m.startTime;
    final DateTime end = m.endTime;
    final DateTime date = m.date;
    final String dateStr = '${date.month}-${date.day}-${date.year}';
    final String timeStr = '${start.hour}-${end.hour}h';

    final map = m.toUiMap();
    final int generatedId = (map['id'] as String?)?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    
    return Journey(
      id: generatedId,
      firestoreId: m.id,
      hostUserId: m.hostUserId,
      hostName: m.hostName,
      hostAvatar: m.hostAvatar,
      reviews: m.hostReviewCount,
      rating: m.hostRating,
      imageUrl: m.imageUrl.isNotEmpty ? m.imageUrl : 'assets/images/groceries.jpg',
      title: m.title,
      location: m.location,
      meetingPoint: m.meetingPoint,
      date: dateStr,
      time: timeStr,
      startTime: start,
      endTime: end,
      compensationType: m.compensationType,
      giftDescription: m.giftDescription,
      giftEmoji: m.giftEmoji,
      giftValue: m.giftValue,
      locationCoordinates: m.locationCoordinates,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.accentOrange.withValues(alpha: 0.05),
              Colors.white,
              AppTheme.accentOrange.withValues(alpha: 0.03),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!_emailVerified)
                Container(
                  color: AppTheme.accentOrange,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Please verify your email to continue',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShadButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Verification email sent!')),
                            );
                          }
                        },
                        child: const Text('Resend', style: TextStyle(color: AppTheme.accentOrange)),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.outline(
                        onPressed: _checkEmailVerification,
                        child: const Text("I've verified", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildCurrentTab()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _currentTab == 0
          ? Container(
              decoration: BoxDecoration(
                color: AppTheme.accentOrange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ShadButton(
                onPressed: _showCreateJourneyDialog,
                child: const Icon(Icons.add, size: 28, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case 0:
        return _buildExploreTab();
      case 1:
        return _buildMyJourneysTab();
      case 2:
        return _buildInboxTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildExploreTab();
    }
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.explore_outlined, Icons.explore, 'Explore'),
            _buildNavItem(1, Icons.list_alt_outlined, Icons.list_alt, 'My Journeys'),
            _buildNavItem(2, Icons.mail_outline, Icons.mail, 'Inbox', badgeCount: _unreadMessageCount),
            _buildNavItem(3, Icons.person_outline, Icons.person, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, {int badgeCount = 0}) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppTheme.accentOrange : AppTheme.textHint,
                size: 26,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? AppTheme.accentOrange : AppTheme.textHint,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTab() {
    final filteredJourneys = _getFilteredAndSortedJourneys();
    final activeFilterCount = _getActiveFilterCount();
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _currentTab = 3),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.dividerColor,
                    image: FirebaseAuth.instance.currentUser?.photoURL != null
                        ? DecorationImage(
                            image: NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: FirebaseAuth.instance.currentUser?.photoURL == null
                      ? const Icon(Icons.person, color: AppTheme.textHint)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F5F5),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        setState(() {
                          _searchQuery = value;
                        });
                        _subscribeToExploreJourneys();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search Journeys',
                      hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: AppTheme.accentOrange),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _subscribeToExploreJourneys();
                            },
                          )
                        : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                children: [
                  IconButton(
                    onPressed: _showFilterModal,
                    icon: Icon(Icons.tune, color: AppTheme.primaryDark),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                    ),
                  ),
                  if (activeFilterCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$activeFilterCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        if (activeFilterCount > 0 || _sortOption != 'recent')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (activeFilterCount > 0)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._buildActiveFilterChips(),
                        const SizedBox(width: 8),
                        ShadButton.outline(
                          onPressed: _clearAllFilters,
                          child: Text('Clear All', style: TextStyle(color: AppTheme.accentOrange, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredJourneys.length} journeys found',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textHint),
              ),
              DropdownButton<String>(
                value: _sortOption,
                underline: const SizedBox(),
                icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                items: const [
                  DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
                  DropdownMenuItem(value: 'soonest', child: Text('Soonest')),
                  DropdownMenuItem(value: 'highestPay', child: Text('Highest Pay')),
                ],
                onChanged: (value) => setState(() => _sortOption = value ?? 'recent'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: filteredJourneys.isEmpty
              ? _buildEmptyFilterState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredJourneys.length,
                  itemBuilder: (context, index) => _buildJourneyCard(filteredJourneys[index]),
                ),
        ),
      ],
    );
  }

  List<Journey> _getFilteredAndSortedJourneys() {
    List<Journey> filtered = journeys.where((j) {
      if (_selectedCompensationFilters.isNotEmpty) {
        if (!_selectedCompensationFilters.contains(j.compensationType)) return false;
      }
      
      if (_priceRangeFilter != 'any' && j.compensationType == jm.CompensationType.withGift) {
        final value = j.giftValue ?? 0;
        switch (_priceRangeFilter) {
          case 'under15':
            if (value >= 15) return false;
            break;
          case '15to25':
            if (value < 15 || value > 25) return false;
            break;
          case '25to40':
            if (value < 25 || value > 40) return false;
            break;
          case 'over40':
            if (value <= 40) return false;
            break;
        }
      }
      
      return true;
    }).toList();

    switch (_sortOption) {
      case 'soonest':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'highestPay':
        filtered.sort((a, b) => (b.giftValue ?? 0).compareTo(a.giftValue ?? 0));
        break;
      case 'nearest':
        final targetLat = _filterCoordinates?.latitude ?? _userPosition?.latitude;
        final targetLng = _filterCoordinates?.longitude ?? _userPosition?.longitude;

        if (targetLat != null && targetLng != null) {
           filtered.sort((a, b) {
             double distA = 99999999;
             double distB = 99999999;
             
             if (a.locationCoordinates != null) {
               distA = Geolocator.distanceBetween(
                 targetLat, targetLng,
                 a.locationCoordinates!.latitude, a.locationCoordinates!.longitude
               );
             }
             
             if (b.locationCoordinates != null) {
               distB = Geolocator.distanceBetween(
                  targetLat, targetLng,
                  b.locationCoordinates!.latitude, b.locationCoordinates!.longitude
               );
             }
             return distA.compareTo(distB);
           });
        }
        break;
        
      case 'recent':
      default:
        final tLat = _filterCoordinates?.latitude ?? _userPosition?.latitude;
        final tLng = _filterCoordinates?.longitude ?? _userPosition?.longitude;

        if (tLat != null && tLng != null) {
           filtered.sort((a, b) {
             double distA = 99999999;
             double distB = 99999999;
             if (a.locationCoordinates != null) distA = Geolocator.distanceBetween(tLat, tLng, a.locationCoordinates!.latitude, a.locationCoordinates!.longitude);
             if (b.locationCoordinates != null) distB = Geolocator.distanceBetween(tLat, tLng, b.locationCoordinates!.latitude, b.locationCoordinates!.longitude);
             return distA.compareTo(distB);
           });
        }
        break;
    }

    return filtered;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCompensationFilters.isNotEmpty) count += _selectedCompensationFilters.length;
    if (_priceRangeFilter != 'any') count++;
    if (_dateFilter != 'any') count++;
    if (_filterLocationText.isNotEmpty) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  List<Widget> _buildActiveFilterChips() {
    List<Widget> chips = [];
    
    if (_searchQuery.isNotEmpty) {
      chips.add(_buildFilterChip('🔍 $_searchQuery', () {
        setState(() {
          _searchQuery = '';
          _searchController.clear();
        });
        _subscribeToExploreJourneys();
      }));
    }
    
    if (_filterLocationText.isNotEmpty) {
      chips.add(_buildFilterChip('📍 $_filterLocationText', () {
        setState(() {
          _filterLocationText = '';
          _filterCoordinates = null;
        });
      }));
    }

    for (var type in _selectedCompensationFilters) {
      String label;
      switch (type) {
        case jm.CompensationType.withoutRemuneration:
          label = 'No Remuneration';
          break;
        case jm.CompensationType.withGift:
          label = 'With Gift';
          break;
      }
      chips.add(_buildFilterChip(label, () {
        setState(() => _selectedCompensationFilters.remove(type));
      }));
    }
    
    if (_priceRangeFilter != 'any') {
      String label;
      switch (_priceRangeFilter) {
        case 'under15':
          label = 'Under \$15/h';
          break;
        case '15to25':
          label = '\$15-\$25/h';
          break;
        case '25to40':
          label = '\$25-\$40/h';
          break;
        case 'over40':
          label = '\$40+/h';
          break;
        default:
          label = '';
      }
      if (label.isNotEmpty) {
        chips.add(_buildFilterChip(label, () {
          setState(() => _priceRangeFilter = 'any');
        }));
      }
    }
    
    if (_dateFilter != 'any') {
      String label;
      switch (_dateFilter) {
        case 'today':
          label = 'Today';
          break;
        case 'thisWeek':
          label = 'This Week';
          break;
        case 'thisWeekend':
          label = 'Weekend';
          break;
        case 'nextWeek':
          label = 'Next Week';
          break;
        default:
          label = '';
      }
      if (label.isNotEmpty) {
        chips.add(_buildFilterChip(label, () {
          setState(() => _dateFilter = 'any');
        }));
      }
    }
    
    return chips;
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: AppTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: AppTheme.accentOrange),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCompensationFilters.clear();
      _priceRangeFilter = 'any';
      _dateFilter = 'any';
      _filterLocationText = '';
      _filterCoordinates = null;
    });
  }

  Widget _buildEmptyFilterState() {
    final hasActiveFilters = _getActiveFilterCount() > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: hasActiveFilters
              ? [
                  Icon(Icons.search_off, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('No journeys match your filters',
                      style: AppTheme.headingM
                          .copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Try adjusting your filters',
                      style: AppTheme.bodyRegular),
                  const SizedBox(height: 24),
                  ShadButton(
                    onPressed: _clearAllFilters,
                    child: const Text('Try adjusting your filters'),
                  ),
                ]
              : [
                  Icon(Icons.markunread_mailbox_outlined,
                      size: 72, color: AppTheme.textHint),
                  const SizedBox(height: 20),
                  Text('No journeys available right now',
                      style: AppTheme.headingM
                          .copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Be the first to create one!',
                      style: AppTheme.bodyRegular
                          .copyWith(color: AppTheme.textHint)),
                  const SizedBox(height: 28),
                  ShadButton(
                    onPressed: _showCreateJourneyDialog,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('Create Journey', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  void _showFilterModal() {
    Set<jm.CompensationType> tempCompFilters = Set.from(_selectedCompensationFilters);
    String tempPriceRange = _priceRangeFilter;
    String tempDateFilter = _dateFilter;
    TextEditingController tempLocController = TextEditingController(text: _filterLocationText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: AppTheme.headingM),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text('📍 Location', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tempLocController,
                        decoration: InputDecoration(
                          hintText: 'Enter Zip Code or City',
                          prefixIcon: Icon(Icons.location_on, color: AppTheme.textHint),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          fillColor: AppTheme.dividerColor,
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),

                      const SizedBox(height: 16),
                      Text('💰 Compensation Type', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildCompFilterCheckbox(tempCompFilters, jm.CompensationType.withoutRemuneration, 'No Remuneration', setModalState),
                      _buildCompFilterCheckbox(tempCompFilters, jm.CompensationType.withGift, 'With Gift', setModalState),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      
                      const SizedBox(height: 16),
                      Text('💵 Price Range (hourly)', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildPriceRadio(tempPriceRange, 'any', 'Any price', (v) => setModalState(() => tempPriceRange = v)),
                      _buildPriceRadio(tempPriceRange, 'under15', 'Under \$15/hour', (v) => setModalState(() => tempPriceRange = v)),
                      _buildPriceRadio(tempPriceRange, '15to25', '\$15-\$25/hour', (v) => setModalState(() => tempPriceRange = v)),
                      _buildPriceRadio(tempPriceRange, '25to40', '\$25-\$40/hour', (v) => setModalState(() => tempPriceRange = v)),
                      _buildPriceRadio(tempPriceRange, 'over40', '\$40+/hour', (v) => setModalState(() => tempPriceRange = v)),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      
                      const SizedBox(height: 16),
                      Text('📅 Date', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDateRadio(tempDateFilter, 'any', 'Any time', (v) => setModalState(() => tempDateFilter = v)),
                      _buildDateRadio(tempDateFilter, 'today', 'Today', (v) => setModalState(() => tempDateFilter = v)),
                      _buildDateRadio(tempDateFilter, 'thisWeek', 'This week', (v) => setModalState(() => tempDateFilter = v)),
                      _buildDateRadio(tempDateFilter, 'thisWeekend', 'This weekend', (v) => setModalState(() => tempDateFilter = v)),
                      _buildDateRadio(tempDateFilter, 'nextWeek', 'Next week', (v) => setModalState(() => tempDateFilter = v)),
                    ],
                  ),
                ),
              ),
              
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () {
                        setModalState(() {
                          tempLocController.clear();
                          tempCompFilters.clear();
                          tempPriceRange = 'any';
                          tempDateFilter = 'any';
                        });
                      },
                      child: Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ShadButton(
                      onPressed: () async {
                        GeoPoint? newCoords;
                        String locText = tempLocController.text.trim();
                        
                        if (locText.isNotEmpty) {
                          if (kIsWeb) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Location search via city/zip is limited on web demo. Try searching on mobile!')),
                            );
                          } else {
                            try {
                              List<Location> locations = await locationFromAddress(locText);
                              if (locations.isNotEmpty) {
                                newCoords = GeoPoint(locations.first.latitude, locations.first.longitude);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not find location. Please check zip/city.')),
                                );
                              }
                              return;
                            }
                          }
                        }

                        if (mounted) {
                          setState(() {
                            _selectedCompensationFilters = tempCompFilters;
                            _priceRangeFilter = tempPriceRange;
                            _dateFilter = tempDateFilter;
                            _filterLocationText = locText;
                            _filterCoordinates = newCoords;
                            _sortOption = (_filterCoordinates != null || (_userPosition != null && locText.isEmpty)) ? 'nearest' : 'recent';
                          });
                          _subscribeToExploreJourneys();
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompFilterCheckbox(Set<jm.CompensationType> filters, jm.CompensationType type, String label, StateSetter setModalState) {
    return CheckboxListTile(
      value: filters.contains(type),
      onChanged: (v) {
        setModalState(() {
          if (v == true) {
            filters.add(type);
          } else {
            filters.remove(type);
          }
        });
      },
      title: Text(label, style: AppTheme.bodyRegular),
      activeColor: AppTheme.accentOrange,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildPriceRadio(String current, String value, String label, Function(String) onChanged) {
    return RadioListTile<String>(
      value: value,
      groupValue: current,
      onChanged: (v) => onChanged(v ?? 'any'),
      title: Text(label, style: AppTheme.bodyRegular),
      activeColor: AppTheme.accentOrange,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildDateRadio(String current, String value, String label, Function(String) onChanged) {
    return RadioListTile<String>(
      value: value,
      groupValue: current,
      onChanged: (v) => onChanged(v ?? 'any'),
      title: Text(label, style: AppTheme.bodyRegular),
      activeColor: AppTheme.accentOrange,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildImageErrorWidget(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket,
            size: 60,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(Journey journey) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (journey.hostUserId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfilePage(
                              userId: journey.hostUserId!,
                              userName: journey.hostName,
                              userAvatar: journey.hostAvatar,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.dividerColor,
                        image: journey.hostAvatar != null
                            ? DecorationImage(
                                image: NetworkImage(journey.hostAvatar!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: journey.hostAvatar == null
                          ? const Icon(Icons.person, color: AppTheme.textHint)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          journey.hostName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${journey.reviews} reviews',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < journey.rating.floor()
                                      ? Icons.star
                                      : (i <= journey.rating.ceil() && journey.rating % 1 != 0 ? Icons.star_half : Icons.star_border),
                                  color: AppTheme.accentOrange,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                    color: AppTheme.textHint,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reviews',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textHint,
                        ),
                      ),
                      Text(
                        '${journey.reviews}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rating',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textHint,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < journey.rating.floor()
                                ? Icons.star
                                : (i <= journey.rating.ceil() && journey.rating % 1 != 0 ? Icons.star_half : Icons.star_border),
                            color: AppTheme.accentOrange,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          color: const Color(0xFF2A4A5C),
                          child: journey.imageUrl.startsWith('http')
                              ? Image.network(
                                  journey.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildImageErrorWidget('Journey Image'),
                                )
                              : Image.asset(
                                  journey.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildImageErrorWidget('Asset Image'),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_likedJourneyIds.contains(journey.id.toString())) {
                                _likedJourneyIds.remove(journey.id.toString());
                              } else {
                                _likedJourneyIds.add(journey.id.toString());
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              _likedJourneyIds.contains(journey.id.toString())
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _likedJourneyIds.contains(journey.id.toString())
                                  ? Colors.red
                                  : AppTheme.textHint,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: journey.badgeColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (journey.compensationType == jm.CompensationType.withGift)
                                Text(
                                  journey.giftEmoji ?? '🎁',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              const SizedBox(width: 6),
                              Text(
                                  journey.badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: journey.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const WidgetSpan(child: SizedBox(width: 8)),
                          TextSpan(
                            text: journey.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textHint,
                            ),
                          TextSpan(text: ' Meet: ${journey.meetingPoint}. Date: ${journey.date}, ${journey.time}'),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _buildJourneyActionButton(context, journey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyActionButton(BuildContext context, Journey journey) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isHost = currentUser != null && journey.hostUserId == currentUser.uid;
    final isApplied = journey.firestoreId != null && _appliedJourneyIds.contains(journey.firestoreId);
    final jModelRaw = journey.firestoreId != null ? _journeyModelsById[journey.firestoreId!] : null;
    final isCompletedStatus = jModelRaw?.status == 'completed';
    final isTimePast = journey.endTime != null && DateTime.now().isAfter(journey.endTime!);
    final isPast = isTimePast || isCompletedStatus;

    if (isHost && !isPast) {
      final hasAcceptedApplicants = jModelRaw?.acceptedCompanionId != null;
      
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: ShadButton.outline(
                onPressed: () => _showApplicantsDialog(context, journey),
                child: Text(
                  'YOUR JOURNEY',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentOrange,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            if (!hasAcceptedApplicants) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppTheme.accentOrange),
                onPressed: () {
                  if (jModelRaw != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateJourneyPage(
                          existingJourney: jModelRaw,
                        ),
                      ),
                    );
                  }
                },
                tooltip: 'Edit Journey',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Journey?'),
                      content: const Text(
                        'Are you sure you want to delete this journey? This action cannot be undone and all applications will be removed.',
                      ),
                      actions: [
                        ShadButton.outline(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ShadButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          backgroundColor: Colors.red,
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && journey.firestoreId != null) {
                    try {
                      await JourneyService().deleteJourney(journey.firestoreId!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Journey deleted successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error deleting journey: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                tooltip: 'Delete Journey',
              ),
            ],
          ],
        ),
      );
    }

    if (isApplied) {
      final status = _myApplicationStatus[journey.firestoreId] ?? 'applied';
      
      if (status == 'accepted') {
        final jModel = _journeyModelsById[journey.firestoreId];
        final now = DateTime.now();
        final startTime = jModel?.startTime ?? DateTime.now();
        final hoursUntilStart = startTime.difference(now).inHours;
        final isChatAvailable = hoursUntilStart <= 24;
        
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ShadButton(
            onPressed: isChatAvailable ? () async {
              if (journey.firestoreId != null && journey.hostUserId != null) {
                try {
                  final chatService = ChatService();
                  final chatId = await chatService.getOrCreateChat(
                    journey.firestoreId!,
                    journey.hostUserId!,
                    journeyTitle: journey.title,
                  );
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          chatId: chatId,
                          otherUserName: journey.hostName,
                          otherUserAvatar: journey.hostAvatar,
                          journeyTitle: journey.title,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error opening chat: $e')),
                    );
                  }
                }
              }
            } : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chat will be available 24 hours before the journey starts'),
                  backgroundColor: AppTheme.textSecondary,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  isChatAvailable ? 'ACCEPTED' : 'ACCEPTED (Chat in ${hoursUntilStart}h)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: isChatAvailable ? Colors.green : Colors.grey,
          ),
        );
      }
      
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: ShadButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'APPLIED',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    if (isPast) {
      if (journey.firestoreId == null) {
        return const SizedBox();
      }

      bool isParticipant = false;
      String revieweeId = '';
      String revieweeName = '';
      
      final jm = _journeyModelsById[journey.firestoreId];
      if (jm != null) {
        if (currentUser?.uid == journey.hostUserId) {
           isParticipant = true;
           if (jm.acceptedCompanionId != null) {
             revieweeId = jm.acceptedCompanionId!;
             revieweeName = 'Companion';
           }
        } else if (currentUser?.uid == jm.acceptedCompanionId) {
           isParticipant = true;
           revieweeId = journey.hostUserId ?? '';
           revieweeName = journey.hostName;
        }
      }

      if (revieweeId.isNotEmpty) {
        return FutureBuilder<ReviewModel?>(
          future: ReviewService().getReview(journey.firestoreId!, currentUser!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
               return const SizedBox(
                 width: double.infinity,
                 height: 44,
                 child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
               );
            }
            
            final existingReview = snapshot.data;
            final hasReviewed = existingReview != null;

            if (hasReviewed) {
               return SizedBox(
                 width: double.infinity,
                 height: 44,
                 child: ShadButton(
                   onPressed: () {
                     _showReviewDialog(context, existingReview);
                   },
                   backgroundColor: Colors.grey,
                   child: const Text('REVIEW SUBMITTED', style: TextStyle(
                     fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1
                   )),
                 )
               );
            } else {
               return SizedBox(
                 width: double.infinity,
                 height: 44,
                 child: ShadButton(
                   onPressed: () => _openReviewDialog(context, journey, revieweeName, revieweeId),
                   child: const Text('WRITE REVIEW', style: TextStyle(
                     fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1
                   )),
                 )
               );
            }
          },
        );
      }
      return const SizedBox(height: 44, child: Center(child: Text('Completed', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))));
    }

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ShadButton(
        onPressed: () {
          if (journey.firestoreId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This is a demo journey and cannot be applied to.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          final journeyModel = _journeyModelsById[journey.firestoreId];
          
          if (journeyModel != null) {
            _checkProfileAndProceed(
              actionType: 'join',
              onProceed: () => _handleApplyJourney(context, journeyModel),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to apply. Journey data not found.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: const Text(
          'APPLY',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, ReviewModel review) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: review.reviewerAvatar != null ? NetworkImage(review.reviewerAvatar!) : null,
              child: review.reviewerAvatar == null ? Text(review.reviewerName[0]) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('${review.reviewerName}', style: AppTheme.headingS)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 children: [
                   for (int i = 1; i <= 5; i++)
                     Icon(
                       i <= review.rating ? Icons.star : Icons.star_border,
                       color: Colors.amber,
                       size: 24,
                     ),
                   const SizedBox(width: 8),
                   Text(review.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                 ],
               ),
               const SizedBox(height: 16),
               if (review.punctualityRating != null || review.friendlinessRating != null) ...[
                 _buildReviewDetailRow('Punctuality', review.punctualityRating),
                 _buildReviewDetailRow('Friendliness', review.friendlinessRating),
                 _buildReviewDetailRow('Communication', review.communicationRating),
                 _buildReviewDetailRow('Safety', review.safetyRating),
                 const Divider(height: 24),
               ],
               Text(review.comment.isNotEmpty ? review.comment : 'No details provided.', style: AppTheme.bodyRegular),
               if (review.photoUrls.isNotEmpty) ...[
                 const SizedBox(height: 16),
                 SizedBox(
                   height: 100,
                   child: ListView.builder(
                     scrollDirection: Axis.horizontal,
                     itemCount: review.photoUrls.length,
                     itemBuilder: (context, idx) => Padding(
                       padding: const EdgeInsets.only(right: 8),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: Image.network(review.photoUrls[idx], width: 100, height: 100, fit: BoxFit.cover),
                       ),
                     ),
                   ),
                 ),
               ],
            ],
          ),
        ),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  Widget _buildReviewDetailRow(String label, double? rating) {
    if (rating == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Row(
            children: [
              const Icon(Icons.star, size: 12, color: Colors.amber),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _openReviewDialog(BuildContext context, Journey journey, String revieweeName, String revieweeId) {
    showDialog(
      context: context,
      builder: (ctx) => ReviewDialog(
        revieweeName: revieweeName,
        onSubmit: ({
          required double rating,
          required String comment,
          double? punctuality,
          double? friendliness,
          double? communication,
          double? safety,
          List<XFile>? photos,
        }) async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );

          try {
            final currentUser = FirebaseAuth.instance.currentUser;
            final reviewService = ReviewService();
            
            List<String> photoUrls = [];
            if (photos != null && photos.isNotEmpty) {
              for (var i = 0; i < photos.length; i++) {
                final ref = FirebaseStorage.instance
                    .ref()
                    .child('reviews')
                    .child('${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
                await ref.putData(await photos[i].readAsBytes());
                photoUrls.add(await ref.getDownloadURL());
              }
            }

            await reviewService.submitReview(ReviewModel(
              journeyId: journey.firestoreId!,
              reviewerId: currentUser!.uid,
              reviewerName: currentUser.displayName ?? 'User',
              revieweeId: revieweeId,
              rating: rating,
              comment: comment,
              punctualityRating: punctuality,
              friendlinessRating: friendliness,
              communicationRating: communication,
              safetyRating: safety,
              photoUrls: photoUrls,
            ));

            if (context.mounted) {
              Navigator.pop(context);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enhanced review submitted!'), backgroundColor: Colors.green)
              );
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red)
              );
            }
          }
        }
      )
    );
  }

  int _myJourneysSubTab = 0;

  Widget _buildMyJourneysTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Journeys', style: AppTheme.headingL),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ShadButton(
                  onPressed: () {
                    _showCreateJourneyDialog();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Create', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildSubTab(0, 'Active'),
              _buildSubTab(1, 'Applications'),
              _buildSubTab(2, 'Past'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _buildMyJourneysSubContent(),
        ),
      ],
    );
  }

  Widget _buildSubTab(int index, String label) {
    final isSelected = _myJourneysSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _myJourneysSubTab = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyJourneysSubContent() {
    switch (_myJourneysSubTab) {
      case 0:
        return _buildMergedActiveJourneys();
      case 1:
        return _buildAppliedJourneys();
      case 2:
        return _buildPastJourneys();
      default:
        return _buildMergedActiveJourneys();
    }
  }

  Widget _buildMergedActiveJourneys() {
    final now = DateTime.now();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    final acceptedAppliedJourneys = _appliedJourneysCache.where((j) {
      if (j.firestoreId == null) return false;
      final model = _journeyModelsById[j.firestoreId];
      if (model == null) return false;
      return model.acceptedCompanionId == userId;
    }).toList();

    final allJourneys = [..._activeJourneysCache, ...acceptedAppliedJourneys, ..._createdJourneysCache]; 
    final uniqueJourneys = {for (var j in allJourneys) j.id: j}.values.toList();
    
    final ongoing = uniqueJourneys.where((j) {
      if (j.startTime == null || j.endTime == null) return false;
      return !now.isBefore(j.startTime!) && !now.isAfter(j.endTime!);
    }).toList();

    final upcoming = uniqueJourneys.where((j) {
      if (j.startTime == null) return false;
      return j.startTime!.isAfter(now);
    }).toList();

    if (ongoing.isEmpty && upcoming.isEmpty) {
      return _buildEmptyState(
        icon: Icons.directions_walk,
        title: 'No active journeys',
        subtitle: "You don't have any ongoing or upcoming journeys.\nExplore or create one to get started!",
        actionLabel: 'Explore Journeys',
        onAction: () => setState(() => _currentTab = 0),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text('Ongoing', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary
          )),
        ),
        if (ongoing.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.timelapse, color: AppTheme.textHint),
                const SizedBox(width: 12),
                Text('No ongoing journeys', style: AppTheme.bodyRegular),
              ],
            ),
          )
        else
          ...ongoing.map((j) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildJourneyCard(j),
          )).toList(),

        const SizedBox(height: 12),

        const Padding(
          padding: EdgeInsets.only(bottom: 8.0, top: 8.0),
          child: Text('Upcoming', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary
          )),
        ),
        if (upcoming.isEmpty)
          Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.grey[100],
               borderRadius: BorderRadius.circular(12),
             ),
             child: Row(
               children: [
                 Icon(Icons.calendar_today, color: AppTheme.textHint),
                 const SizedBox(width: 12),
                 Text('No upcoming journeys', style: AppTheme.bodyRegular),
               ],
             ),
           )
        else
          ...upcoming.map((j) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildJourneyCard(j),
          )).toList(),
      ],
    );
  }

  Widget _buildAppliedJourneys() {
    final journeyProvider = context.read<JourneyProvider>();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<jm.JourneyModel>>(
      stream: journeyProvider.getAppliedJourneysStream(userId),
      builder: (context, snapshot) {
        List<Journey> appliedList = [];
        if (snapshot.hasData) {
          appliedList = snapshot.data!.map((m) => _convertModelToJourney(m)).toList();
        }

        final now = DateTime.now();
        final hostedActive = _createdJourneysCache.where((j) {
            return j.endTime == null || !j.endTime!.isBefore(now);
        }).toList();

        final combined = [...appliedList, ...hostedActive];
        final unique = {for (var j in combined) j.id: j}.values.toList();
        
        if (unique.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting && _createdJourneysCache.isEmpty) {
              return const Center(child: CircularProgressIndicator());
          }
          return _buildEmptyState(
            icon: Icons.assignment_ind,
            title: 'No applications',
            subtitle: "You haven't applied to any journeys,\nand no one has applied to yours yet.",
            actionLabel: 'Explore Journeys',
            onAction: () => setState(() => _currentTab = 0),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: unique.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final journey = unique[index];
            final isMyJourney = journey.hostUserId == userId;

            return GestureDetector(
              onTap: isMyJourney ? () => _showApplicantsDialog(context, journey) : null,
              child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(journey.title, style: AppTheme.labelMedium)),
                      if (isMyJourney)
                        Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                           decoration: BoxDecoration(
                             color: AppTheme.accentOrange.withValues(alpha: 0.1),
                             borderRadius: BorderRadius.circular(4),
                           ),
                           child: const Text('MY JOURNEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                        )
                      else
                        const Icon(Icons.outbound, size: 16, color: AppTheme.textHint),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(journey.location, style: AppTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                       Text(
                        journey.badgeText,
                        style: TextStyle(
                          color: journey.badgeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (isMyJourney)
                         const Text('Tap to view applicants', style: TextStyle(color: AppTheme.accentOrange, fontSize: 12))
                      else
                         _buildApplicationStatusBadge(journey.firestoreId),
                    ],
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  Widget _buildPastJourneys() {
    final provider = Provider.of<JourneyProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();

    return StreamBuilder<List<jm.JourneyModel>>(
      stream: provider.getMyPastJourneysStream(),
      builder: (context, snapshot) {
        List<Journey> hostedPast = [];
        if (snapshot.hasData && (snapshot.data ?? []).isNotEmpty) {
           hostedPast = snapshot.data!.map((m) => _convertModelToJourney(m)).toList();
           if (hostedPast.isNotEmpty) {
             _pastJourneysCache = hostedPast;
           }
        } else if (_pastJourneysCache.isNotEmpty) {
           hostedPast = _pastJourneysCache;
        }
        
        hostedPast = hostedPast.where((j) => j.endTime != null && j.endTime!.isBefore(now)).toList();

        List<Journey> acceptedAppliedPast = [];
        if (userId != null) {
          acceptedAppliedPast = _appliedJourneysCache.where((j) {
            if (j.endTime == null || !j.endTime!.isBefore(now)) return false;

            if (j.firestoreId != null && _journeyModelsById.containsKey(j.firestoreId)) {
               final m = _journeyModelsById[j.firestoreId]!;
               return m.acceptedCompanionId == userId;
            }
            return false;
          }).toList();
        }

        final allPast = [...hostedPast, ...acceptedAppliedPast];
        final uniquePast = {for (var j in allPast) j.id: j}.values.toList();
        
        uniquePast.sort((a, b) {
            final aTime = a.endTime ?? DateTime.now();
            final bTime = b.endTime ?? DateTime.now();
            return bTime.compareTo(aTime);
        });

        if (uniquePast.isEmpty) {
           if (snapshot.connectionState == ConnectionState.waiting && _pastJourneysCache.isEmpty && _appliedJourneysCache.isEmpty) {
              return const Center(child: CircularProgressIndicator());
           }
           return _buildEmptyState(
            icon: Icons.history,
            title: 'No past journeys',
            subtitle: 'Completed journeys you hosted\nor participated in will appear here.',
            actionLabel: null,
            onAction: null,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: uniquePast.length,
          itemBuilder: (context, idx) {
            return _buildJourneyCard(uniquePast[idx]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppTheme.textHint),
            const SizedBox(height: 24),
            Text(title, style: AppTheme.headingM.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AppTheme.bodyRegular,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ShadButton(
                onPressed: onAction,
                child: Text(actionLabel, style: AppTheme.labelMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationStatusBadge(String? journeyId) {
    String status = 'applied';
    if (journeyId != null && _myApplicationStatus.containsKey(journeyId)) {
      status = _myApplicationStatus[journeyId]!;
    }
    
    Color color;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    
    return Text(
      status.toUpperCase(), 
      style: TextStyle(
        color: color, 
        fontSize: 12, 
        fontWeight: FontWeight.bold
      )
    );
  }

  Future<void> _checkProfileAndProceed({
    required String actionType,
    required VoidCallback onProceed,
  }) async {
    if (!_emailVerified) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify your email before creating or joining journeys'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final complete = await isProfileComplete();
    if (complete) {
      onProceed();
    } else {
      if (mounted) {
        _showProfileIncompletePrompt(actionType);
      }
    }
  }

  void _showProfileIncompletePrompt(String actionType) {
    final actionText = actionType == 'create' ? 'create a journey' : 'join a journey';
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Complete Your Profile',
                style: AppTheme.headingM.copyWith(fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(dialogContext).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 40,
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You need to complete your profile before you can $actionText.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyRegular,
              ),
              const SizedBox(height: 8),
              Text(
                'It only takes a minute! Help others get to know you.',
                textAlign: TextAlign.center,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textHint),
              ),
            ],
          ),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ShadButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateProfilePage(
                      returnAfterComplete: true,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              child: const Text('Complete Profile'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateJourneyDialog() {
    _checkProfileAndProceed(
      actionType: 'create',
      onProceed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateJourneyPage()),
        );
      },
    );
  }

  void _handleApplyJourney(BuildContext context, jm.JourneyModel journey) {
    _submitApplication(context, journey, null);
  }

  Future<void> _submitApplication(
    BuildContext context,
    jm.JourneyModel journey,
    String? rewardChoice,
  ) async {
    final applicationProvider =
        context.read<ApplicationProvider>();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to apply');
      }

      await applicationProvider.applyToJourney(
        journey: journey,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'User',
        rewardChoice: rewardChoice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully applied to: ${journey.title}'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppTheme.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInboxTab() {
    final chatService = ChatService();
    final myId = FirebaseAuth.instance.currentUser?.uid;

    if (myId == null) {
      return Center(child: Text('Please log in to see messages', style: AppTheme.bodyRegular));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text('Inbox', style: AppTheme.headingL),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: chatService.getInboxStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Unable to load chats.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_outline, size: 80, color: AppTheme.textHint),
                      const SizedBox(height: 24),
                      Text(
                        'No messages yet',
                        style: AppTheme.headingM.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Chats with hosts and companions\nwill appear here.',
                        style: AppTheme.bodyRegular,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final chats = snapshot.data!.docs;

              return ListView.builder(
                itemCount: chats.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final data = chats[index].data() as Map<String, dynamic>;
                  final participants = List<String>.from(data['participants'] ?? []);
                  final otherUserId = participants.firstWhere((id) => id != myId, orElse: () => '');
                  final lastMessage = data['lastMessage'] ?? '';
                  final timestamp = data['updatedAt'] is Timestamp 
                      ? (data['updatedAt'] as Timestamp).toDate() 
                      : DateTime.now();
                  final journeyTitle = data['journeyTitle'] ?? 'Journey';
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                    builder: (context, userSnapshot) {
                      String otherName = 'User';
                      String? otherAvatar;
                      
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                         final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                         otherName = userData['displayName'] ?? userData['fullName'] ?? 'User';
                         otherAvatar = userData['photoURL'] ?? userData['avatarUrl'];
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                chatId: chats[index].id,
                                otherUserName: otherName,
                                otherUserAvatar: otherAvatar,
                                journeyTitle: journeyTitle,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
                                child: otherAvatar == null 
                                    ? Text(otherName[0].toUpperCase(), style: TextStyle(color: AppTheme.textSecondary))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(otherName, style: AppTheme.headingS.copyWith(fontSize: 16)),
                                        Text(
                                          timeago.format(timestamp, locale: 'en_short'),
                                          style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      journeyTitle,
                                      style: TextStyle(color: AppTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMessage,
                                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showApplicantsDialog(BuildContext context, Journey journey) {
    if (journey.firestoreId == null) return;

    final jModel = _journeyModelsById[journey.firestoreId];
    final isCompleted = jModel?.status == 'completed';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Applicants', style: AppTheme.headingM),
                   IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: Provider.of<ApplicationProvider>(context, listen: false)
                      .getApplicationsForJourney(journey.firestoreId!),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No applicants yet',
                          style: AppTheme.bodyRegular,
                        ),
                      );
                    }

                    final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);
                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['createdAt'] as Timestamp?;
                      final bTime = bData['createdAt'] as Timestamp?;
                      return (bTime ?? Timestamp.now()).compareTo(aTime ?? Timestamp.now());
                    });
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final applicationId = doc.id;
                        final applicantId = data['userId'];
                        final name = data['userName'] ?? 'Unknown User';
                        final reward = data['rewardChoice'] ?? 'N/A';
                        final status = data['status'] ?? 'applied';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.1),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: AppTheme.accentOrange)),
                          ),
                          title: Text(name, style: AppTheme.labelMedium),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Requested: $reward'),
                              Text(status.toUpperCase(), style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                color: status == 'accepted' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange)
                              )),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (status == 'accepted') ...[
                                Builder(
                                  builder: (context) {
                                    final now = DateTime.now();
                                    final startTime = jModel?.startTime ?? DateTime.now();
                                    final hoursUntilStart = startTime.difference(now).inHours;
                                    final isChatAvailable = hoursUntilStart <= 24;
                                    
                                    return IconButton(
                                      icon: Icon(
                                        Icons.chat_bubble_outline, 
                                        color: isChatAvailable ? AppTheme.textSecondary : Colors.grey.shade300,
                                      ),
                                      onPressed: isChatAvailable ? () async {
                                         final chatId = await ChatService().getOrCreateChat(
                                           journey.firestoreId!, 
                                           applicantId, 
                                           journeyTitle: journey.title
                                         );
                                         if (context.mounted) {
                                           Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
                                             chatId: chatId,
                                             otherUserName: name,
                                             journeyTitle: journey.title,
                                           )));
                                         }
                                      } : () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Chat will be available 24 hours before the journey starts'),
                                            backgroundColor: AppTheme.textSecondary,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                              if (status == 'applied') ...[
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                  onPressed: () {
                                    Provider.of<ApplicationProvider>(context, listen: false)
                                        .acceptApplication(applicationId, journey.firestoreId!, applicantId);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                  onPressed: () {
                                    Provider.of<ApplicationProvider>(context, listen: false)
                                        .rejectApplication(applicationId);
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (!isCompleted) ...[
                const SizedBox(height: 16),
                Center(
                  child: ShadButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Complete Journey?'),
                          content: const Text('This will move the journey to "Past" and allow participants to review each other. This action cannot be undone.'),
                          actions: [
                            ShadButton.outline(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ShadButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        if (context.mounted) {
                          await Provider.of<JourneyProvider>(context, listen: false).markAsComplete(journey.firestoreId!);
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: const Text('Mark as Complete', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileTab() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.surface,
                          Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.1),
                            backgroundImage: (userData['photo'] ?? FirebaseAuth.instance.currentUser?.photoURL) != null
                                ? NetworkImage(userData['photo'] ?? FirebaseAuth.instance.currentUser!.photoURL!)
                                : null,
                            child: (userData['photo'] ?? FirebaseAuth.instance.currentUser?.photoURL) == null
                                ? Icon(Icons.person, size: 42, color: AppTheme.accentOrange)
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            userData['firstName'] != null ? '${userData['firstName']} ${userData['lastName'] ?? ''}' : (FirebaseAuth.instance.currentUser?.displayName ?? 'Your Profile'), 
                            style: AppTheme.headingM.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            FirebaseAuth.instance.currentUser?.email ?? 'Complete your profile',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (userId != null)
                  FutureBuilder<Map<String, dynamic>>(
                    future: Provider.of<JourneyProvider>(context, listen: false).getJourneysStream().first.then((_) {
                      return JourneyService().getUserStats(userId);
                    }),
                    builder: (context, statsSnapshot) {
                      final data = statsSnapshot.data ?? {};
                      final rating = data['rating'] as double? ?? 0.0;
                      final reviews = data['reviews'] as int? ?? 0;
                      final created = data['created'] as int? ?? 0;
                      final participated = data['participated'] as int? ?? 0;

                      return Column(
                        children: [
                          Row(
                            children: [
                              _buildStatCard('Created', '$created', icon: Icons.create_new_folder_outlined),
                              const SizedBox(width: 12),
                              _buildStatCard('Guest', '$participated', icon: Icons.person_outline),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatCard('Reviews', '$reviews', icon: Icons.reviews_outlined),
                              const SizedBox(width: 12),
                              _buildStatCard('Rating', rating > 0 ? rating.toStringAsFixed(1) : '-', icon: Icons.star_outline, isRating: true, rating: rating),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 20),

                _buildSettingsTile(
                  'Edit Profile',
                  Icons.edit_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateProfilePage(
                          firstName: userData['firstName'] ?? '',
                          lastName: userData['lastName'] ?? '',
                          phone: userData['phone'] ?? '',
                          bio: userData['bio'] ?? '',
                          occupation: userData['occupation'],
                          photoUrl: userData['photo'],
                          returnAfterComplete: true,
                        ),
                      ),
                    ).then((value) {
                      if (value == true) setState(() {});
                    });
                  },
                ),

                _buildSettingsTile(
                  'Settings',
                  Icons.settings_outlined,
                  onTap: () => _showSettingsPage(),
                ),
                _buildSettingsTile(
                  'Help & Support',
                  Icons.help_outline,
                  onTap: () => _showHelpPage(),
                ),
                _buildSettingsTile(
                  'Logout',
                  Icons.logout,
                  onTap: () async {
                     await AuthService().signOut();
                     if (context.mounted) {
                       Navigator.of(context).pushAndRemoveUntil(
                         MaterialPageRoute(builder: (context) => const LoginPage()),
                         (route) => false,
                       );
                     }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final isDark = themeProvider.isDarkMode;
            return Scaffold(
              backgroundColor: isDark ? AppTheme.darkTheme.scaffoldBackgroundColor : AppTheme.backgroundColor,
              appBar: AppBar(
                title: const Text('Settings'),
                backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                elevation: 0,
              ),
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark 
                        ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                        : [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppTheme.accentOrange, Colors.orangeAccent],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
                              backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                                  ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                                  : null,
                              child: FirebaseAuth.instance.currentUser?.photoURL == null
                                  ? Icon(Icons.person, size: 40, color: AppTheme.accentOrange)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                            style: AppTheme.headingM.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.primaryDark,
                            ),
                          ),
                          Text(
                            FirebaseAuth.instance.currentUser?.email ?? '',
                            style: AppTheme.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    _buildSectionHeader('APP', isDark),
                    
                    _buildGlassTile(
                      isDark: isDark,
                      child: SwitchListTile(
                        title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Enable dark theme'),
                        value: isDark,
                        onChanged: (value) {
                          themeProvider.toggleTheme(value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value ? 'Dark mode enabled' : 'Dark mode disabled'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppTheme.accentOrange,
                            ),
                          );
                        },
                        secondary: Icon(
                          isDark ? Icons.brightness_2 : Icons.brightness_low,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader('ACCOUNT', isDark),
                    _buildGlassTile(
                      isDark: isDark,
                      child: Column(
                        children: [
                          _buildModernSettingsTile(
                            'Edit Profile',
                            Icons.person_outline,
                            isDark,
                            onTap: () async {
                              final userId = FirebaseAuth.instance.currentUser?.uid;
                              if (userId == null) return;
                              final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                              final userData = doc.data() ?? {};
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateProfilePage(
                                    firstName: userData['firstName'] ?? '',
                                    lastName: userData['lastName'] ?? '',
                                    phone: userData['phone'] ?? '',
                                    bio: userData['bio'] ?? '',
                                    occupation: userData['occupation'],
                                    photoUrl: userData['photo'],
                                    returnAfterComplete: true,
                                  ),
                                ),
                              ).then((value) {
                                if (value == true && mounted) setState(() {});
                              });
                            },
                          ),
                          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                          _buildModernSettingsTile(
                            'Change Phone Number',
                            Icons.phone_outlined,
                            isDark,
                            onTap: () => _showChangePhoneDialog(),
                          ),
                          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                          _buildModernSettingsTile(
                            'Change Email Address',
                            Icons.email_outlined,
                            isDark,
                            onTap: () => _showChangeEmailDialog(),
                          ),
                          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                          _buildModernSettingsTile(
                            'Change Password',
                            Icons.lock_outline,
                            isDark,
                            onTap: () => _showChangePasswordDialog(),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('PAYMENTS', isDark),
                    _buildGlassTile(
                      isDark: isDark,
                      child: Column(
                        children: [
                          _buildModernSettingsTile(
                            'Payment Methods',
                            Icons.payment_outlined,
                            isDark,
                            onTap: () => _showPaymentMethodsDialog(),
                          ),
                          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                          _buildModernSettingsTile(
                            'Add Funds / Payment Test',
                            Icons.add_card_outlined,
                            isDark,
                            onTap: () => _showPaymentTestDialog(),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('INFORMATION', isDark),
                    _buildGlassTile(
                      isDark: isDark,
                      child: Column(
                        children: [
                          _buildModernSettingsTile(
                            'About Us',
                            Icons.info_outline,
                            isDark,
                            onTap: () => _showAboutUs(),
                          ),
                          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                          _buildModernSettingsTile(
                            'Terms of Service',
                            Icons.description_outlined,
                            isDark,
                            onTap: () => _showTermsOfService(),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader('DANGER ZONE', isDark, isDanger: true),
                    _buildGlassTile(
                      isDark: isDark,
                      isDanger: true,
                      child: Column(
                        children: [
                          _buildModernSettingsTile(
                            'Deactivate Account',
                            Icons.person_off_outlined,
                            isDark,
                            onTap: () => _handleDeactivateAccount(),
                            isDanger: true,
                          ),
                          Divider(height: 1, color: Colors.red.withValues(alpha: 0.1)),
                          _buildModernSettingsTile(
                            'Delete Account',
                            Icons.delete_forever_outlined,
                            isDark,
                            onTap: () => _handleDeleteAccount(),
                            isDanger: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPaymentMethodsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Payment Methods', style: AppTheme.headingM),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: AppTheme.dividerColor,
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: const Row(
                       children: [
                         Icon(Icons.credit_card, color: AppTheme.accentOrange),
                         SizedBox(width: 16),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('Visa ending in 4242', style: TextStyle(fontWeight: FontWeight.bold)),
                               Text('Expires 12/26', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                             ],
                           ),
                         ),
                         Icon(Icons.check_circle, color: Colors.green, size: 20),
                       ],
                     ),
                   ),
                   const SizedBox(height: 16),
                   ShadButton(
                     onPressed: () {
                       PaymentService().makePayment(
                         context: context, 
                         amount: '0',
                         currency: 'usd'
                       );
                     },
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Icon(Icons.add),
                         const SizedBox(width: 8),
                         const Text('Add New Card'),
                       ],
                     ),
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentTestDialog() {
    final controller = TextEditingController(text: '10.00');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This is a demonstration of Stripe Payment Sheet.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Amount (USD)',
                prefixText: '\$ ',
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                ),
                fillColor: AppTheme.dividerColor,
                filled: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ShadButton(
            onPressed: () {
              Navigator.pop(context);
              final amountStr = controller.text;
              final amountInt = ((double.tryParse(amountStr) ?? 0) * 100).toInt().toString();

              PaymentService().makePayment(
                context: context, 
                amount: amountInt, 
                currency: 'usd'
              );
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  void _showChangePhoneDialog() {
    final currentPhoneController = TextEditingController();
    final newPhoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Phone Number'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Current Phone Number',
                  hintText: '+1 234 567 8900',
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppTheme.dividerColor,
                  filled: true,
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter current phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPhoneController,
                decoration: const InputDecoration(
                  labelText: 'New Phone Number',
                  hintText: '+1 234 567 8900',
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppTheme.dividerColor,
                  filled: true,
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter new phone number';
                  }
                  final phoneRegex = RegExp(r'^\+[1-9]\d{1,14}$');
                  if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
                    return 'Enter valid international format (e.g., +1234567890)';
                  }
                  if (value == currentPhoneController.text) {
                    return 'New number must be different';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) return;
                  
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                  final actualCurrentPhone = userDoc.data()?['phone']?.toString().replaceAll(' ', '');
                  final enteredCurrentPhone = currentPhoneController.text.replaceAll(' ', '');
                  
                  if (actualCurrentPhone != null && enteredCurrentPhone != actualCurrentPhone) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Current phone number is incorrect')),
                      );
                    }
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({'phone': newPhoneController.text});
                      
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone number updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAboutUs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('About WeThere', style: AppTheme.headingM),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Icon(Icons.people_alt, size: 80, color: AppTheme.accentOrange),
                    const SizedBox(height: 24),
                    Text(
                      'WeThere is more than just an app; it\'s a movement to reconnect the world, one journey at a time.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'In an increasingly digital world, genuine human connection is becoming rarer. WeThere helps you find companions for your daily activities—whether it\'s grocery shopping, going to the gym, attending a concert, or just a walk in the park.',
                      textAlign: TextAlign.justify,
                      style: AppTheme.bodyRegular,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Our mission is to combat loneliness by facilitating shared experiences. Hosts can offer compensation through rewards or hourly pay, and companions can find meaningful ways to spend their time while helping others.',
                      textAlign: TextAlign.justify,
                      style: AppTheme.bodyRegular,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome to WeThere!', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. User Safety', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('WeThere is a platform for connecting individuals. We are not responsible for user conduct. Always meet in public places.'),
              SizedBox(height: 8),
              Text('2. Payments & Rewards', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Any payment and reward agreements are strictly between the host and the companion. We do not process payments.'),
              SizedBox(height: 8),
              Text('3. Data Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('We value your privacy. Your data is used only to facilitate connections between users.'),
              SizedBox(height: 8),
              Text('4. Prohibited Content', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Inappropriate behavior or content will result in immediate account deletion.'),
              SizedBox(height: 16),
              Text('This is a simplified version of our Terms of Service for review purpose.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _handleDeactivateAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Account?'),
        content: const Text('Your profile will be hidden from other users. You can reactivate by logging in again.'),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ShadButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().deactivateAccount();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  void _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account Permanently?'),
        content: const Text('This action is IRREVERSIBLE. All your data, journeys, and applications will be permanently deleted.'),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ShadButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService().deleteAccount();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e. You might need to re-login to delete account.')),
          );
        }
      }
    }
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Email Address'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'New Email',
                  hintText: 'email@example.com',
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppTheme.dividerColor,
                  filled: true,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter new email';
                  if (!value.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Enter your current password',
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppTheme.dividerColor,
                  filled: true,
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please confirm your password';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  
                  final credential = EmailAuthProvider.credential(
                    email: user.email!, 
                    password: passwordController.text
                  );
                  await user.reauthenticateWithCredential(credential);
                  
                  await user.verifyBeforeUpdateEmail(emailController.text);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email sent to new address.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Verification failed: ${e.toString()}')),
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppTheme.dividerColor,
                  filled: true,
                ),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Enter current password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppTheme.dividerColor,
                  filled: true,
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter new password';
                  if (value.length < 6) return 'Password too short (min 6 chars)';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  
                  final credential = EmailAuthProvider.credential(
                    email: user.email!, 
                    password: currentPasswordController.text
                  );
                  await user.reauthenticateWithCredential(credential);
                  
                  await user.updatePassword(newPasswordController.text);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Update failed: ${e.toString()}')),
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showHelpPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Help & Support'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.accentOrange),
                  title: const Text('Chat with Support'),
                  subtitle: const Text('Get help from our AI assistant'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showChatbotDialog(),
                ),
              ),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.emergency, color: Colors.red.shade700),
                  title: Text('Emergency', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Call 911 or send emergency message'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showEmergencyOptions(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatbotDialog() {
    showDialog(
      context: context,
      builder: (context) => const SupportChatDialog(),
    );
  }

  void _showEmergencyOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    final userDoc = user != null 
        ? await FirebaseFirestore.instance.collection('users').doc(user.uid).get()
        : null;
    final userData = userDoc?.data();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.red),
              title: const Text('Call 911'),
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening phone dialer...')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.orange),
              title: const Text('Send Emergency Message'),
              subtitle: const Text('Auto-includes location & info'),
              onTap: () async {
                Navigator.pop(context);
                
                String locationText = 'Location unavailable';
                if (_userPosition != null) {
                  locationText = '${_userPosition!.latitude}, ${_userPosition!.longitude}';
                }
                
                final name = userData?['firstName'] ?? user?.displayName ?? 'Unknown';
                final phone = userData?['phone'] ?? 'Not provided';
                
                final message = 'I need help. Here is my location: $locationText, my phone number: $phone, my name: $name.';
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Emergency message ready:\n$message'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title, 
        style: AppTheme.bodySmall.copyWith(
          color: isDanger ? Colors.red.shade400 : (isDark ? Colors.white70 : AppTheme.textSecondary),
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.5,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildGlassTile({required bool isDark, required Widget child, bool isDanger = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? (isDanger ? Colors.red.withAlpha(13) : Colors.white.withAlpha(13))
            : (isDanger ? Colors.red.withAlpha(8) : Colors.white.withAlpha(8)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark 
            ? [] 
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  Widget _buildModernSettingsTile(String title, IconData icon, bool isDark, {VoidCallback? onTap, bool isDanger = false}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDanger 
                ? Colors.red.withAlpha(26) 
                : (isDark ? Colors.white.withAlpha(13) : AppTheme.dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon, 
            size: 20, 
            color: isDanger ? Colors.red : (isDark ? Colors.white : AppTheme.primaryDark),
          ),
        ),
        title: Text(
          title, 
          style: TextStyle(
            color: isDanger ? Colors.red : (isDark ? Colors.white : AppTheme.primaryDark),
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right, 
          size: 18, 
          color: isDanger ? Colors.red.withValues(alpha: 0.5) : (isDark ? Colors.white30 : AppTheme.textHint),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {IconData? icon, bool isRating = false, double rating = 0.0}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppTheme.accentOrange),
                ),
                const SizedBox(height: 8),
              ],
              if (isRating && rating > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 1; i <= 5; i++)
                      Icon(
                        i <= rating.floor() 
                            ? Icons.star 
                            : (i <= rating.ceil() && rating % 1 != 0 ? Icons.star_half : Icons.star_border),
                        color: Colors.amber,
                        size: 12,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label, 
                style: AppTheme.bodySmall.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentOrange.withValues(alpha: 0.15),
                          AppTheme.accentOrange.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon, 
                      size: 20, 
                      color: AppTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title, 
                      style: AppTheme.labelMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios, 
                      size: 12, 
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
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

class SupportChatDialog extends StatefulWidget {
  const SupportChatDialog({super.key});

  @override
  State<SupportChatDialog> createState() => _SupportChatDialogState();
}

class _SupportChatDialogState extends State<SupportChatDialog> {
  final List<Map<String, String>> _messages = [
    {'role': 'assistant', 'content': '🤖 Hi! I\'m your support assistant. How can I help you today?\n\n• Journey issues\n• Account problems\n• Payment questions\n• Connect to live agent'}
  ];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();
    
    await ChatService().forwardMessageToAdmins(text);

    if (mounted) {
      setState(() {
        _messages.add({
          'role': 'assistant', 
          'content': 'I have forwarded your message to our support team (valcourtjohnpeterson). They will review your request and get back to you shortly through the inbox!'
        });
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Support Chat'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser) const Text('🤖 ', style: TextStyle(fontSize: 18)),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? AppTheme.accentOrange.withValues(alpha: 0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(12).copyWith(
                                  bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                                  bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                                ),
                              ),
                              child: Text(
                                msg['content']!,
                                style: AppTheme.bodyRegular,
                              ),
                            ),
                          ),
                          if (isUser) const Padding(
                            padding: EdgeInsets.only(left: 8, top: 4),
                            child: Icon(Icons.person, size: 16, color: AppTheme.accentOrange),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _handleSendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: AppTheme.dividerColor,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _handleSendMessage,
                  icon: const Icon(Icons.send, color: AppTheme.accentOrange),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class Journey {
  final int id;
  final String? firestoreId;
  final String? hostUserId;
  final String hostName;
  final String? hostAvatar;
  final int reviews;
  final double rating;
  final String imageUrl;
  final String title;
  final String location;
  final String meetingPoint;
  final String date;
  final String time;
  final DateTime? endTime;
  
  final jm.CompensationType compensationType;
  final String? giftDescription;
  final String? giftEmoji;
  final double? giftValue;

  final DateTime? startTime;
  final GeoPoint? locationCoordinates;

  Journey({
    required this.id,
    this.firestoreId,
    this.hostUserId,
    required this.hostName,
    this.hostAvatar,
    required this.reviews,
    required this.rating,
    required this.imageUrl,
    required this.title,
    required this.location,
    required this.meetingPoint,
    required this.date,
    required this.time,
    this.startTime,
    this.endTime,
    required this.compensationType,
    this.giftDescription,
    this.giftEmoji,
    this.giftValue,
    this.locationCoordinates,
  });

  String get badgeText {
    switch (compensationType) {
      case jm.CompensationType.withoutRemuneration:
        return 'No Remuneration';
      case jm.CompensationType.withGift:
        return '${giftEmoji ?? '🎁'} ${giftDescription ?? 'Gift'}';
    }
  }

  Color get badgeColor {
    switch (compensationType) {
      case jm.CompensationType.withoutRemuneration:
        return const Color(0xFF9E9E9E);
      case jm.CompensationType.withGift:
        return const Color(0xFFFF6B35);
    }
  }
}
