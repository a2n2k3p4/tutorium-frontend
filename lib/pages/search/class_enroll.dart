import 'package:flutter/material.dart';

class ClassInfoPage extends StatefulWidget {
  const ClassInfoPage({super.key});

  @override
  State<ClassInfoPage> createState() => _ClassInfoPageState();
}

class _ClassInfoPageState extends State<ClassInfoPage> {
  Map<String, dynamic>? selectedSession;
  bool showAllReviews = false;

  final List<Map<String, dynamic>> sessions = [
    {
      "date": "2025-10-01",
      "time": "14:00 - 16:00",
      "students": 5,
      "capacity": 10,
      "deadline": "2025-09-28",
      "price": 49.99,
    },
    {
      "date": "2025-10-05",
      "time": "10:00 - 12:00",
      "students": 8,
      "capacity": 10,
      "deadline": "2025-10-02",
      "price": 59.99,
    },
  ];

  final List<Map<String, dynamic>> reviews = [
    {
      "name": "Alice",
      "comment": "Great class, learned a lot!",
      "rating": 4.5,
    },
    {
      "name": "Bob",
      "comment": "Good teacher, very patient.",
      "rating": 4.0,
    },
    {
      "name": "Charlie",
      "comment": "Really enjoyed the sessions!",
      "rating": 5.0,
    },
    {
      "name": "Diana",
      "comment": "Nice pace and easy to follow.",
      "rating": 4.2,
    },
  ];

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
                  title: const Text("Class Info"),
                  background: Image.asset(
                    "assets/images/guitar.jpg",
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🎸 Guitar Mastery 101",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),

                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.star, color: Colors.amber),
                          SizedBox(width: 4),
                          Text("4.8 (120 reviews)"),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        "Learn the fundamentals of guitar playing, chords, "
                        "strumming patterns, and basic music theory.",
                      ),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("👨‍🏫 Teacher: John Smith",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Go to Teacher Profile")),
                              );
                            },
                            child: const Text("View Profile"),
                          )
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Text("📂 Category: Music"),

                      const Divider(height: 32),
                      const Text("📅 Select Session",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        hint: const Text("Choose a session"),
                        value: selectedSession,
                        items: sessions.map((session) {
                          return DropdownMenuItem(
                            value: session,
                            child: Text(
                              "${session['date']} | ${session['time']} - \$${session['price']}",
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSession = value;
                          });
                        },
                      ),

                      if (selectedSession != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  "Enrolled: ${selectedSession!['students']}/${selectedSession!['capacity']}"),
                              Text("Deadline: ${selectedSession!['deadline']}"),
                              Text("Price: \$${selectedSession!['price']}"),
                            ],
                          ),
                        ),
                      ],

                      const Divider(height: 32),
                      const Text("⭐ Reviews",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      Column(
                        children: [
                          ...reviews
                              .take(showAllReviews ? reviews.length : 2)
                              .map((r) => ListTile(
                                    leading: const CircleAvatar(
                                        child: Icon(Icons.person)),
                                    title: Text(r["name"]),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(r["comment"]),
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < r["rating"].round()
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              size: 16,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                          if (!showAllReviews && reviews.length > 2)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  showAllReviews = true;
                                });
                              },
                              child: const Text("See More Reviews"),
                            )
                        ],
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 🔹 Fixed Enroll Button
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
                                  "Enrolled in session on ${selectedSession!['date']}")),
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
