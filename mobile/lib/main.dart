import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/messages_provider.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/create_message_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const GeoNoteApp());
}

class GeoNoteApp extends StatelessWidget {
  const GeoNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
      ],
      child: MaterialApp(
        title: 'GeoNote',
        debugShowCheckedModeBanner: false,
        theme: GeoNoteTheme.light,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginScreen(),
          '/map': (_) => const MapScreen(),
          '/create': (_) => const CreateMessageScreen(),
          '/profile': (_) => const ProfileScreen(),
        },
      ),
    );
  }
}
