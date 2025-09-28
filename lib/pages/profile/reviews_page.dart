import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/pages/profile/profile_page.dart';
import 'dart:convert';

class ReviewPage extends StatefulWidget {
  final int classId;

  const ReviewPage({super.key, required this.classId});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool isLoading = true;
  List<Review> reviews = [];
  List<User> users = [];
  Map<int, User> usersMap = {};

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    await Future.wait([fetchUsers(), fetchReviews()]);
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchReviews() async {
    try {
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];
      final apiUrl = "$apiKey:$port/reviews";

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        final allReviews = jsonData.map((r) => Review.fromJson(r)).toList();

        setState(() {
          reviews = allReviews
              .where((r) => r.classId == widget.classId)
              .toList();
        });
      } else {
        throw Exception("Failed to load reviews");
      }
    } catch (e) {
      print("Error fetching reviews: $e");
      setState(() {
        reviews = [];
      });
    }
  }

  Future<void> fetchUsers() async {
    try {
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];
      final apiUrl = "$apiKey:$port/users";

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;
        final fetchedUsers = jsonData.map((u) => User.fromJson(u)).toList();

        setState(() {
          users = fetchedUsers;
          usersMap = {for (var u in users) u.id: u};
        });
      }
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  String getUserName(Review review) {
    if (review.learnerUserId == null) return "Unknown";

    final user = usersMap[review.learnerUserId!];
    if (user == null) return "Unknown";

    return "${user.firstName} ${user.lastName}".trim();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Review"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reviews.isEmpty
              ? const Center(child: Text("No reviews yet"))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    final reviewerName = getUserName(review);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.greenAccent,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    reviewerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          color: Colors.amber, size: 18),
                                      Text(
                                        "${review.rating?.toStringAsFixed(1) ?? '0.0'}",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                review.comment ?? "",
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}


