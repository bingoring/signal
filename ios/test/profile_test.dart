import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:signal_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:signal_app/features/profile/presentation/pages/profile_page.dart';
import 'package:signal_app/features/profile/data/repositories/profile_repository.dart';
import 'package:signal_app/core/services/profile_service.dart';
import 'package:signal_app/core/network/api_result.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('Profile Integration Tests', () {
    late MockProfileRepository mockRepository;
    late ProfileBloc profileBloc;

    setUp(() {
      mockRepository = MockProfileRepository();
      profileBloc = ProfileBloc(profileRepository: mockRepository);
    });

    tearDown(() {
      profileBloc.close();
    });

    testWidgets('ProfilePage displays loading initially', (WidgetTester tester) async {
      // Mock repository to return a loading state
      when(mockRepository.getProfile()).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return const ApiResult.success(ProfileData(
          id: 1,
          userId: 1,
          displayName: 'Test User',
          mannerTemperature: 38.5,
          signalCount: 5,
          joinCount: 3,
          completionRate: 80.0,
          notificationsEnabled: true,
          createdAt: '2024-01-01T00:00:00Z',
          updatedAt: '2024-01-01T00:00:00Z',
        ));
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProfileBloc>.value(
            value: profileBloc,
            child: const ProfilePage(),
          ),
        ),
      );

      // Should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ProfilePage displays profile data when loaded', (WidgetTester tester) async {
      const testProfile = ProfileData(
        id: 1,
        userId: 1,
        displayName: 'Test User',
        mannerTemperature: 38.5,
        signalCount: 5,
        joinCount: 3,
        completionRate: 80.0,
        avatar: '😊',
        oneLine: 'Hello, I love meeting new people!',
        notificationsEnabled: true,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      const testTrustStats = TrustStats(
        mannerTemperature: 38.5,
        trustLevel: '보통',
        signalCount: 5,
        joinCount: 3,
        completionRate: 80.0,
        totalRatings: 10,
        noShowCount: 1,
        rankPercentage: 75.0,
      );

      when(mockRepository.getProfile())
          .thenAnswer((_) async => const ApiResult.success(testProfile));
      when(mockRepository.getTrustStats())
          .thenAnswer((_) async => const ApiResult.success(testTrustStats));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProfileBloc>.value(
            value: profileBloc,
            child: const ProfilePage(),
          ),
        ),
      );

      // Wait for the profile to load
      await tester.pumpAndSettle();

      // Should display profile information
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('38.5°C'), findsOneWidget);
      expect(find.text('신뢰도 보통'), findsOneWidget);
      expect(find.text('Hello, I love meeting new people!'), findsOneWidget);
      expect(find.text('5'), findsAtLeastNWidgets(1)); // Signal count
      expect(find.text('3'), findsAtLeastNWidgets(1)); // Join count
    });

    testWidgets('ProfilePage shows edit dialog when edit button is tapped', (WidgetTester tester) async {
      const testProfile = ProfileData(
        id: 1,
        userId: 1,
        displayName: 'Test User',
        mannerTemperature: 38.5,
        signalCount: 5,
        joinCount: 3,
        completionRate: 80.0,
        notificationsEnabled: true,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      when(mockRepository.getProfile())
          .thenAnswer((_) async => const ApiResult.success(testProfile));
      when(mockRepository.getTrustStats())
          .thenAnswer((_) async => const ApiResult.success(TrustStats(
            mannerTemperature: 38.5,
            trustLevel: '보통',
            signalCount: 5,
            joinCount: 3,
            completionRate: 80.0,
            totalRatings: 10,
            noShowCount: 1,
            rankPercentage: 75.0,
          )));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProfileBloc>.value(
            value: profileBloc,
            child: const ProfilePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the edit button
      final editButton = find.byIcon(Icons.edit_outlined);
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Should show edit dialog
      expect(find.text('프로필 수정'), findsOneWidget);
      expect(find.text('닉네임 (2-30자)'), findsOneWidget);
      expect(find.text('아바타 선택:'), findsOneWidget);
    });

    test('ProfileBloc handles profile loading correctly', () async {
      const testProfile = ProfileData(
        id: 1,
        userId: 1,
        displayName: 'Test User',
        mannerTemperature: 38.5,
        signalCount: 5,
        joinCount: 3,
        completionRate: 80.0,
        notificationsEnabled: true,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      when(mockRepository.getProfile())
          .thenAnswer((_) async => const ApiResult.success(testProfile));
      when(mockRepository.getTrustStats())
          .thenAnswer((_) async => const ApiResult.success(TrustStats(
            mannerTemperature: 38.5,
            trustLevel: '보통',
            signalCount: 5,
            joinCount: 3,
            completionRate: 80.0,
            totalRatings: 10,
            noShowCount: 1,
            rankPercentage: 75.0,
          )));

      final states = <ProfileState>[];
      profileBloc.stream.listen(states.add);

      profileBloc.add(ProfileRequested());

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states, [
        ProfileLoading(),
        isA<ProfileLoaded>()
            .having((s) => s.profile.displayName, 'displayName', 'Test User')
            .having((s) => s.profile.mannerTemperature, 'mannerTemperature', 38.5),
      ]);
    });

    test('ProfileBloc handles profile update correctly', () async {
      const originalProfile = ProfileData(
        id: 1,
        userId: 1,
        displayName: 'Original Name',
        mannerTemperature: 38.5,
        signalCount: 5,
        joinCount: 3,
        completionRate: 80.0,
        notificationsEnabled: true,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      const updatedProfile = ProfileData(
        id: 1,
        userId: 1,
        displayName: 'Updated Name',
        mannerTemperature: 38.5,
        signalCount: 5,
        joinCount: 3,
        completionRate: 80.0,
        notificationsEnabled: true,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-02T00:00:00Z',
      );

      // Setup initial state
      profileBloc.emit(const ProfileLoaded(profile: originalProfile));

      when(mockRepository.updateProfile(any))
          .thenAnswer((_) async => const ApiResult.success(updatedProfile));
      when(mockRepository.getProfile())
          .thenAnswer((_) async => const ApiResult.success(updatedProfile));
      when(mockRepository.getTrustStats())
          .thenAnswer((_) async => const ApiResult.success(TrustStats(
            mannerTemperature: 38.5,
            trustLevel: '보통',
            signalCount: 5,
            joinCount: 3,
            completionRate: 80.0,
            totalRatings: 10,
            noShowCount: 1,
            rankPercentage: 75.0,
          )));

      final states = <ProfileState>[];
      profileBloc.stream.listen(states.add);

      profileBloc.add(const ProfileUpdated(
        UpdateProfileRequest(displayName: 'Updated Name'),
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states, [
        ProfileUpdating(),
        isA<ProfileUpdateSuccess>()
            .having((s) => s.profile.displayName, 'displayName', 'Updated Name'),
        ProfileLoading(), // Reload after successful update
        isA<ProfileLoaded>()
            .having((s) => s.profile.displayName, 'displayName', 'Updated Name'),
      ]);
    });
  });

  group('Profile Data Model Tests', () {
    test('ProfileData fromJson works correctly', () {
      final json = {
        'id': 1,
        'user_id': 123,
        'display_name': 'Test User',
        'manner_temperature': 38.5,
        'signal_count': 5,
        'join_count': 3,
        'completion_rate': 80.0,
        'notifications_enabled': true,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final profile = ProfileData.fromJson(json);

      expect(profile.id, 1);
      expect(profile.userId, 123);
      expect(profile.displayName, 'Test User');
      expect(profile.mannerTemperature, 38.5);
      expect(profile.signalCount, 5);
      expect(profile.joinCount, 3);
      expect(profile.completionRate, 80.0);
      expect(profile.notificationsEnabled, true);
    });

    test('ProfileData toJson works correctly', () {
      const profile = ProfileData(
        id: 1,
        userId: 123,
        displayName: 'Test User',
        mannerTemperature: 38.5,
        signalCount: 5,
        joinCount: 3,
        completionRate: 80.0,
        notificationsEnabled: true,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      final json = profile.toJson();

      expect(json['id'], 1);
      expect(json['user_id'], 123);
      expect(json['display_name'], 'Test User');
      expect(json['manner_temperature'], 38.5);
      expect(json['signal_count'], 5);
      expect(json['join_count'], 3);
      expect(json['completion_rate'], 80.0);
      expect(json['notifications_enabled'], true);
    });

    test('QuickSetupRequest validation', () {
      const request = QuickSetupRequest(
        displayName: 'New User',
        avatar: '😊',
        oneLine: 'Hello world!',
      );

      final json = request.toJson();
      expect(json['display_name'], 'New User');
      expect(json['avatar'], '😊');
      expect(json['one_line'], 'Hello world!');
    });
  });
}