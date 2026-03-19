import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wethere/theme/app_theme.dart';

class ReviewDialog extends StatefulWidget {
  final String revieweeName;
  final Function({
    required double rating,
    required String comment,
    double? punctuality,
    double? friendliness,
    double? communication,
    double? safety,
    List<XFile>? photos,
  }) onSubmit;

  const ReviewDialog({
    super.key,
    required this.revieweeName,
    required this.onSubmit,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double _overallRating = 0;
  double _punctuality = 0;
  double _friendliness = 0;
  double _communication = 0;
  double _safety = 0;
  
  final TextEditingController _commentController = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _selectedPhotos.add(image);
      });
    }
  }

  Widget _buildCategoryRating(String label, double rating, Function(double) onUpdate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyRegular),
          RatingBar.builder(
            initialRating: rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 24,
            itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: onUpdate,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rate Experience', style: AppTheme.headingM),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'How was your journey with ${widget.revieweeName}?',
                style: AppTheme.bodyRegular.copyWith(color: AppTheme.textSecondary),
              ),
              const Divider(height: 32),
              
              const Text('Overall Rating', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Center(
                child: RatingBar.builder(
                  initialRating: _overallRating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                  onRatingUpdate: (rating) => setState(() => _overallRating = rating),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text('Categories (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildCategoryRating('Punctuality', _punctuality, (v) => setState(() => _punctuality = v)),
              _buildCategoryRating('Friendliness', _friendliness, (v) => setState(() => _friendliness = v)),
              _buildCategoryRating('Communication', _communication, (v) => setState(() => _communication = v)),
              _buildCategoryRating('Safety', _safety, (v) => setState(() => _safety = v)),
              
              const SizedBox(height: 24),
              const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: AppTheme.buildInputDecoration(
                  hintText: 'Describe your experience...',
                ),
              ),
              
              const SizedBox(height: 24),
              const Text('Add Photos', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Icon(Icons.add_a_photo, color: AppTheme.textHint),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ..._selectedPhotos.map((file) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        // We need to import dart:io only for File() in non-web
                        // But since we are inside a MultiProvider or similar, we can conditionally show.
                        // Actually, let's use a cleaner way.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb 
                            ? Image.network(file.path, width: 70, height: 70, fit: BoxFit.cover)
                            : Image.file(File(file.path), width: 70, height: 70, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPhotos.remove(file)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _overallRating > 0 
                      ? () {
                          widget.onSubmit(
                            rating: _overallRating,
                            comment: _commentController.text,
                            punctuality: _punctuality > 0 ? _punctuality : null,
                            friendliness: _friendliness > 0 ? _friendliness : null,
                            communication: _communication > 0 ? _communication : null,
                            safety: _safety > 0 ? _safety : null,
                            photos: _selectedPhotos,
                          );
                        }
                      : null,
                  style: AppTheme.primaryButtonStyle.copyWith(
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  child: const Text('Submit Enhanced Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
