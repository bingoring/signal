import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/signal/presentation/pages/create_signal_page.dart';
import '../features/signal/presentation/pages/signal_detail_page.dart';
import '../features/chat/presentation/pages/chat_room_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/buddy/presentation/pages/buddy_list_page.dart';
import '../features/buddy/presentation/pages/potential_buddies_page.dart';
import '../features/buddy/presentation/pages/manner_evaluation_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      
      // Main Routes
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/signal/create',
        builder: (context, state) => const CreateSignalPage(),
      ),
      GoRoute(
        path: '/signal/:id',
        builder: (context, state) {
          final signalId = state.pathParameters['id']!;
          return SignalDetailPage(signalId: signalId);
        },
      ),
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return ChatRoomPage(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      
      // Buddy Routes
      GoRoute(
        path: '/buddies',
        builder: (context, state) => const BuddyListPage(),
      ),
      GoRoute(
        path: '/potential-buddies',
        builder: (context, state) => const PotentialBuddiesPage(),
      ),
      GoRoute(
        path: '/manner-evaluation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return MannerEvaluationPage(
            rateeId: extra['rateeId'],
            rateeName: extra['rateeName'],
            signalId: extra['signalId'],
            signalTitle: extra['signalTitle'],
          );
        },
      ),
    ],
  );
}