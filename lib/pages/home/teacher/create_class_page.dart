import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorium_frontend/service/class_categories.dart'
    as category_api;
import 'package:tutorium_frontend/service/classes.dart' as class_api;
import 'package:tutorium_frontend/service/api_client.dart';

class CreateClassPage extends StatefulWidget {
  final int teacherId;

  const CreateClassPage({super.key, required this.teacherId});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CategoryOption {
  final int id;
  final String name;

  const _CategoryOption({required this.id, required this.name});
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _bannerImage;
  String? _bannerBase64;
  bool _isLoading = false;
  bool _isCategoryLoading = false;
  List<_CategoryOption> _categories = [];
  final List<int> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _isCategoryLoading = true;
      });
    }

    try {
      final categories = await category_api.ClassCategory.fetchAll();
      final normalised =
          categories
              .map(
                (category) => _CategoryOption(
                  id: category.id,
                  name: category.classCategory.trim(),
                ),
              )
              .where((option) => option.name.isNotEmpty)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      if (!mounted) return;
      setState(() {
        _categories = normalised;
        _isCategoryLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCategoryLoading = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);

      setState(() {
        _bannerImage = file;
        _bannerBase64 = base64;
      });
    }
  }

  Future<void> _createClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // NOTE: According to swagger.yaml, the backend API does NOT currently support
    // class_category_ids in the /classes POST endpoint. The ClassDoc model only
    // includes: class_name, class_description, teacher_id, and banner_picture.
    // Category associations need to be handled differently (possibly a separate
    // endpoint or backend update needed).

    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Format them into the JSON structure your API expects
      final categoryPayload = _categories
          .where((category) => _selectedCategories.contains(category.id))
          .map((category) => category.name) // Get the name (String)
          .toList();

      final classInfo = class_api.ClassInfo(
        id: 0,
        className: _classNameController.text.trim(),
        classDescription: _descriptionController.text.trim(),
        teacherId: widget.teacherId,
        bannerPicture: _bannerBase64,
        bannerPictureUrl: null,
        rating: 0,
        teacherName: null,
        enrolledLearners: null,
        // categories: const [],
        categories: categoryPayload,
      );

      debugPrint('Creating class with data: ${classInfo.toPayload()}');
      debugPrint(
        'Selected categories (NOT SENT - API unsupported): $_selectedCategories',
      );

      if (_selectedCategories.isNotEmpty) {
        debugPrint(
          '⚠️ WARNING: Category IDs cannot be assigned during class creation.',
        );
        debugPrint(
          '⚠️ Backend API needs to be updated to support class_category_ids field.',
        );
      }

      final createdClass = await class_api.ClassInfo.create(classInfo);

      if (mounted) {
        final message = _selectedCategories.isEmpty
            ? 'Class "${createdClass.className}" created without categories.'
            : 'Class "${createdClass.className}" created successfully with categories!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _selectedCategories.isEmpty
                ? Colors.orange
                : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to create class';

        String errorDetails = e.toString();

        if (e is ApiException) {
          errorDetails = e.body ?? e.toString();
          switch (e.statusCode) {
            case 400:
              errorMessage = 'Invalid data. Please check all fields.';
              break;
            case 401:
            case 403:
              errorMessage = 'Unauthorized. Please log in again.';
              break;
            case 404:
              errorMessage = 'Service unavailable. Please try again later.';
              break;
            case 500:
              errorMessage = 'Server error. Please try again later.';
              break;
            default:
              errorMessage = 'Failed to create class (code ${e.statusCode}).';
          }

          if ((e.body ?? '').contains('foreign key')) {
            errorMessage =
                'Database error: Invalid teacher ID or missing reference';
          }
        } else {
          if (errorDetails.contains('foreign key')) {
            errorMessage =
                'Database error: Invalid teacher ID or missing reference';
          } else if (errorDetails.contains('teacher_id')) {
            errorMessage = 'Invalid teacher ID. Please contact support.';
          } else if (errorDetails.contains('401') ||
              errorDetails.contains('Unauthorized')) {
            errorMessage = 'Unauthorized. Please log in again.';
          } else if (errorDetails.contains('400')) {
            errorMessage = 'Invalid data. Please check all fields.';
          } else if (errorDetails.contains('500')) {
            errorMessage = 'Server error. Please try again later.';
          }
        }

        debugPrint('❌ Create class error: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Details: $errorDetails',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Create New Class',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Image Section
                _buildBannerSection(),
                const SizedBox(height: 24),

                // Class Name
                _buildTextField(
                  controller: _classNameController,
                  label: 'Class Name',
                  icon: Icons.school,
                  hint: 'e.g., Advanced Python Programming',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter class name';
                    }
                    if (value.length < 3) {
                      return 'Class name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Description
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  icon: Icons.description,
                  hint: 'Describe what students will learn...',
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    if (value.length < 10) {
                      return 'Description must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Categories
                _buildCategoriesSection(),
                const SizedBox(height: 32),

                // Create Button
                _buildCreateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Banner',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 2),
              image: _bannerImage != null
                  ? DecorationImage(
                      image: FileImage(_bannerImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _bannerImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to add banner image',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Optional',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.blue[700]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //   decoration: BoxDecoration(
            //     color: Colors.orange[100],
            //     borderRadius: BorderRadius.circular(12),
            //   ),
            //   child: Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Icon(
            //         Icons.warning_amber,
            //         size: 14,
            //         color: Colors.orange[700],
            //       ),
            //       const SizedBox(width: 4),
            //       Text(
            //         'Not supported yet',
            //         style: TextStyle(
            //           fontSize: 11,
            //           fontWeight: FontWeight.bold,
            //           color: Colors.orange[700],
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
        const SizedBox(height: 8),
        // Warning notice about API limitation
        // Container(
        //   padding: const EdgeInsets.all(12),
        //   decoration: BoxDecoration(
        //     color: Colors.orange[50],
        //     borderRadius: BorderRadius.circular(8),
        //     border: Border.all(color: Colors.orange[200]!),
        //   ),
        //   child: Row(
        //     children: [
        //       Icon(Icons.info_outline, size: 18, color: Colors.orange[700]),
        //       const SizedBox(width: 8),
        //       Expanded(
        //         child: Text(
        //           'Category assignment is not yet supported by the backend API. Categories can be added later.',
        //           style: TextStyle(fontSize: 12, color: Colors.orange[900]),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        const SizedBox(height: 12),
        // Show categories for future use (disabled state)
        if (_isCategoryLoading)
          const Center(child: CircularProgressIndicator())
        else if (_categories.isEmpty)
          _buildEmptyCategoriesNotice()
        else
          Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategories.contains(category.id);

                  return FilterChip(
                    label: Text(category.name),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category.id);
                        } else {
                          _selectedCategories.remove(category.id);
                        }
                        debugPrint(
                          'Selected category IDs: $_selectedCategories',
                        );
                      });
                    },
                    backgroundColor: isSelected
                        ? Colors.blue[100]
                        : Colors.grey[200],
                    selectedColor: Colors.blue[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue[900] : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.blue[700]!
                            : Colors.grey[300]!,
                      ),
                    ),
                  );
                }).toList(),
                // children: _categories.map((category) {
                //   return FilterChip(
                //     label: Text(category.name),
                //     selected: false,
                //     onSelected: null, // Disabled
                //     backgroundColor: Colors.grey[200],
                //     disabledColor: Colors.grey[200],
                //     labelStyle: TextStyle(
                //       color: Colors.grey[500],
                //       fontWeight: FontWeight.normal,
                //     ),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(8),
                //       side: BorderSide(color: Colors.grey[300]!),
                //     ),
                //   );
                // }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCategoriesNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'No categories available',
                style: TextStyle(
                  color: Colors.blue[900],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Looks like there are no categories to pick right now. Try refreshing to fetch the latest categories.',
            style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.3),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isCategoryLoading ? null : _loadCategories,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh categories'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[700],
                side: BorderSide(color: Colors.blue[200]!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _createClass,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[700],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Create Class',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }
}
