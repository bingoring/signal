# Frontend Development Priorities - Signal App

## 📱 개발 전략 개요

### 플랫폼별 접근 방식
- **Flutter (iOS)**: MVP 기능 우선 개발, 빠른 프로토타이핑
- **Android (Kotlin)**: Flutter 완성 후 포팅, 네이티브 최적화 적용
- **공통 개발**: 디자인 시스템, API 클라이언트, 상태 관리 패턴 표준화

---

## 🎯 Phase 1: Core MVP Features (4주)

### Week 1: 지도 기반 시그널 탐색

#### Flutter (iOS) 우선 구현
```dart
// 1. Google Maps 통합
dependencies:
  google_maps_flutter: ^2.5.0
  geolocator: ^10.1.0
  permission_handler: ^11.1.0
```

**구현 우선순위:**
1. **지도 뷰 컴포넌트** (2일)
   ```dart
   class SignalMapView extends StatefulWidget {
     @override
     Widget build(BuildContext context) {
       return GoogleMap(
         onMapCreated: _onMapCreated,
         markers: _buildSignalMarkers(),
         onCameraMove: _onCameraMove,
         myLocationEnabled: true,
         myLocationButtonEnabled: true,
       );
     }
   }
   ```

2. **위치 권한 관리** (1일)
   ```dart
   class LocationService {
     Future<Position> getCurrentPosition() async {
       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
       LocationPermission permission = await Geolocator.checkPermission();
       // Permission handling...
     }
   }
   ```

3. **시그널 마커 표시** (2일)
   ```dart
   Set<Marker> _buildSignalMarkers() {
     return state.nearbySignals.map((signal) => Marker(
       markerId: MarkerId(signal.id.toString()),
       position: LatLng(signal.latitude, signal.longitude),
       icon: _getMarkerIcon(signal.category),
       onTap: () => _showSignalDetails(signal),
     )).toSet();
   }
   ```

#### Android 기본 구조
```kotlin
// 기본 지도 액티비티 구조만 설정
class MapActivity : AppCompatActivity() {
    private lateinit var mapFragment: SupportMapFragment
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Basic Google Maps setup
    }
}
```

### Week 2: 시그널 생성 플로우

#### Flutter 구현
1. **시그널 생성 폼** (2일)
   ```dart
   class CreateSignalPage extends StatefulWidget {
     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(title: Text('시그널 보내기')),
         body: Column(children: [
           _CategorySelector(),
           _DateTimePicker(),
           _ParticipantCounter(),
           _LocationPicker(),
           _CreateButton(),
         ]),
       );
     }
   }
   ```

2. **카테고리 선택 UI** (1일)
   ```dart
   class CategorySelector extends StatelessWidget {
     final List<SignalCategory> categories = [
       SignalCategory(icon: '🎲', name: '게임', color: Colors.purple),
       SignalCategory(icon: '🍽️', name: '식사', color: Colors.orange),
       SignalCategory(icon: '🏃', name: '운동', color: Colors.green),
     ];
   }
   ```

3. **장소 선택 인터페이스** (2일)
   - 지도에서 핀 선택
   - 장소 검색 기능
   - 현재 위치 자동 설정

#### Android 기본 UI
- Material Design 3 기반 시그널 생성 화면
- Jetpack Compose로 카테고리 선택 UI

### Week 3: 실시간 알림 시스템

#### Firebase 통합
1. **FCM 설정** (1일)
   ```dart
   class PushNotificationService {
     final FirebaseMessaging _fcm = FirebaseMessaging.instance;
     
     Future<void> initialize() async {
       NotificationSettings settings = await _fcm.requestPermission();
       String? token = await _fcm.getToken();
       _sendTokenToServer(token);
     }
   }
   ```

2. **푸시 알림 처리** (2일)
   ```dart
   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     _showLocalNotification(message);
   });
   
   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     _handleNotificationTap(message);
   });
   ```

3. **딥링크 처리** (2일)
   - 알림 클릭 시 해당 시그널 상세로 이동
   - 앱 상태별 분기 처리

#### 알림 설정 UI
```dart
class NotificationSettingsPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      SwitchListTile(
        title: Text('새 시그널 알림'),
        subtitle: Text('관심 카테고리의 새 시그널을 받아보세요'),
        value: settings.newSignalNotification,
        onChanged: (value) => _updateSetting('new_signal', value),
      ),
    ]);
  }
}
```

### Week 4: 기본 채팅 UI

#### WebSocket 클라이언트
```dart
class WebSocketService {
  IOWebSocketChannel? _channel;
  
  void connect(String roomId) {
    _channel = IOWebSocketChannel.connect(
      'ws://localhost:8080/ws/chat/$roomId',
    );
    
    _channel!.stream.listen((message) {
      _handleIncomingMessage(json.decode(message));
    });
  }
}
```

#### 채팅 UI 컴포넌트
```dart
class ChatPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildChatAppBar(),
      body: Column(children: [
        _buildCountdownTimer(),
        Expanded(child: _buildMessageList()),
        _buildMessageInput(),
      ]),
    );
  }
}
```

---

## 🚀 Phase 2: Advanced Features (6주)

### Week 5-6: 향상된 지도 기능

#### 고급 지도 기능
1. **클러스터링** (3일)
   ```dart
   class SignalCluster {
     final LatLng center;
     final List<Signal> signals;
     final int count;
     
     Marker toMarker() {
       return Marker(
         markerId: MarkerId('cluster_${center.toString()}'),
         position: center,
         icon: _createClusterIcon(count),
       );
     }
   }
   ```

2. **필터링 UI** (2일)
   ```dart
   class FilterBottomSheet extends StatefulWidget {
     @override
     Widget build(BuildContext context) {
       return Container(
         height: 400,
         child: Column(children: [
           _CategoryFilter(),
           _TimeRangeFilter(),  
           _DistanceSlider(),
           _GenderFilter(),
           _ApplyFilterButton(),
         ]),
       );
     }
   }
   ```

3. **검색 기능** (2일)
   - 장소명으로 검색
   - 최근 검색 기록
   - 즐겨찾기 장소

### Week 7-8: 프로필 및 매너 시스템

#### 프로필 페이지
```dart
class ProfilePage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(children: [
      _ProfileHeader(),
      _MannerScoreCard(),
      _BadgeSection(),
      _ActivityHistory(),
      _SettingsSection(),
    ]);
  }
}

class MannerScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(child: Column(children: [
      Text('매너온도', style: Theme.of(context).textTheme.titleLarge),
      CustomPaint(
        painter: ThermometerPainter(score: user.mannerScore),
        size: Size(200, 100),
      ),
      Text('${user.mannerScore}°C'),
    ]));
  }
}
```

#### 평가 시스템
```dart
class RatingDialog extends StatefulWidget {
  @override  
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('모임은 어떠셨나요?'),
      content: Column(children: [
        _RatingStars(),
        _QuickFeedbackButtons(),
        _CommentTextField(),
        _NoShowCheckbox(),
      ]),
      actions: [_SubmitButton()],
    );
  }
}
```

### Week 9-10: 이미지 및 미디어 처리

#### 이미지 업로드
```dart
class ImageUploadService {
  Future<String> uploadProfileImage(File imageFile) async {
    // 이미지 압축
    File compressedFile = await _compressImage(imageFile);
    
    // S3 업로드
    String uploadUrl = await _getPresignedUrl();
    String imageUrl = await _uploadToS3(compressedFile, uploadUrl);
    
    return imageUrl;
  }
}
```

#### 카메라/갤러리 통합
```dart
class ImagePickerWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
        icon: Icon(Icons.camera_alt),
        onPressed: () => _pickImage(ImageSource.camera),
      ),
      IconButton(
        icon: Icon(Icons.photo_library),
        onPressed: () => _pickImage(ImageSource.gallery),
      ),
    ]);
  }
}
```

---

## 🎨 Design System & UI Components

### 컬러 팔레트
```dart
class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryVariant = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Signal category colors
  static const Color gameColor = Color(0xFF8B5CF6);
  static const Color foodColor = Color(0xFFF97316);
  static const Color sportsColor = Color(0xFF059669);
  static const Color cultureColor = Color(0xFFDC2626);
}
```

### 공통 위젯
```dart
// 시그널 카드 컴포넌트
class SignalCard extends StatelessWidget {
  final Signal signal;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          _SignalHeader(signal),
          _SignalContent(signal),
          _SignalFooter(signal),
        ]),
      ),
    );
  }
}

// 매너온도 표시 위젯
class MannerThermometer extends StatelessWidget {
  final double score;
  
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ThermometerPainter(score: score),
      size: Size(40, 80),
    );
  }
}
```

---

## 📊 상태 관리 아키텍처 (BLoC 패턴)

### 핵심 BLoC들
```dart
// 시그널 관련 상태 관리
class SignalBloc extends Bloc<SignalEvent, SignalState> {
  final SignalRepository repository;
  final LocationService locationService;
  
  SignalBloc({required this.repository, required this.locationService}) 
      : super(SignalInitial()) {
    on<LoadNearbySignals>(_onLoadNearbySignals);
    on<CreateSignal>(_onCreateSignal);
    on<JoinSignal>(_onJoinSignal);
    on<FilterSignals>(_onFilterSignals);
  }
}

// 채팅 상태 관리
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final WebSocketService wsService;
  final ChatRepository repository;
  
  ChatBloc({required this.wsService, required this.repository}) 
      : super(ChatInitial()) {
    on<ConnectToChat>(_onConnectToChat);
    on<SendMessage>(_onSendMessage);
    on<ReceiveMessage>(_onReceiveMessage);
  }
}
```

### 의존성 주입
```dart
class ServiceLocator {
  static final GetIt _instance = GetIt.instance;
  
  static void setup() {
    // Services
    _instance.registerLazySingleton<ApiService>(() => ApiService());
    _instance.registerLazySingleton<LocationService>(() => LocationService());
    _instance.registerLazySingleton<WebSocketService>(() => WebSocketService());
    
    // Repositories  
    _instance.registerLazySingleton<SignalRepository>(
      () => SignalRepositoryImpl(_instance<ApiService>()),
    );
    
    // BLoCs
    _instance.registerFactory<SignalBloc>(
      () => SignalBloc(
        repository: _instance<SignalRepository>(),
        locationService: _instance<LocationService>(),
      ),
    );
  }
}
```

---

## 🧪 테스트 전략

### Unit Tests
```dart
void main() {
  group('SignalBloc Tests', () {
    late SignalBloc signalBloc;
    late MockSignalRepository mockRepository;
    
    setUp(() {
      mockRepository = MockSignalRepository();
      signalBloc = SignalBloc(repository: mockRepository);
    });
    
    test('should emit SignalLoaded when LoadNearbySignals is successful', () async {
      // Arrange
      when(mockRepository.getNearbySignals(any, any, any))
          .thenAnswer((_) async => [testSignal]);
      
      // Act
      signalBloc.add(LoadNearbySignals(lat: 37.5, lon: 127.0, radius: 5000));
      
      // Assert
      expectLater(signalBloc.stream, emits(SignalLoaded([testSignal])));
    });
  });
}
```

### Widget Tests
```dart
void main() {
  testWidgets('SignalCard displays correct information', (tester) async {
    // Arrange
    final testSignal = Signal(
      id: 1,
      title: 'Test Signal',
      category: 'game',
      participantCount: 2,
      maxParticipants: 4,
    );
    
    // Act
    await tester.pumpWidget(MaterialApp(
      home: SignalCard(signal: testSignal),
    ));
    
    // Assert
    expect(find.text('Test Signal'), findsOneWidget);
    expect(find.text('2/4명'), findsOneWidget);
  });
}
```

### Integration Tests
```dart
void main() {
  group('End-to-End Tests', () {
    testWidgets('Complete signal creation flow', (tester) async {
      // 1. 앱 시작
      await tester.pumpWidget(MyApp());
      
      // 2. 시그널 생성 버튼 탭
      await tester.tap(find.byKey(Key('create_signal_fab')));
      await tester.pumpAndSettle();
      
      // 3. 카테고리 선택
      await tester.tap(find.text('게임'));
      
      // 4. 상세 정보 입력
      await tester.enterText(find.byKey(Key('signal_title')), '보드게임 하실 분');
      
      // 5. 시그널 생성
      await tester.tap(find.text('시그널 보내기'));
      
      // 6. 성공 메시지 확인
      expect(find.text('시그널이 성공적으로 전송되었습니다!'), findsOneWidget);
    });
  });
}
```

---

## 🔧 Android 개발 로드맵

### Kotlin + Jetpack Compose 구현 순서

#### Week 1-2: 기본 구조 (Flutter 완성 후)
```kotlin
// 1. Navigation 설정
@Composable
fun SignalNavigation() {
    val navController = rememberNavController()
    NavHost(navController, startDestination = "map") {
        composable("map") { MapScreen(navController) }
        composable("create_signal") { CreateSignalScreen(navController) }
        composable("chat/{roomId}") { ChatScreen(navController) }
    }
}

// 2. 상태 관리 (Hilt + ViewModel)
@HiltViewModel  
class SignalViewModel @Inject constructor(
    private val signalRepository: SignalRepository
) : ViewModel() {
    private val _nearbySignals = mutableStateOf<List<Signal>>(emptyList())
    val nearbySignals: State<List<Signal>> = _nearbySignals
    
    fun loadNearbySignals(lat: Double, lon: Double) {
        viewModelScope.launch {
            _nearbySignals.value = signalRepository.getNearbySignals(lat, lon)
        }
    }
}
```

#### Week 3-4: 고급 기능 포팅
- Google Maps Compose 통합
- Material Design 3 적용
- 네이티브 성능 최적화

---

## 📅 즉시 착수 가능한 작업

### 오늘 시작할 수 있는 작업
1. **Flutter Google Maps 설정** (2시간)
   ```bash
   cd ios
   flutter pub add google_maps_flutter geolocator permission_handler
   ```

2. **기본 지도 화면 구현** (4시간)
   - GoogleMap 위젯 추가
   - 현재 위치 표시
   - 기본 마커 표시

3. **Firebase 프로젝트 설정** (1시간)
   - Firebase Console에서 프로젝트 생성
   - iOS/Android 앱 등록
   - google-services.json/GoogleService-Info.plist 설정

### 이번 주 완료 목표
- [ ] 지도 기반 메인 화면 완성
- [ ] 시그널 마커 실시간 표시
- [ ] 기본 위치 권한 및 서비스
- [ ] 푸시 알림 기초 설정

이 우선순위에 따라 개발하면 4주 내에 핵심 기능이 동작하는 MVP를 완성할 수 있습니다!