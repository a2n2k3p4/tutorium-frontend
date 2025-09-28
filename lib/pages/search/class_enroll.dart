import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';

class ClassEnrollPage extends StatefulWidget {
  final int classId;
  final String teacherName;

  const ClassEnrollPage({super.key, required this.classId, required this.teacherName});

  @override
  State<ClassEnrollPage> createState() => _ClassEnrollPageState();
}

class _ClassEnrollPageState extends State<ClassEnrollPage> {
  ClassInfo? classInfo;
  List<ClassSession> sessions = [];
  bool isLoading = true;
  ClassSession? selectedSession;
  bool showAllReviews = false;
  late Future<List<ClassSession>> futureSessions;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final fetchedSessions =
          await ClassSessionService().fetchClassSessions(widget.classId);
      final fetchedClassInfo =
          await ClassSessionService().fetchClassInfo(widget.classId);

      setState(() {
        sessions = fetchedSessions;
        classInfo = fetchedClassInfo;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Error loading class data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.asset(
                    "assets/images/guitar.jpg",
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "🎨 ${classInfo?.name ?? "Untitled Class"}",
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text("${classInfo?.rating ?? 0}/5"),
                              ],
                            ),

                            const SizedBox(height: 16),
                            Text(classInfo?.description ?? "No description available"),

                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "👨‍🏫 Teacher: ${widget.teacherName}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Go to Teacher Profile of ${widget.teacherName}",
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text("View Profile"),
                                )
                              ],
                            ),

                            const SizedBox(height: 16),
                            Text("📂 Category: ${classInfo?.category ?? "General"}"),

                            const Divider(height: 32),

                            const Text("📅 Select Session",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),

                            sessions.isNotEmpty
                                ? DropdownButton<ClassSession>(
                                    isExpanded: true,
                                    hint: const Text("Choose a session"),
                                    value: selectedSession,
                                    items: sessions.map((session) {
                                      String pad(int n) => n.toString().padLeft(2, '0');

                                      String formatDate(DateTime dt) {
                                        final weekdays = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];
                                        final months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
                                        return "${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}";
                                      }

                                      String formatTime(DateTime dt) {
                                        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                                        final minute = pad(dt.minute);
                                        final ampm = dt.hour >= 12 ? "PM" : "AM";
                                        return "$hour:$minute $ampm";
                                      }

                                      final dateStr = formatDate(session.classStart);
                                      final timeStr = "${formatTime(session.classStart)} – ${formatTime(session.classFinish)}";
                                      final deadlineStr = formatDate(session.enrollmentDeadline);

                                      return DropdownMenuItem(
                                        value: session,
                                        child: Text(
                                          "$dateStr • $timeStr • \$${session.price}  "
                                          "(Deadline: $deadlineStr)",
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),

                                    onChanged: (value) {
                                      setState(() {
                                        selectedSession = value;
                                      });
                                    },
                                  )
                                : const Text("No sessions available"),

                            const Divider(height: 32),

                            const Text("⭐ Reviews",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: const Text("Alice"),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Great class, learned a lot!"),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        i < 4 ? Icons.star : Icons.star_border,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  showAllReviews = !showAllReviews;
                                });
                              },
                              child: Text(showAllReviews ? "See Less" : "See More"),
                            ),

                            const SizedBox(height: 80),
                          ],
                        ),
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: selectedSession == null
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Enrolled in session ${selectedSession!.description}",
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Enroll Now"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
