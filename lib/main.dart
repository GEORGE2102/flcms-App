import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'auth/auth_wrapper.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'screens/bishop/bishop_dashboard.dart';
import 'screens/pastor/pastor_dashboard.dart';
import 'screens/leader/leader_dashboard.dart';
import 'screens/treasurer/treasurer_dashboard.dart';
import 'models/user_model.dart';
import 'services/sync_service.dart';
import 'services/local_database_service.dart';
import 'services/offline_aware_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize local database and sync service
  await LocalDatabaseService().database; // Initialize local database
  final syncService = SyncService();
  await syncService.initialize();

  // Initialize conflict resolution service
  final offlineAwareService = OfflineAwareService();
  await offlineAwareService.initializeConflictResolution();

  // Start automatic sync monitoring
  syncService.startAutoSync();

  runApp(
    FirstLoveChurchApp(
      syncService: syncService,
      offlineAwareService: offlineAwareService,
    ),
  );
}

class FirstLoveChurchApp extends StatelessWidget {
  const FirstLoveChurchApp({
    super.key,
    required this.syncService,
    required this.offlineAwareService,
  });

  final SyncService syncService;
  final OfflineAwareService offlineAwareService;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: syncService),
        ChangeNotifierProvider.value(
          value: offlineAwareService.conflictService,
        ),
      ],
      child: MaterialApp(
        title: 'First Love Church CMS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle routes that need user data
          switch (settings.name) {
            case '/bishop/dashboard':
              return MaterialPageRoute(
                builder:
                    (context) => FutureBuilder<UserModel?>(
                      future: AuthService().getCurrentUserData(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const LoginScreen();
                        }
                        return BishopDashboard(user: snapshot.data!);
                      },
                    ),
              );
            case '/pastor/dashboard':
              return MaterialPageRoute(
                builder:
                    (context) => FutureBuilder<UserModel?>(
                      future: AuthService().getCurrentUserData(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const LoginScreen();
                        }
                        return PastorDashboard(user: snapshot.data!);
                      },
                    ),
              );
            case '/leader/dashboard':
              return MaterialPageRoute(
                builder:
                    (context) => FutureBuilder<UserModel?>(
                      future: AuthService().getCurrentUserData(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const LoginScreen();
                        }
                        return LeaderDashboard(user: snapshot.data!);
                      },
                    ),
              );
            case '/treasurer/dashboard':
              return MaterialPageRoute(
                builder:
                    (context) => FutureBuilder<UserModel?>(
                      future: AuthService().getCurrentUserData(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const LoginScreen();
                        }
                        return TreasurerDashboard(user: snapshot.data!);
                      },
                    ),
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
