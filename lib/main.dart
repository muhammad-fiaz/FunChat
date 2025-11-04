import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/environment.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/chat_list_screen.dart';
import 'presentation/screens/auth/signin_screen.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FunChatApp()));
}

class FunChatApp extends ConsumerStatefulWidget {
  const FunChatApp({super.key});

  @override
  ConsumerState<FunChatApp> createState() => _FunChatAppState();
}

class _FunChatAppState extends ConsumerState<FunChatApp> {
  bool _isInitialized = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = ref.read(authServiceProvider);
    final user = await authService.getCurrentUser();
    
    if (user != null) {
      ref.read(currentUserIdProvider.notifier).setUserId(user.userId);
      await _initialize(user.userId);
      setState(() {
        _isAuthenticated = true;
        _isInitialized = true;
      });
    } else {
      setState(() {
        _isAuthenticated = false;
        _isInitialized = true;
      });
    }
  }

  Future<void> _initialize(String userId) async {
    final crypto = ref.read(signalProtocolProvider);
    await crypto.initialize(userId);

    final preKeyBundle = await crypto.generatePreKeyBundle();

    final authService = ref.read(authServiceProvider);
    final user = await authService.getCurrentUser();

    final signaling = ref.read(signalingProvider);
    await signaling.connect(userId);
    await signaling.register(
      userId,
      user?.email ?? '',
      user?.displayName ?? '',
      preKeyBundle,
      user?.profileImage,
    );

    signaling.messageStream.listen((message) {
      _handleSignalingMessage(message);
    });
  }

  void _handleSignalingMessage(Map<String, dynamic> message) {
    final chatRepo = ref.read(chatRepositoryProvider);
    
    switch (message['type']) {
      case 'offer':
        chatRepo.handleOffer(message['from'], message['offer']);
        break;
      case 'answer':
        chatRepo.handleAnswer(message['from'], message['answer']);
        break;
      case 'ice':
        chatRepo.handleIceCandidate(message['from'], message['candidate']);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);

    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: Environment.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: _isAuthenticated ? const ChatListScreen() : const SignInScreen(),
    );
  }
}
