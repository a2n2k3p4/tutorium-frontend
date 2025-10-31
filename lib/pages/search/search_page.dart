import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tutorium_frontend/service/api_client.dart' show ApiException;
import 'package:tutorium_frontend/service/learners.dart' as learner_api;
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';
import 'package:tutorium_frontend/pages/widgets/schedule_card_search.dart';
import 'package:tutorium_frontend/pages/widgets/search_service.dart';
import 'package:tutorium_frontend/pages/widgets/skeleton_loading.dart';
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

class _MaxValueTextInputFormatter extends TextInputFormatter {
  _MaxValueTextInputFormatter(this.maxValue);

  final double maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    if (text == '.') {
      return newValue;
    }

    final value = double.tryParse(text);
    if (value == null) {
      return oldValue;
    }

    if (value > maxValue) {
      return oldValue;
    }

    return newValue;
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchService api = SearchService();
  final SearchDataStore _dataStore = SearchDataStore.instance;
  Timer? _searchDebounce;
  List<dynamic> _allClasses = [];
  List<dynamic> _filteredClasses = [];
  List<dynamic> _popularClasses = [];
  List<_RecommendedClass> _recommendedClasses = [];
  List<dynamic>? _popularTopCache;
  List<dynamic>? _popularAllCache;
  bool showAllPopular = false;
  bool isLoading = false;
  bool _isLoadingRecommended = false;
  bool _isLoadingPopularToggle = false;
  int? _cachedLearnerId;
  String? _recommendationError;
  String currentQuery = "";
  bool _showHomeView = true;

  List<String> selectedCategories = [];
  double? minRating;
  double? maxRating;
  bool isFilterActive = false;

  bool get _hasActiveCategoryFilter =>
      selectedCategories.any((category) => category != 'All');

  bool get _hasActiveFilters =>
      _hasActiveCategoryFilter || minRating != null || maxRating != null;

  List<String> get _categoryFilters =>
      selectedCategories.where((category) => category != 'All').toList();

  void _refreshFilterActiveState() {
    isFilterActive = _hasActiveFilters;
  }

  void _updateViewState() {
    final bool isAllCategory =
        selectedCategories.length == 1 && selectedCategories.contains('All');
    if (currentQuery.isNotEmpty || isFilterActive || isAllCategory) {
      _showHomeView = false;
    } else {
      _showHomeView = true;
    }
  }

  void _toggleCategorySelection(String category, bool shouldSelect) {
    if (category == 'All') {
      if (shouldSelect) {
        selectedCategories
          ..clear()
          ..add('All');
      } else {
        selectedCategories.remove('All');
      }
    } else {
      if (shouldSelect) {
        selectedCategories.remove('All');
        if (!selectedCategories.contains(category)) {
          selectedCategories.add(category);
        }
      } else {
        selectedCategories.remove(category);
      }
    }
    _refreshFilterActiveState();
  }

  void _setMinRating(double? value) {
    minRating = value;
    _refreshFilterActiveState();
  }

  void _setMaxRating(double? value) {
    maxRating = value;
    _refreshFilterActiveState();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _dataStore.removeListener(_handleStoreUpdated);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dataStore.addListener(_handleStoreUpdated);
    _hydrateFromCache();
    _loadClasses();
    _loadPopularClasses();
    _loadRecommendedSessions();
  }

  void _handleStoreUpdated() {
    if (!mounted) return;
    setState(_hydrateFromCache);
  }

  void _hydrateFromCache() {
    final cachedClasses = _dataStore.allClasses;
    if (cachedClasses != null && cachedClasses.isNotEmpty) {
      _allClasses = List<dynamic>.from(cachedClasses);
      _filteredClasses = api.searchLocal(cachedClasses, currentQuery);
    }

    final cachedTop = _dataStore.popularTop;
    final cachedAll = _dataStore.popularAll;
    _popularTopCache = cachedTop;
    _popularAllCache = cachedAll;

    if (showAllPopular) {
      if (cachedAll != null && cachedAll.isNotEmpty) {
        _popularClasses = List<dynamic>.from(cachedAll);
      } else if (cachedTop != null && cachedTop.isNotEmpty) {
        _popularClasses = List<dynamic>.from(cachedTop);
      }
    } else if (cachedTop != null && cachedTop.isNotEmpty) {
      _popularClasses = List<dynamic>.from(cachedTop);
    }
  }

  Future<void> _loadClasses({bool forceRefresh = false}) async {
    final cached = forceRefresh ? null : _dataStore.allClasses;
    if (cached != null && cached.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _allClasses = List<dynamic>.from(cached);
        _filteredClasses = api.searchLocal(cached, currentQuery);
      });
      return;
    }

    try {
      final data = await api.getAllClasses(forceRefresh: forceRefresh);
      _dataStore.updateAllClasses(data);

      if (!mounted) return;
      setState(() {
        _allClasses = List<dynamic>.from(data);
        _filteredClasses = api.searchLocal(data, currentQuery);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allClasses = [];
        _filteredClasses = [];
      });
    }
  }

  Future<void> _loadPopularClasses({bool forceRefresh = false}) async {
    if (!forceRefresh && !showAllPopular) {
      final cachedTop = _dataStore.popularTop;
      if (cachedTop != null && cachedTop.isNotEmpty) {
        if (!mounted) return;
        setState(() => _popularClasses = List<dynamic>.from(cachedTop));
        return;
      }
    }

    try {
      final data = await api.getPopularClasses(
        limit: 10,
        forceRefresh: forceRefresh,
      );
      _dataStore.updatePopularTop(data);

      if (!mounted) return;
      setState(() {
        _popularClasses = List<dynamic>.from(data);
        _popularTopCache = data;
      });
    } catch (e) {
      debugPrint("Error loading popular classes: $e");
    }
  }

  Future<void> _togglePopularView() async {
    if (_isLoadingPopularToggle) return;

    if (showAllPopular) {
      final top =
          _popularTopCache ??
          _dataStore.popularTop ??
          (_popularClasses.length > 10
              ? _popularClasses.take(10).toList()
              : List<dynamic>.from(_popularClasses));
      if (!mounted) return;
      setState(() {
        showAllPopular = false;
        _popularClasses = List<dynamic>.from(top);
      });
      return;
    }

    setState(() => _isLoadingPopularToggle = true);

    try {
      final cachedAll = _popularAllCache ?? _dataStore.popularAll;
      List<dynamic> data;
      if (cachedAll != null && cachedAll.isNotEmpty) {
        data = cachedAll;
      } else {
        data = await api.getPopularClasses(forceRefresh: false);
        _dataStore.updatePopularAll(data);
      }

      if (!mounted) return;
      setState(() {
        showAllPopular = true;
        _popularAllCache = data;
        _popularClasses = List<dynamic>.from(data);
      });
    } catch (e) {
      debugPrint('Error toggling popular view: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPopularToggle = false);
      }
    }
  }

  Future<int?> _resolveLearnerId({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedLearnerId != null) {
      return _cachedLearnerId;
    }

    try {
      final cachedId = await LocalStorage.getLearnerId();
      if (cachedId != null && cachedId > 0) {
        _cachedLearnerId = cachedId;
        return cachedId;
      }
    } catch (e) {
      debugPrint('Search: unable to read cached learner ID - $e');
    }

    final cachedUser = UserCache().user;
    final fallbackId = cachedUser?.learner?.id;
    if (fallbackId != null && fallbackId > 0) {
      _cachedLearnerId = fallbackId;
      try {
        await LocalStorage.saveLearnerId(fallbackId);
      } catch (e) {
        debugPrint('Search: unable to persist learner ID - $e');
      }
    }

    return _cachedLearnerId;
  }

  Future<void> _loadRecommendedSessions({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingRecommended = true;
      if (!forceRefresh) {
        _recommendationError = null;
      }
    });

    try {
      final learnerId = await _resolveLearnerId(forceRefresh: forceRefresh);
      if (learnerId == null) {
        debugPrint('Search: learner ID unavailable, falling back to popular');
        await _loadRecommendedFallback(
          reason: 'missing learner id',
          forceRefresh: forceRefresh,
        );
        return;
      }

      final response = await learner_api
          .LearnerInterestService.fetchRecommendations(learnerId);
      final sources =
          (response.recommendedFound && response.recommendedClasses.isNotEmpty)
          ? response.recommendedClasses
          : response.remainingClasses;

      if (sources.isEmpty) {
        await _loadRecommendedFallback(
          reason: 'empty recommendation payload',
          forceRefresh: forceRefresh,
        );
        return;
      }

      final normalized = sources
          .map(_normalizeClassMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      if (normalized.isEmpty) {
        await _loadRecommendedFallback(
          reason: 'unrecognized payload',
          forceRefresh: forceRefresh,
        );
        return;
      }

      final recommendations = await _buildRecommendationCards(
        normalized.take(12).toList(growable: false),
      );

      if (!mounted) return;
      setState(() {
        _recommendedClasses = recommendations;
        _recommendationError = null;
      });
    } on ApiException catch (e) {
      debugPrint(
        'Search: recommendation API failed (${e.statusCode}). body=${e.body}',
      );
      await _loadRecommendedFallback(
        reason: 'api ${e.statusCode}',
        forceRefresh: forceRefresh,
      );
    } catch (e, stackTrace) {
      debugPrint('Search: recommendation pipeline crashed: $e');
      debugPrint('$stackTrace');
      await _loadRecommendedFallback(
        reason: 'exception',
        forceRefresh: forceRefresh,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingRecommended = false);
      } else {
        _isLoadingRecommended = false;
      }
    }
  }

  Future<void> _loadRecommendedFallback({
    required String reason,
    bool forceRefresh = false,
  }) async {
    debugPrint('Search: fallback to popular recommendations ($reason)');
    try {
      final popularCandidates = await api.getPopularClasses(
        limit: 8,
        forceRefresh: forceRefresh,
      );
      final mapped = popularCandidates
          .map(_normalizeClassMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      if (mapped.isEmpty) {
        if (!mounted) return;
        setState(() {
          _recommendedClasses = [];
          _recommendationError =
              'ไม่พบคลาสที่แนะนำในตอนนี้ ลองใช้การค้นหาหรือกรองเพิ่มเติม';
        });
        return;
      }

      final recommendations = await _buildRecommendationCards(mapped);
      if (!mounted) return;
      setState(() {
        _recommendedClasses = recommendations;
        _recommendationError = recommendations.isEmpty
            ? 'ไม่พบคลาสที่แนะนำในตอนนี้ ลองใช้การค้นหาหรือกรองเพิ่มเติม'
            : 'กำลังแสดงคลาสยอดนิยมแทนคำแนะนำเฉพาะตัว';
      });
    } catch (e, stackTrace) {
      debugPrint('Search: fallback recommendations failed: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _recommendedClasses = [];
        _recommendationError =
            'ไม่สามารถโหลดคำแนะนำได้ กรุณาลองใหม่หรือตรวจสอบการเชื่อมต่อ';
      });
    }
  }

  Future<List<_RecommendedClass>> _buildRecommendationCards(
    List<Map<String, dynamic>> candidates,
  ) async {
    if (candidates.isEmpty) {
      return const <_RecommendedClass>[];
    }

    final now = DateTime.now();
    final futures = candidates
        .take(12)
        .map((classData) => _buildRecommendationEntry(classData, now));

    final results = await Future.wait(futures);
    final recommendations =
        results.whereType<_RecommendedClass>().toList(growable: false)
          ..sort((a, b) {
            final aDate = a.date;
            final bDate = b.date;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
    return recommendations.take(6).toList(growable: false);
  }

  Future<_RecommendedClass?> _buildRecommendationEntry(
    Map<String, dynamic> classData,
    DateTime now,
  ) async {
    final classId = _asInt(
      classData['id'] ?? classData['ID'] ?? classData['class_id'],
    );
    if (classId == null || classId <= 0) {
      return null;
    }

    try {
      final sessions = await ClassSessionService.getSessionsByClass(classId);
      final upcomingSessions =
          sessions.where((session) => session.classStart.isAfter(now)).toList()
            ..sort((a, b) => a.classStart.compareTo(b.classStart));

      final hasUpcomingSession = upcomingSessions.isNotEmpty;
      final session = hasUpcomingSession ? upcomingSessions.first : null;
      final startLocal = session?.classStart.toLocal();
      final endLocal = session?.classFinish.toLocal();

      int? enrolledCount;
      if (session != null) {
        try {
          final enrollments = await ClassSessionService.getEnrollmentsBySession(
            session.id,
          );
          enrolledCount = enrollments.length;
        } catch (e) {
          debugPrint(
            'Search: failed to fetch enrollments for session ${session.id}: $e',
          );
        }
      }

      final teacherRaw =
          (classData['teacher_name'] ?? classData['teacherName'] ?? '')
              .toString()
              .trim();
      final teacherName = teacherRaw.isEmpty ? 'Unknown Teacher' : teacherRaw;

      final imageUrl =
          (classData['banner_picture_url'] ??
                  classData['banner_picture'] ??
                  classData['imagePath'])
              ?.toString();

      final rating = _asDouble(
        classData['rating'] ?? classData['average_rating'],
      );

      return _RecommendedClass(
        classId: classId,
        sessionId: session?.id,
        className:
            (classData['class_name'] ??
                    classData['className'] ??
                    'Unnamed Class')
                .toString(),
        teacherName: teacherName,
        date: startLocal,
        startTime: startLocal != null
            ? TimeOfDay.fromDateTime(startLocal)
            : null,
        endTime: endLocal != null ? TimeOfDay.fromDateTime(endLocal) : null,
        imageUrl: imageUrl,
        rating: rating,
        enrolledLearner: enrolledCount,
        learnerLimit: session?.learnerLimit,
        hasUpcomingSession: hasUpcomingSession,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Search: failed to build recommendation for class $classId: $e',
      );
      debugPrint('$stackTrace');
      return null;
    }
  }

  Map<String, dynamic>? _normalizeClassMap(dynamic value) {
    if (value is! Map) return null;

    final result = <String, dynamic>{};

    value.forEach((rawKey, rawVal) {
      if (rawVal == null) return;
      final key = rawKey.toString();
      final lowerKey = key.toLowerCase();

      if (lowerKey == 'class' ||
          lowerKey == 'classdoc' ||
          lowerKey == 'classinfo') {
        final nested = _normalizeClassMap(rawVal);
        if (nested != null) {
          result.addAll(nested);
        }
        return;
      }

      if (rawVal is Map) {
        result[key] = rawVal.map((k, dynamic v) => MapEntry(k.toString(), v));
        return;
      }

      if (rawVal is List) {
        result[key] = rawVal
            .map(
              (item) => item is Map ? _normalizeClassMap(item) ?? item : item,
            )
            .toList(growable: false);
        return;
      }

      result[key] = rawVal;
    });

    return result;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Set<String> _extractCategoryNames(dynamic item) {
    final categories = <String>{};

    void addCategoryValue(dynamic value) {
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty) {
          categories.add(normalized);
        }
      }
    }

    final rawCategories = item is Map<String, dynamic>
        ? (item['categories'] ?? item['Categories'])
        : null;

    if (rawCategories is String) {
      rawCategories
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .forEach(addCategoryValue);
    } else if (rawCategories is List) {
      for (final entry in rawCategories) {
        if (entry is String) {
          addCategoryValue(entry);
        } else if (entry is Map<String, dynamic>) {
          addCategoryValue(entry['class_category']);
          addCategoryValue(entry['category']);
          addCategoryValue(entry['category_name']);
          addCategoryValue(entry['name']);
        }
      }
    } else if (rawCategories is Map<String, dynamic>) {
      addCategoryValue(rawCategories['class_category']);
      addCategoryValue(rawCategories['category']);
      addCategoryValue(rawCategories['category_name']);
      addCategoryValue(rawCategories['name']);
    }

    final fallbackCategory = item is Map<String, dynamic>
        ? (item['category'] ?? item['Category'])
        : null;
    addCategoryValue(fallbackCategory);

    final primaryCategory = item is Map<String, dynamic>
        ? (item['primary_category'] ?? item['primaryCategory'])
        : null;
    addCategoryValue(primaryCategory);

    return categories;
  }

  List<dynamic> _applyActiveFilters(List<dynamic> classes) {
    if (!isFilterActive) {
      return List<dynamic>.from(classes);
    }

    final activeCategories = _categoryFilters
        .map((c) => c.toLowerCase())
        .toList(growable: false);
    final localMinRating = minRating;
    final localMaxRating = maxRating;

    return classes
        .where((item) {
          dynamic ratingSource;
          if (item is Map<String, dynamic>) {
            ratingSource = item['rating'] ?? item['average_rating'];
          }
          final rating = _asDouble(ratingSource);

          if (localMinRating != null && rating < localMinRating) {
            return false;
          }
          if (localMaxRating != null && rating > localMaxRating) {
            return false;
          }

          if (activeCategories.isNotEmpty) {
            final classCategories = _extractCategoryNames(
              item,
            ).map((c) => c.toLowerCase()).toSet();
            if (classCategories.isEmpty) {
              // Backend already applied category filter; accept entries even if category metadata is absent.
              return true;
            }

            final hasMatch = activeCategories.any(classCategories.contains);
            if (!hasMatch) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }

  Future<void> _search(String query) async {
    final normalizedQuery = query.trim();

    if (currentQuery != normalizedQuery) {
      setState(() {
        currentQuery = normalizedQuery;
      });
    }

    if (!isFilterActive) {
      setState(() {
        _filteredClasses = api.searchLocal(_allClasses, normalizedQuery);
      });
      return;
    }

    setState(() => isLoading = true);
    try {
      final categoryFilters = _categoryFilters;
      final data = await api.filterClasses(
        categories: categoryFilters.isNotEmpty ? categoryFilters : null,
        minRating: minRating,
        maxRating: maxRating,
      );

      final filteredData = _applyActiveFilters(data);
      final searched = api.searchLocal(filteredData, normalizedQuery);
      setState(() => _filteredClasses = searched);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    final normalizedQuery = query.trim();
    final isWhitespaceOnly = normalizedQuery.isEmpty && query.isNotEmpty;

    if (isWhitespaceOnly) {
      _searchDebounce?.cancel();
      setState(() {
        currentQuery = '';
        _filteredClasses = [];
      });
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _runDebouncedSearch(normalizedQuery);
    });
  }

  void _runDebouncedSearch(String normalizedQuery) {
    setState(() {
      currentQuery = normalizedQuery;
      _updateViewState();

      if (_showHomeView) {
        _filteredClasses = api.searchLocal(_allClasses, "");
      }
    });

    if (_showHomeView) {
      return;
    }

    _search(normalizedQuery);
  }

  void _showFilterOptions() {
    final List<String> categories = [
      'All',
      'General',
      'Mathematics',
      'Science',
      'Language',
      'History',
      'Technology',
      'Arts',
    ];

    final minRatingController = TextEditingController(
      text: minRating?.toString() ?? '',
    );
    final maxRatingController = TextEditingController(
      text: maxRating?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void updateFilters(VoidCallback updates) {
              setModalState(() {
                updates();
              });
              setState(() {});
            }

            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter Options",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          updateFilters(() {
                            selectedCategories.clear();
                            _setMinRating(null);
                            _setMaxRating(null);
                            minRatingController.clear();
                            maxRatingController.clear();
                          });
                        },
                        child: Text("Reset"),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  Text(
                    "Categories",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8,
                    children: categories.map((category) {
                      final isSelected = selectedCategories.contains(category);
                      return FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          updateFilters(() {
                            _toggleCategorySelection(category, selected);
                          });
                        },
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 16),
                  Text(
                    "Rating Range (0-5)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minRatingController,
                          decoration: InputDecoration(
                            labelText: "Min Rating",
                            border: OutlineInputBorder(),
                            errorText: _validateRatingRange(
                              minRatingController.text,
                              maxRatingController.text,
                            )?.minError,
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                            _MaxValueTextInputFormatter(5),
                          ],
                          onChanged: (value) {
                            updateFilters(() {
                              _setMinRating(double.tryParse(value));
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: maxRatingController,
                          decoration: InputDecoration(
                            labelText: "Max Rating",
                            border: OutlineInputBorder(),
                            errorText: _validateRatingRange(
                              minRatingController.text,
                              maxRatingController.text,
                            )?.maxError,
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                            _MaxValueTextInputFormatter(5),
                          ],
                          onChanged: (value) {
                            updateFilters(() {
                              _setMaxRating(double.tryParse(value));
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final validation = _validateRatingRange(
                        minRatingController.text,
                        maxRatingController.text,
                      );

                      if (validation?.hasError == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Please fix rating validation errors",
                            ),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _refreshFilterActiveState();
                        _updateViewState();
                      });
                      Navigator.pop(context);
                      if (!_showHomeView) {
                        _search(currentQuery);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text("Apply Filters"),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  RatingValidation? _validateRatingRange(String minText, String maxText) {
    final min = double.tryParse(minText);
    final max = double.tryParse(maxText);

    if (minText.isEmpty && maxText.isEmpty) return null;

    String? minError;
    String? maxError;
    bool hasError = false;

    if (min != null && (min < 0 || min > 5)) {
      minError = "Must be between 0-5";
      hasError = true;
    }

    if (max != null && (max < 0 || max > 5)) {
      maxError = "Must be between 0-5";
      hasError = true;
    }

    if (min != null && max != null && min > max) {
      minError = "Min cannot be greater than max";
      maxError = "Max cannot be less than min";
      hasError = true;
    }

    return hasError ? RatingValidation(minError, maxError, true) : null;
  }

  Future<void> _handleRefresh() async {
    debugPrint('🔄 Pull to refresh triggered');

    // Clear in-memory cache to force fresh data
    _dataStore.clearCache();

    // Force refresh popular classes
    await _loadPopularClasses(forceRefresh: true);

    // Force refresh recommended sessions
    await _loadRecommendedSessions(forceRefresh: true);

    // If there's a current search/filter, re-run it
    if (currentQuery.isNotEmpty || isFilterActive) {
      await _search(currentQuery);
    } else {
      // Reload all classes
      try {
        final data = await api.filterClasses();
        setState(() => _allClasses = data);
      } catch (e) {
        debugPrint('Error refreshing all classes: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Refreshed successfully'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    debugPrint('✅ Refresh completed');
  }

  @override
  Widget build(BuildContext context) {
    return SearchDataProvider(
      notifier: _dataStore,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Search Class",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Enter class name..",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilterActive
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).primaryColor,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.filter_list, color: Colors.white),
                        onPressed: _showFilterOptions,
                      ),
                    ),
                  ],
                ),
              ),

              if (isFilterActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_categoryFilters.isNotEmpty)
                        Chip(
                          label: Text(
                            "Categories: ${selectedCategories.join(',')}",
                          ),
                          onDeleted: () {
                            setState(() {
                              selectedCategories.clear();
                              _refreshFilterActiveState();
                              _updateViewState();
                            });
                            if (!_showHomeView) {
                              _search(currentQuery);
                            }
                          },
                        ),
                      if (minRating != null)
                        Chip(
                          label: Text("Rating ≥ $minRating"),
                          onDeleted: () {
                            setState(() {
                              _setMinRating(null);
                              _updateViewState();
                            });
                            if (!_showHomeView) {
                              _search(currentQuery);
                            }
                          },
                        ),
                      if (maxRating != null)
                        Chip(
                          label: Text("Rating ≤ $maxRating"),
                          onDeleted: () {
                            setState(() {
                              _setMaxRating(null);
                              _updateViewState();
                            });
                            if (!_showHomeView) {
                              _search(currentQuery);
                            }
                          },
                        ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: GridLoadingSkeleton(itemCount: 6),
                      )
                    else if (!_showHomeView)
                      _filteredClasses.isNotEmpty
                          ? GridView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 0.8,
                                  ),
                              itemCount: _filteredClasses.length,
                              itemBuilder: (context, index) {
                                final item = _filteredClasses[index];
                                return ScheduleCardSearch(
                                  classId: item['id'] ?? item['classId'] ?? 0,
                                  className:
                                      item['class_name'] ??
                                      item['className'] ??
                                      'Unnamed Class',
                                  teacherName:
                                      item['teacher_name'] ??
                                      item['teacherName'] ??
                                      'Unknown Teacher',
                                  date: DateTime.now(),
                                  startTime: TimeOfDay(hour: 0, minute: 0),
                                  endTime: TimeOfDay(hour: 0, minute: 0),
                                  imageUrl:
                                      (item['banner_picture_url'] ??
                                              item['banner_picture'] ??
                                              item['imagePath'])
                                          ?.toString(),
                                  fallbackAsset: 'assets/images/guitar.jpg',
                                  showSchedule: false,
                                  rating: (item['rating'] is num)
                                      ? (item['rating'] as num).toDouble()
                                      : 0.0,
                                );
                              },
                            )
                          : const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text("No results found"),
                            )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              "Recommended Class",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 180,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _isLoadingRecommended
                                  ? const HorizontalLoadingSkeleton(
                                      itemCount: 5,
                                    )
                                  : _recommendedClasses.isEmpty
                                  ? Center(
                                      key: ValueKey('no_recommended'),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          _recommendationError ??
                                              'No recommended sessions found',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      key: const ValueKey('recommended_list'),
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _recommendedClasses.length,
                                      itemBuilder: (context, index) {
                                        final item = _recommendedClasses[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: ScheduleCardSearch(
                                            classId: item.classId,
                                            className: item.className,
                                            enrolledLearner:
                                                item.enrolledLearner,
                                            learnerLimit: item.learnerLimit,
                                            teacherName: item.teacherName,
                                            date: item.date ?? DateTime.now(),
                                            startTime:
                                                item.startTime ??
                                                const TimeOfDay(
                                                  hour: 0,
                                                  minute: 0,
                                                ),
                                            endTime:
                                                item.endTime ??
                                                const TimeOfDay(
                                                  hour: 0,
                                                  minute: 0,
                                                ),
                                            imageUrl: item.imageUrl,
                                            fallbackAsset:
                                                'assets/images/default.jpg',
                                            rating: item.rating,
                                            showSchedule:
                                                item.hasUpcomingSession,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Popular Classes",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if ((_popularTopCache?.length ??
                                            _popularClasses.length) >
                                        10 ||
                                    _popularAllCache != null)
                                  TextButton(
                                    onPressed: _isLoadingPopularToggle
                                        ? null
                                        : _togglePopularView,
                                    child: _isLoadingPopularToggle
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            showAllPopular
                                                ? "See less"
                                                : "See more",
                                          ),
                                  ),
                              ],
                            ),
                          ),

                          SizedBox(
                            height: 180,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _popularClasses.isEmpty
                                  ? const Center(
                                      key: ValueKey('no_popular'),
                                      child: Text("No popular classes found"),
                                    )
                                  : ListView.builder(
                                      key: const ValueKey('popular_list'),
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _popularClasses.length,
                                      itemBuilder: (context, index) {
                                        final item = _popularClasses[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: ScheduleCardSearch(
                                            classId:
                                                item['id'] ??
                                                item['classId'] ??
                                                0,
                                            className:
                                                item['class_name'] ??
                                                'Unnamed Class',
                                            teacherName:
                                                item['teacher_name'] ??
                                                'Unknown Teacher',
                                            date: DateTime.now(),
                                            startTime: TimeOfDay(
                                              hour: 0,
                                              minute: 0,
                                            ),
                                            endTime: TimeOfDay(
                                              hour: 0,
                                              minute: 0,
                                            ),
                                            imageUrl:
                                                (item['banner_picture_url'] ??
                                                        item['banner_picture'] ??
                                                        item['imagePath'])
                                                    ?.toString(),
                                            fallbackAsset:
                                                'assets/images/guitar.jpg',
                                            showSchedule: false,
                                            rating: (item['rating'] is num)
                                                ? (item['rating'] as num)
                                                      .toDouble()
                                                : 0.0,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchDataStore extends ChangeNotifier {
  SearchDataStore._internal();

  static final SearchDataStore instance = SearchDataStore._internal();

  List<dynamic>? _allClasses;
  List<dynamic>? _popularTop;
  List<dynamic>? _popularAll;

  List<dynamic>? get allClasses =>
      _allClasses != null ? List<dynamic>.from(_allClasses!) : null;
  List<dynamic>? get popularTop =>
      _popularTop != null ? List<dynamic>.from(_popularTop!) : null;
  List<dynamic>? get popularAll =>
      _popularAll != null ? List<dynamic>.from(_popularAll!) : null;

  void updateAllClasses(List<dynamic> classes) {
    if (_shouldSkipUpdate(_allClasses, classes)) return;
    _allClasses = List<dynamic>.from(classes);
    notifyListeners();
  }

  void updatePopularTop(List<dynamic> classes) {
    if (_shouldSkipUpdate(_popularTop, classes)) return;
    _popularTop = List<dynamic>.from(classes);
    notifyListeners();
  }

  void updatePopularAll(List<dynamic> classes) {
    if (_shouldSkipUpdate(_popularAll, classes)) return;
    _popularAll = List<dynamic>.from(classes);
    notifyListeners();
  }

  bool _shouldSkipUpdate(List<dynamic>? existing, List<dynamic> incoming) {
    if (existing == null) return false;
    return listEquals(existing, incoming);
  }

  void clearCache() {
    _allClasses = null;
    _popularTop = null;
    _popularAll = null;
    notifyListeners();
  }
}

class SearchDataProvider extends InheritedNotifier<SearchDataStore> {
  const SearchDataProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static SearchDataStore of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<SearchDataProvider>();
    if (provider == null || provider.notifier == null) {
      throw FlutterError('SearchDataProvider not found in context');
    }
    return provider.notifier!;
  }
}

class _RecommendedClass {
  final int classId;
  final int? sessionId;
  final String className;
  final String teacherName;
  final DateTime? date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? imageUrl;
  final double rating;
  final int? enrolledLearner;
  final int? learnerLimit;
  final bool hasUpcomingSession;

  const _RecommendedClass({
    required this.classId,
    required this.sessionId,
    required this.className,
    required this.teacherName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.imageUrl,
    required this.rating,
    this.enrolledLearner,
    this.learnerLimit,
    required this.hasUpcomingSession,
  });
}

class RatingValidation {
  final String? minError;
  final String? maxError;
  final bool hasError;

  RatingValidation(this.minError, this.maxError, this.hasError);
}
