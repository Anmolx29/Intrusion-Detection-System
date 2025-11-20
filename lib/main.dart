import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

/// 🔹 Handles background notifications
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("📩 Background message: ${message.notification?.title}");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sign in anonymously (needed for RTDB)
  await FirebaseAuth.instance.signInAnonymously();

  // 🔹 Setup Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notifications settings
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PIR Motion Detector',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MotionScreen(),
    );
  }
}

class MotionScreen extends StatefulWidget {
  const MotionScreen({super.key});

  @override
  _MotionScreenState createState() => _MotionScreenState();
}

class _MotionScreenState extends State<MotionScreen> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
  String deviceStatus = "Loading...";
  String lastActive = "N/A";
  String motionStatus = "Waiting...";
  String motionTime = "";

  @override
  void initState() {
    super.initState();

    // 🔹 Listen to Realtime Database changes
    dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final motion = data['motion'] ?? {};
        final status = data['device_status'] ?? "Unknown";
        final active = data['last_active'] ?? "N/A";

        setState(() {
          deviceStatus = status;
          lastActive = active;
          motionStatus = motion['status'] ?? "Unknown";
          motionTime = motion['timestamp'] ?? "";
        });

        // Save event to logs in RTDB
        _saveLog(motionStatus);

        // Show local notification
        _showNotification(
          "Motion Update",
          body: "${motion['status']} at ${motion['timestamp']}",
        );
      }
    });

    // 🔹 Foreground push notifications (from FCM)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(
        message.notification?.title ?? "Motion Update",
        body: message.notification?.body ?? "",
      );
    });
  }

  /// Save motion events to logs
  void _saveLog(String status) {
    final DatabaseReference logsRef = FirebaseDatabase.instance.ref("logs");
    final timestamp = DateTime.now().toString();

    logsRef.push().set({"status": status, "timestamp": timestamp});
  }

  /// Local notification
  Future<void> _showNotification(String title, {String body = ""}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'motion_channel',
          'Motion Alerts',
          channelDescription: 'Notifies when motion is detected',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'motion',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PIR Motion Detector")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListTile(
                leading: const Icon(Icons.device_hub, color: Colors.blue),
                title: Text("Device Status: $deviceStatus"),
                subtitle: Text("Last Active: $lastActive"),
              ),
            ),
            Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListTile(
                leading: Icon(
                  motionStatus == "Motion Detected"
                      ? Icons.directions_run
                      : Icons.pause_circle_filled,
                  color: motionStatus == "Motion Detected"
                      ? Colors.red
                      : Colors.green,
                ),
                title: Text("Motion Status: $motionStatus"),
                subtitle: Text("Time: $motionTime"),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogbookScreen()),
          );
        },
        label: const Text("Logbook"),
        icon: const Icon(Icons.list),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

// 🔹 Logbook Screen
class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  final DatabaseReference _logsRef = FirebaseDatabase.instance.ref("logs");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Motion Logbook")),
      body: StreamBuilder(
        stream: _logsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("⚠ Error loading logs"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final event = snapshot.data as DatabaseEvent;
          final data = event.snapshot.value as Map<dynamic, dynamic>?;

          if (data == null) {
            return const Center(child: Text("📭 No logs yet"));
          }

          final logs = data.entries.map((entry) {
            final value = entry.value as Map<dynamic, dynamic>;
            return {
              "status": value["status"] ?? "Unknown",
              "timestamp": value["timestamp"] ?? "",
            };
          }).toList();

          logs.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    log["status"] == "Motion Detected"
                        ? Icons.directions_run
                        : Icons.pause_circle_filled,
                    color: log["status"] == "Motion Detected"
                        ? Colors.red
                        : Colors.green,
                  ),
                  title: Text(log["status"]),
                  subtitle: Text(log["timestamp"]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
