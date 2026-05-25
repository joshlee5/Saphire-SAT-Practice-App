import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  String searchTerm = "";

  // Your current user ID (mock for now)
  final currentUid = UserModel.instance.uid;

  // Adds a friend to Firestore
  Future<void> addFriend(String friendUid) async {
    final userRef =
        FirebaseFirestore.instance.collection("users").doc(currentUid);

    await userRef.update({
      "friends": FieldValue.arrayUnion([friendUid])
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Friend added!")));

    setState(() {}); // refresh
  }

  bool friendAlreadyAdded(List friends, String uid) {
    return friends.contains(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Friends"),
        backgroundColor: Colors.blueAccent,
      ),

      body: Column(
        children: [
          // ================= SEARCH BAR ==================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => searchTerm = value.trim()),
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ================= USER LIST ===================
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(currentUid)
                  .get(),

              builder: (context, currentSnapshot) {
                if (!currentSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Safe get your current friends list
                final currentData =
                    currentSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                final currentFriends = currentData["friends"] ?? [];

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .snapshots(),

                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final users = snapshot.data!.docs.where((doc) {
                      final data =
                          doc.data() as Map<String, dynamic>? ?? {};

                      final name =
                          data["name"]?.toString().toLowerCase() ?? "";

                      return name.contains(searchTerm.toLowerCase()) &&
                          doc.id != currentUid;
                    }).toList();

                    if (users.isEmpty) {
                      return const Center(child: Text("No users found"));
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userDoc = users[index];
                        final userData =
                            userDoc.data() as Map<String, dynamic>? ?? {};

                        final uid = userDoc.id;
                        final name = userData["name"] ?? "Unknown";
                        final username = userData["username"] ?? "user";

                        final alreadyAdded =
                            friendAlreadyAdded(currentFriends, uid);

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(name[0].toUpperCase()),
                          ),

                          title: Text(name),
                          subtitle: Text("@$username"),

                          trailing: ElevatedButton(
                            onPressed:
                                alreadyAdded ? null : () => addFriend(uid),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: alreadyAdded
                                  ? Colors.grey
                                  : Colors.blueAccent,
                            ),
                            child:
                                Text(alreadyAdded ? "Added" : "Add"),
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
      ),
    );
  }
}
