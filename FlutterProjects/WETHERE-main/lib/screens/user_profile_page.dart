import 'package:flutter/material.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/models/journey_model.dart';
import 'package:wethere/models/review_model.dart';
import 'package:wethere/services/journey_service.dart';
import 'package:wethere/services/review_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  final JourneyService _journeyService = JourneyService();
  final ReviewService _reviewService = ReviewService();
  late TabController _tabController;

  Future<Map<String, dynamic>>? _statsFuture;
  Future<Map<String, dynamic>>? _detailedReviewStatsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _statsFuture = _journeyService.getUserStats(widget.userId);
    _detailedReviewStatsFuture = _reviewService.getUserReviewStats(widget.userId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: _buildProfileHeader(),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.accentOrange,
                unselectedLabelColor: AppTheme.textHint,
                indicatorColor: AppTheme.accentOrange,
                tabs: const [
                  Tab(text: 'Past Journeys'),
                  Tab(text: 'Reviews'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPastJourneysList(),
            _buildReviewsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.dividerColor,
                border: Border.all(color: AppTheme.borderColor, width: 2),
                image: widget.userAvatar != null
                    ? DecorationImage(
                        image: NetworkImage(widget.userAvatar!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.userAvatar == null
                  ? Center(
                      child: Text(
                        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 40, color: AppTheme.textHint),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(widget.userName, style: AppTheme.headingM),
            const SizedBox(height: 16),
            
            // Stats FutureBuilder
            FutureBuilder<Map<String, dynamic>>(
              future: _statsFuture,
              builder: (context, snapshot) {
                final data = snapshot.data ?? {};
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
          ],
        ),
      ),
    );
  }

  Widget _buildPastJourneysList() {
    return StreamBuilder<List<JourneyModel>>(
      stream: _journeyService.getPastJourneysForUser(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final journeys = snapshot.data ?? [];
        if (journeys.isEmpty) {
          return _buildEmptyState(Icons.history, 'No past journeys');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: journeys.length,
          itemBuilder: (context, index) => _buildSimpleJourneyCard(journeys[index]),
        );
      },
    );
  }

  Widget _buildReviewsList() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildDetailedRatingStats(),
          StreamBuilder<List<ReviewModel>>(
            stream: _reviewService.getReviewsForUser(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              final reviews = snapshot.data ?? [];
              if (reviews.isEmpty) {
                return _buildEmptyState(Icons.star_outline, 'No reviews yet');
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: reviews.length,
                itemBuilder: (context, index) => _buildReviewCard(reviews[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedRatingStats() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _detailedReviewStatsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final stats = snapshot.data!;
        if (stats['totalReviews'] == 0) return const SizedBox();

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Review Categories', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildLinearStat('Punctuality', stats['punctualityAvg'] as double),
              _buildLinearStat('Friendliness', stats['friendlinessAvg'] as double),
              _buildLinearStat('Communication', stats['communicationAvg'] as double),
              _buildLinearStat('Safety', stats['safetyAvg'] as double),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinearStat(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: rating / 5.0,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.dividerColor,
                backgroundImage: review.reviewerAvatar != null ? NetworkImage(review.reviewerAvatar!) : null,
                child: review.reviewerAvatar == null ? Text(review.reviewerName[0]) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(review.reviewerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (review.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: AppTheme.accentOrange),
                        ],
                      ],
                    ),
                    Text(timeago.format(review.createdAt), style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 2),
                  Text(review.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review.comment, style: AppTheme.bodyRegular),
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                itemBuilder: (context, idx) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(review.photoUrls[idx], width: 80, height: 80, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
          if (review.hostResponse != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Host Response', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                  const SizedBox(height: 4),
                  Text(review.hostResponse!, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(text, style: AppTheme.headingS.copyWith(color: AppTheme.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleJourneyCard(JourneyModel model) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Image.asset(
                model.imageUrl.isNotEmpty ? model.imageUrl : 'assets/images/groceries.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(model.title, style: AppTheme.headingS, maxLines: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(model.location, style: AppTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {IconData? icon, bool isRating = false, double rating = 0.0}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.dividerColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: AppTheme.accentOrange), const SizedBox(height: 8)],
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentOrange)),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

