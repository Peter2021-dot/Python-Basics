import 'dart:math';

class JourneyCategory {
  final String id;
  final String name;
  final String imagePath;
  final List<String> keywords;
  final String description;

  JourneyCategory({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.keywords,
    required this.description,
  });
}

class CategoryService {
  static final List<JourneyCategory> _categories = [
    JourneyCategory(
      id: 'entertainment',
      name: 'Entertainment',
      imagePath: 'assets/images/categories/entertainment.jpg',
      keywords: ['movie', 'concert', 'show', 'theater', 'music', 'performance', 'cinema', 'play'],
      description: 'Movies, concerts, shows, and live performances',
    ),
    JourneyCategory(
      id: 'shopping',
      name: 'Shopping',
      imagePath: 'assets/images/categories/shopping.jpg',
      keywords: ['mall', 'store', 'shop', 'buy', 'retail', 'market', 'boutique', 'grocery'],
      description: 'Mall visits, retail therapy, and market exploration',
    ),
    JourneyCategory(
      id: 'dining',
      name: 'Dining',
      imagePath: 'assets/images/categories/dining.jpg',
      keywords: ['restaurant', 'food', 'dinner', 'lunch', 'cafe', 'eat', 'cuisine', 'meal'],
      description: 'Restaurant visits and culinary experiences',
    ),
    JourneyCategory(
      id: 'outdoor',
      name: 'Outdoor Adventure',
      imagePath: 'assets/images/categories/outdoor.jpg',
      keywords: ['hike', 'park', 'nature', 'trail', 'camping', 'adventure', 'mountain', 'forest'],
      description: 'Hiking, parks, and outdoor activities',
    ),
    JourneyCategory(
      id: 'sports',
      name: 'Sports & Fitness',
      imagePath: 'assets/images/categories/sports.jpg',
      keywords: ['gym', 'workout', 'sport', 'game', 'fitness', 'exercise', 'training', 'match'],
      description: 'Sports events, gym sessions, and fitness activities',
    ),
    JourneyCategory(
      id: 'travel',
      name: 'Travel & Tourism',
      imagePath: 'assets/images/categories/travel.jpg',
      keywords: ['trip', 'vacation', 'tour', 'explore', 'destination', 'journey', 'city', 'tourism'],
      description: 'Sightseeing and travel experiences',
    ),
    JourneyCategory(
      id: 'social',
      name: 'Social Gathering',
      imagePath: 'assets/images/categories/social.jpg',
      keywords: ['party', 'meet', 'friends', 'gathering', 'event', 'celebration', 'group', 'social'],
      description: 'Meetups, parties, and social events',
    ),
    JourneyCategory(
      id: 'education',
      name: 'Education & Learning',
      imagePath: 'assets/images/categories/education.jpg',
      keywords: ['class', 'workshop', 'learn', 'study', 'course', 'seminar', 'training', 'school'],
      description: 'Workshops, classes, and learning experiences',
    ),
    JourneyCategory(
      id: 'wellness',
      name: 'Wellness & Relaxation',
      imagePath: 'assets/images/categories/wellness.jpg',
      keywords: ['spa', 'relax', 'wellness', 'meditation', 'yoga', 'massage', 'therapy', 'self-care'],
      description: 'Spa visits, yoga, and wellness activities',
    ),
    JourneyCategory(
      id: 'arts',
      name: 'Arts & Culture',
      imagePath: 'assets/images/categories/arts.jpg',
      keywords: ['museum', 'art', 'gallery', 'culture', 'exhibition', 'painting', 'sculpture', 'creative'],
      description: 'Museums, galleries, and cultural experiences',
    ),
    JourneyCategory(
      id: 'nightlife',
      name: 'Nightlife',
      imagePath: 'assets/images/categories/nightlife.jpg',
      keywords: ['bar', 'club', 'night', 'party', 'drinks', 'dance', 'music', 'evening'],
      description: 'Bars, clubs, and evening entertainment',
    ),
    JourneyCategory(
      id: 'volunteer',
      name: 'Volunteer & Community',
      imagePath: 'assets/images/categories/volunteer.jpg',
      keywords: ['volunteer', 'help', 'community', 'charity', 'service', 'give', 'support', 'cause'],
      description: 'Volunteer work and community service',
    ),
  ];

  static List<JourneyCategory> getAllCategories() {
    return List.from(_categories);
  }

  static JourneyCategory? getCategoryById(String id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  static JourneyCategory? findBestCategory(String title, String description) {
    String searchText = '${title.toLowerCase()} ${description.toLowerCase()}';
    
    JourneyCategory? bestMatch;
    int highestScore = 0;

    for (JourneyCategory category in _categories) {
      int score = 0;
      
      // Check for keyword matches
      for (String keyword in category.keywords) {
        if (searchText.contains(keyword)) {
          score += 2; // Keywords are worth more
        }
      }
      
      // Check for category name match
      if (searchText.contains(category.name.toLowerCase())) {
        score += 3; // Name match is worth more
      }
      
      // Add some randomness for variety
      score += Random().nextInt(2);
      
      if (score > highestScore) {
        highestScore = score;
        bestMatch = category;
      }
    }

    // If no good match found, return a random category
    if (highestScore == 0) {
      return _categories[Random().nextInt(_categories.length)];
    }

    return bestMatch;
  }

  static JourneyCategory getRandomCategory() {
    return _categories[Random().nextInt(_categories.length)];
  }
}
