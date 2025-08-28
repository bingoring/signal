# 핵심 기능 개발 순서 상세 가이드

## 📋 개발 원칙

### 개발 접근 방식
- **Backend-First**: API를 먼저 완성한 후 Frontend 연동
- **Feature-Complete**: 각 기능을 수직적으로 완전히 구현
- **Iterative**: 작은 단위로 테스트하며 점진적 개선
- **Mobile-First**: Flutter를 우선 개발 후 Android 포팅

---

## 🎯 Sprint 1: 지도 기반 시그널 탐색 (1주)

### 🔧 Backend 작업 (3일)

#### Day 1: PostGIS 지리적 검색 API
```go
// signal_handler.go 업데이트
func (h *SignalHandler) GetNearbySignals(c *gin.Context) {
    lat, _ := strconv.ParseFloat(c.Query("lat"), 64)
    lon, _ := strconv.ParseFloat(c.Query("lon"), 64) 
    radius, _ := strconv.ParseFloat(c.Query("radius"), 64)
    categories := strings.Split(c.Query("categories"), ",")
    
    signals, err := h.signalService.GetNearbySignals(lat, lon, radius, categories)
    if err != nil {
        utils.InternalServerErrorResponse(c, "Failed to get nearby signals", err)
        return
    }
    
    utils.SuccessResponse(c, "Nearby signals retrieved", gin.H{
        "signals": signals,
        "count": len(signals),
    })
}
```

**구체적 작업:**
- [ ] Signal 모델에 PostGIS Point 필드 추가
- [ ] 지리적 검색 쿼리 구현
- [ ] 카테고리 필터링 로직 추가
- [ ] API 엔드포인트 테스트

#### Day 2: 실시간 시그널 상태 관리
```go
// Redis를 활용한 실시간 시그널 캐싱
func (s *SignalService) CacheActiveSignals() error {
    ctx := context.Background()
    key := "active_signals:geo"
    
    // 기존 캐시 삭제
    s.redis.Del(ctx, key)
    
    // 활성 시그널들을 Redis GEO에 저장
    signals, err := s.GetActiveSignals()
    if err != nil {
        return err
    }
    
    for _, signal := range signals {
        err := s.redis.GeoAdd(ctx, key, &redis.GeoLocation{
            Name:      fmt.Sprintf("signal:%d", signal.ID),
            Longitude: signal.Longitude,
            Latitude:  signal.Latitude,
        }).Err()
        if err != nil {
            return err
        }
        
        // 시그널 상세 정보도 별도 캐싱
        signalKey := fmt.Sprintf("signal:%d:details", signal.ID)
        s.redis.Set(ctx, signalKey, signal.ToJSON(), 5*time.Minute)
    }
    
    return nil
}
```

**구체적 작업:**
- [ ] Redis GEO 기반 캐싱 구현
- [ ] 시그널 상태 변경 시 캐시 업데이트
- [ ] 실시간 동기화 로직

#### Day 3: WebSocket 실시간 업데이트
```go
// signal_websocket.go 새 파일 생성
type SignalHub struct {
    clients    map[*SignalClient]bool
    broadcast  chan SignalUpdate
    register   chan *SignalClient
    unregister chan *SignalClient
}

type SignalUpdate struct {
    Type     string `json:"type"`     // "new", "update", "delete"
    Signal   Signal `json:"signal"`
    Location Point  `json:"location"`
}

func (hub *SignalHub) Run() {
    for {
        select {
        case client := <-hub.register:
            hub.clients[client] = true
            
        case client := <-hub.unregister:
            if _, ok := hub.clients[client]; ok {
                delete(hub.clients, client)
                close(client.send)
            }
            
        case update := <-hub.broadcast:
            for client := range hub.clients {
                // 클라이언트 위치 기반으로 필터링
                if hub.isInRange(client.location, update.Location) {
                    select {
                    case client.send <- update:
                    default:
                        close(client.send)
                        delete(hub.clients, client)
                    }
                }
            }
        }
    }
}
```

**구체적 작업:**
- [ ] WebSocket 허브 구현
- [ ] 클라이언트 위치 기반 필터링
- [ ] 시그널 생성/삭제/업데이트 시 실시간 브로드캐스팅

### 📱 Frontend 작업 (4일)

#### Day 1: Google Maps 기본 설정
```bash
cd ios
flutter pub add google_maps_flutter geolocator permission_handler
```

```dart
// lib/features/map/presentation/pages/map_page.dart
class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  Set<Marker> markers = {};
  LatLng currentLocation = LatLng(37.5665, 126.9780); // 서울시청
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadNearbySignals();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: currentLocation,
          zoom: 14.0,
        ),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onCameraMove: _onCameraMove,
        onCameraIdle: _onCameraIdle,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSignalPage,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

#### Day 2: 위치 권한 및 서비스
```dart
// lib/core/services/location_service.dart
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    }
    
    return await Geolocator.getCurrentPosition();
  }
  
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}
```

#### Day 3: API 클라이언트 및 상태 관리
```dart
// lib/features/signal/data/datasources/signal_remote_datasource.dart
class SignalRemoteDataSource {
  final Dio dio;
  
  SignalRemoteDataSource({required this.dio});
  
  Future<List<SignalModel>> getNearbySignals({
    required double lat,
    required double lon,
    required double radius,
    List<String>? categories,
  }) async {
    final response = await dio.get(
      '/api/v1/signals/nearby',
      queryParameters: {
        'lat': lat,
        'lon': lon,
        'radius': radius,
        if (categories != null) 'categories': categories.join(','),
      },
    );
    
    return (response.data['data']['signals'] as List)
        .map((json) => SignalModel.fromJson(json))
        .toList();
  }
}

// BLoC 구현
class SignalMapBloc extends Bloc<SignalMapEvent, SignalMapState> {
  final SignalRepository signalRepository;
  final LocationService locationService;
  
  SignalMapBloc({
    required this.signalRepository,
    required this.locationService,
  }) : super(SignalMapInitial()) {
    on<LoadNearbySignals>(_onLoadNearbySignals);
    on<UpdateLocation>(_onUpdateLocation);
  }
  
  Future<void> _onLoadNearbySignals(
    LoadNearbySignals event,
    Emitter<SignalMapState> emit,
  ) async {
    emit(SignalMapLoading());
    try {
      final signals = await signalRepository.getNearbySignals(
        lat: event.lat,
        lon: event.lon,
        radius: event.radius,
        categories: event.categories,
      );
      emit(SignalMapLoaded(signals: signals));
    } catch (e) {
      emit(SignalMapError(message: e.toString()));
    }
  }
}
```

#### Day 4: 시그널 마커 표시 및 상호작용
```dart
// lib/features/map/presentation/widgets/signal_marker.dart
class SignalMarkerBuilder {
  static Future<BitmapDescriptor> createMarkerIcon(
    SignalCategory category,
    int participantCount,
    int maxParticipants,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(60, 80);
    
    // 카테고리별 색상
    final color = _getCategoryColor(category);
    
    // 마커 배경 그리기
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - 20),
        Radius.circular(30),
      ),
      paint,
    );
    
    // 참여자 수 텍스트
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$participantCount/$maxParticipants',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(15, 25));
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}
```

---

## 🎯 Sprint 2: 시그널 생성 플로우 (1주)

### 🔧 Backend 작업 (2일)

#### Day 1: 시그널 생성 API 강화
```go
// signal_service.go 업데이트
func (s *SignalService) CreateSignal(req *models.CreateSignalRequest) (*models.Signal, error) {
    // 1. 사용자 권한 확인
    user, err := s.userRepo.GetByID(req.UserID)
    if err != nil {
        return nil, fmt.Errorf("user not found")
    }
    
    if user.MannerScore < 32.0 {
        return nil, fmt.Errorf("manner score too low to create signal")
    }
    
    // 2. 위치 유효성 검사
    if !utils.IsValidCoordinate(req.Latitude, req.Longitude) {
        return nil, fmt.Errorf("invalid coordinates")
    }
    
    // 3. 시그널 생성
    signal := &models.Signal{
        UserID:             req.UserID,
        Title:              req.Title,
        Description:        req.Description,
        Category:           req.Category,
        Latitude:           req.Latitude,
        Longitude:          req.Longitude,
        StartTime:          req.StartTime,
        MaxParticipants:    req.MaxParticipants,
        CurrentParticipants: 1,
        Status:             "active",
        GenderRestriction:  req.GenderRestriction,
        AgeRestriction:     req.AgeRestriction,
    }
    
    // 4. 데이터베이스 저장
    if err := s.signalRepo.Create(signal); err != nil {
        return nil, err
    }
    
    // 5. 캐시 업데이트
    s.UpdateSignalCache(signal)
    
    // 6. 매칭 사용자들에게 푸시 알림
    go s.SendSignalNotifications(signal)
    
    return signal, nil
}
```

#### Day 2: 참여 요청 및 승인 로직
```go
func (s *SignalService) JoinSignal(signalID uint, userID uint, message string) error {
    signal, err := s.signalRepo.GetByID(signalID)
    if err != nil {
        return err
    }
    
    // 참여 조건 검사
    if signal.CurrentParticipants >= signal.MaxParticipants {
        return fmt.Errorf("signal is full")
    }
    
    if signal.UserID == userID {
        return fmt.Errorf("cannot join own signal")
    }
    
    // 기존 참여 여부 확인
    exists, err := s.signalRepo.IsParticipant(signalID, userID)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("already joined")
    }
    
    // 참여 요청 생성
    joinRequest := &models.SignalJoinRequest{
        SignalID: signalID,
        UserID:   userID,
        Message:  message,
        Status:   "pending",
    }
    
    if err := s.signalRepo.CreateJoinRequest(joinRequest); err != nil {
        return err
    }
    
    // 주최자에게 알림
    go s.NotifySignalOwner(signal.UserID, joinRequest)
    
    return nil
}
```

### 📱 Frontend 작업 (3일)

#### Day 1: 시그널 생성 UI
```dart
// lib/features/signal/presentation/pages/create_signal_page.dart
class CreateSignalPage extends StatefulWidget {
  @override
  _CreateSignalPageState createState() => _CreateSignalPageState();
}

class _CreateSignalPageState extends State<CreateSignalPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  SignalCategory? selectedCategory;
  DateTime? selectedDateTime;
  int maxParticipants = 4;
  LatLng? selectedLocation;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('시그널 보내기'),
        actions: [
          TextButton(
            onPressed: _canSubmit() ? _submitSignal : null,
            child: Text('완료'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildCategorySelector(),
            SizedBox(height: 16),
            _buildTitleField(),
            SizedBox(height: 16),
            _buildDescriptionField(),
            SizedBox(height: 16),
            _buildDateTimePicker(),
            SizedBox(height: 16),
            _buildParticipantCounter(),
            SizedBox(height: 16),
            _buildLocationSelector(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('무엇을 함께 할까요?', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: SignalCategory.values.map((category) {
            final isSelected = selectedCategory == category;
            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.emoji),
                  SizedBox(width: 4),
                  Text(category.displayName),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  selectedCategory = selected ? category : null;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
```

#### Day 2: 위치 선택 및 지도 통합
```dart
// lib/features/signal/presentation/widgets/location_picker.dart
class LocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final Function(LatLng) onLocationSelected;
  
  const LocationPicker({
    Key? key,
    this.initialLocation,
    required this.onLocationSelected,
  }) : super(key: key);
  
  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late GoogleMapController mapController;
  LatLng? selectedLocation;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation ?? LatLng(37.5665, 126.9780),
              zoom: 16,
            ),
            onTap: (latLng) {
              setState(() {
                selectedLocation = latLng;
              });
              widget.onLocationSelected(latLng);
            },
            markers: selectedLocation != null
                ? {
                    Marker(
                      markerId: MarkerId('selected'),
                      position: selectedLocation!,
                    )
                  }
                : {},
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
              ),
              child: Text(
                selectedLocation != null
                    ? '모임 장소가 선택되었습니다'
                    : '지도를 터치해서 모임 장소를 선택하세요',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### Day 3: 시그널 상세 및 참여 기능
```dart
// lib/features/signal/presentation/pages/signal_detail_page.dart
class SignalDetailPage extends StatelessWidget {
  final Signal signal;
  
  const SignalDetailPage({Key? key, required this.signal}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(signal.title),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share',
                child: Text('공유하기'),
              ),
              PopupMenuItem(
                value: 'report',
                child: Text('신고하기'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSignalHeader(),
            SizedBox(height: 16),
            _buildHostInfo(),
            SizedBox(height: 16),
            _buildSignalDetails(),
            SizedBox(height: 16),
            _buildParticipants(),
            SizedBox(height: 16),
            _buildLocationInfo(),
          ],
        ),
      ),
      bottomNavigationBar: _buildJoinButton(context),
    );
  }
  
  Widget _buildJoinButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: BlocBuilder<SignalBloc, SignalState>(
        builder: (context, state) {
          return ElevatedButton(
            onPressed: signal.canJoin ? () => _showJoinDialog(context) : null,
            child: Text(
              signal.canJoin ? '참여 요청하기' : '마감된 시그널',
              style: TextStyle(fontSize: 16),
            ),
          );
        },
      ),
    );
  }
  
  void _showJoinDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => JoinSignalBottomSheet(signal: signal),
    );
  }
}
```

---

## 🎯 Sprint 3: 실시간 채팅 시스템 (1주)

### 🔧 Backend 작업 (3일)

#### Day 1: WebSocket 채팅 인프라
```go
// websocket_service.go
type ChatMessage struct {
    ID        uint      `json:"id"`
    RoomID    string    `json:"room_id"`
    UserID    uint      `json:"user_id"`
    Username  string    `json:"username"`
    Content   string    `json:"content"`
    Type      string    `json:"type"` // text, image, location, system
    Timestamp time.Time `json:"timestamp"`
}

type ChatRoom struct {
    ID           string                 `json:"id"`
    SignalID     uint                   `json:"signal_id"`
    Participants map[uint]*ChatClient   `json:"-"`
    Messages     chan *ChatMessage      `json:"-"`
    Join         chan *ChatClient       `json:"-"`
    Leave        chan *ChatClient       `json:"-"`
    Created      time.Time              `json:"created"`
    ExpiresAt    time.Time              `json:"expires_at"`
}

func (room *ChatRoom) Run() {
    defer func() {
        close(room.Messages)
        close(room.Join) 
        close(room.Leave)
    }()
    
    for {
        select {
        case client := <-room.Join:
            room.Participants[client.UserID] = client
            
            // 시스템 메시지: 새 참여자
            systemMsg := &ChatMessage{
                RoomID:    room.ID,
                UserID:    0,
                Username:  "시스템",
                Content:   fmt.Sprintf("%s님이 입장했습니다", client.Username),
                Type:      "system",
                Timestamp: time.Now(),
            }
            room.broadcastMessage(systemMsg)
            
        case client := <-room.Leave:
            if _, ok := room.Participants[client.UserID]; ok {
                delete(room.Participants, client.UserID)
                close(client.Send)
                
                // 시스템 메시지: 참여자 나가기
                systemMsg := &ChatMessage{
                    RoomID:    room.ID,
                    UserID:    0,
                    Username:  "시스템",
                    Content:   fmt.Sprintf("%s님이 나갔습니다", client.Username),
                    Type:      "system",
                    Timestamp: time.Now(),
                }
                room.broadcastMessage(systemMsg)
            }
            
        case message := <-room.Messages:
            // 메시지 저장
            room.saveMessage(message)
            
            // 모든 참여자에게 브로드캐스트
            room.broadcastMessage(message)
        }
    }
}
```

#### Day 2: 채팅방 자동 생성/소멸
```go
// chat_service.go
func (s *ChatService) CreateChatRoom(signalID uint) (*ChatRoom, error) {
    signal, err := s.signalRepo.GetByID(signalID)
    if err != nil {
        return nil, err
    }
    
    roomID := fmt.Sprintf("signal_%d", signalID)
    expiresAt := signal.StartTime.Add(24 * time.Hour)
    
    room := &ChatRoom{
        ID:           roomID,
        SignalID:     signalID,
        Participants: make(map[uint]*ChatClient),
        Messages:     make(chan *ChatMessage, 256),
        Join:         make(chan *ChatClient),
        Leave:        make(chan *ChatClient),
        Created:      time.Now(),
        ExpiresAt:    expiresAt,
    }
    
    // 채팅방 저장
    s.rooms[roomID] = room
    
    // 백그라운드에서 채팅방 실행
    go room.Run()
    
    // 자동 소멸 스케줄링
    go s.scheduleRoomDestruction(roomID, expiresAt)
    
    s.logger.Info(fmt.Sprintf("채팅방 생성: %s, 만료: %v", roomID, expiresAt))
    
    return room, nil
}

func (s *ChatService) scheduleRoomDestruction(roomID string, expiresAt time.Time) {
    duration := time.Until(expiresAt)
    timer := time.NewTimer(duration)
    
    <-timer.C
    
    // 채팅방 소멸
    if room, exists := s.rooms[roomID]; exists {
        // 모든 클라이언트 연결 종료
        for _, client := range room.Participants {
            close(client.Send)
        }
        
        // 채팅방 데이터 삭제
        s.deleteChatRoomData(roomID)
        delete(s.rooms, roomID)
        
        s.logger.Info(fmt.Sprintf("채팅방 자동 소멸: %s", roomID))
    }
}
```

#### Day 3: 메시지 저장 및 히스토리
```go
// chat_repository.go
func (r *ChatRepository) SaveMessage(message *models.ChatMessage) error {
    return r.db.Create(message).Error
}

func (r *ChatRepository) GetRoomMessages(roomID string, limit int, offset int) ([]models.ChatMessage, error) {
    var messages []models.ChatMessage
    
    err := r.db.Where("room_id = ?", roomID).
        Order("created_at ASC").
        Limit(limit).
        Offset(offset).
        Find(&messages).Error
        
    return messages, err
}

// Worker에서 주기적으로 만료된 메시지 정리
func (w *ChatCleanupWorker) CleanupExpiredMessages() error {
    // 24시간 지난 메시지 삭제
    cutoff := time.Now().Add(-24 * time.Hour)
    
    result := w.db.Where("created_at < ?", cutoff).
        Delete(&models.ChatMessage{})
        
    w.logger.Info(fmt.Sprintf("만료 메시지 %d개 삭제됨", result.RowsAffected))
    
    return result.Error
}
```

### 📱 Frontend 작업 (4일)

#### Day 1: WebSocket 클라이언트
```dart
// lib/core/services/websocket_service.dart
class WebSocketService {
  IOWebSocketChannel? _channel;
  StreamController<ChatMessage>? _messageController;
  
  Stream<ChatMessage> connect(String roomId, String token) {
    _messageController = StreamController<ChatMessage>.broadcast();
    
    final uri = Uri.parse('ws://localhost:8080/ws/chat/$roomId');
    _channel = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    
    _channel!.stream.listen(
      (data) {
        final message = ChatMessage.fromJson(json.decode(data));
        _messageController!.add(message);
      },
      onError: (error) {
        _messageController!.addError(error);
      },
      onDone: () {
        _messageController!.close();
      },
    );
    
    return _messageController!.stream;
  }
  
  void sendMessage(String content, String type) {
    if (_channel != null) {
      final message = {
        'content': content,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _channel!.sink.add(json.encode(message));
    }
  }
  
  void disconnect() {
    _channel?.sink.close();
    _messageController?.close();
  }
}
```

#### Day 2: 채팅 UI 컴포넌트
```dart
// lib/features/chat/presentation/pages/chat_page.dart
class ChatPage extends StatefulWidget {
  final String roomId;
  final Signal signal;
  
  const ChatPage({Key? key, required this.roomId, required this.signal}) : super(key: key);
  
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late WebSocketService _wsService;
  late AnimationController _countdownController;
  
  List<ChatMessage> messages = [];
  
  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService();
    _connectToChat();
    _setupCountdownTimer();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildChatAppBar(),
      body: Column(
        children: [
          _buildCountdownHeader(),
          Expanded(child: _buildMessageList()),
          _buildMessageInput(),
        ],
      ),
    );
  }
  
  Widget _buildCountdownHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '모임까지 ${_formatTimeRemaining()}',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          AnimatedBuilder(
            animation: _countdownController,
            builder: (context, child) {
              return CircularProgressIndicator(
                value: _countdownController.value,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message);
      },
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.userId == context.read<AuthBloc>().state.user?.id;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 64 : 0,
          right: isMe ? 0 : 64,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.username,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            SizedBox(height: 2),
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## ⚡ 즉시 착수 작업

### 오늘 할 수 있는 작업 (2-3시간)
1. **PostGIS 지리적 검색 API 구현**
```bash
cd be/internal/handlers
# signal_handler.go에 GetNearbySignals 메서드 추가

cd module/pkg/models  
# signal.go에 Latitude, Longitude 필드와 PostGIS 태그 추가
```

2. **Flutter Google Maps 기본 설정**
```bash
cd ios
flutter pub add google_maps_flutter geolocator permission_handler
# pubspec.yaml 업데이트 후 기본 지도 화면 생성
```

### 이번 주 완료 목표
- [ ] 지도에 실시간 시그널 마커 표시
- [ ] 시그널 생성 기본 플로우 완성
- [ ] 위치 권한 및 GPS 서비스 연동
- [ ] 시그널 상세 보기 및 참여 요청 기능

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"content": "\ud604\uc7ac \uac1c\ubc1c \ud604\ud669 \ubc0f \ub2e4\uc74c \ub2e8\uacc4 \ubd84\uc11d", "status": "completed", "activeForm": "Analyzing current development status and next steps"}, {"content": "\uc0ac\uc6a9\uc790 \uc81c\uc548 \uae30\ub2a5 \ud1b5\ud569\ud55c \uc0c1\uc138 \uae30\ud68d\uc11c \uc791\uc131", "status": "completed", "activeForm": "Writing detailed specification with user suggestions"}, {"content": "\uae30\uc220\uc801 \uad6c\ud604 \ub85c\ub4dc\ub9f5 \uc791\uc131", "status": "completed", "activeForm": "Creating technical implementation roadmap"}, {"content": "\ud504\ub860\ud2b8\uc5d4\ub4dc \uac1c\ubc1c \uc6b0\uc120\uc21c\uc704 \uc815\uc758", "status": "completed", "activeForm": "Defining frontend development priorities"}, {"content": "\ud575\uc2ec \uae30\ub2a5 \uac1c\ubc1c \uc21c\uc11c \uad6c\uccb4\ud654", "status": "completed", "activeForm": "Detailing core feature development sequence"}]