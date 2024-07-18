import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sharemusic/firebase_options.dart';
import 'package:spotify/spotify.dart';
import 'package:sharemusic/google_map.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

final credentials = SpotifyApiCredentials(
  'efa883dc56374ce29ca658a7bdde188a',
  '4bd65d957c964dd39e326fa70b4c4c3a',
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SpotifyApi? spotify;
  Timer? _timer;
  String currentlyPlayingTrack = 'Ben Buradayım!';
  final redirectUri = 'sharemusic://callback';

  Future<void> _spotifyLogin() async {
    try {
      final grant = SpotifyApi.authorizationCodeGrant(credentials);
      final authUri = grant.getAuthorizationUrl(
        Uri.parse(redirectUri),
        scopes: [
          'playlist-read-private',
          'user-library-read',
          'user-read-currently-playing',
        ],
      );

      // Kullanıcıyı kimlik doğrulama sayfasına yönlendirin
      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: "sharemusic",
      );

      // Geri dönüş URL'sini işle
      final responseUri = Uri.parse(result);

      // Spotify API'ye erişim sağlayın
      spotify = SpotifyApi.fromAuthCodeGrant(grant, responseUri.toString());

      // Çalma durumu için zamanlayıcı başlat
      _startTimer();

      // Erişim izni verildiğine dair bildirim
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spotify API erişim izni verildi.')),
      );
    } catch (e) {
      print('Error during Spotify login: $e');
    }
  }

  Future<void> _currentlyPlaying(SpotifyApi spotify) async {
    try {
      final playbackState = await spotify.player.currentlyPlaying();
      if (playbackState?.item == null) {
        print('Nothing currently playing.');
      } else {
        setState(() {
          currentlyPlayingTrack = playbackState.item?.name ?? 'Ben Buradayım!';
        });
        print('Currently playing: $currentlyPlayingTrack');
      }
    } catch (e) {
      print('Error fetching currently playing track: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (spotify != null) {
        _currentlyPlaying(spotify!);
      }
    });
  }

  void navigateToMapScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MapScreen(currentlyPlayingTrack: currentlyPlayingTrack),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _spotifyLogin,
              child: const Text("Spotify Login"),
            ),
            const SizedBox(
              height: 30,
            ),
            ElevatedButton(
              onPressed: () {
                navigateToMapScreen(context);
              },
              child: const Text("İkinci Sayfa"),
            ),
          ],
        ),
      ),
    );
  }
}
