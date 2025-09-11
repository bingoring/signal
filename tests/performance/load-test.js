import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep, group } from 'k6';
import { Rate, Counter, Trend } from 'k6/metrics';

// Custom metrics
export const errorRate = new Rate('errors');
export const messagesSent = new Counter('websocket_messages_sent');
export const messagesReceived = new Counter('websocket_messages_received');
export const wsConnectTime = new Trend('websocket_connect_time');
export const wsMessageLatency = new Trend('websocket_message_latency');

// Test configuration
export const options = {
  stages: [
    { duration: '5m', target: 100 },   // Ramp up to 100 users over 5 minutes
    { duration: '10m', target: 100 },  // Stay at 100 users for 10 minutes
    { duration: '3m', target: 300 },   // Spike to 300 users over 3 minutes
    { duration: '2m', target: 300 },   // Stay at 300 users for 2 minutes
    { duration: '5m', target: 0 },     // Ramp down to 0 users over 5 minutes
  ],
  thresholds: {
    'http_req_duration': ['p(95)<300'], // 95% of HTTP requests must complete within 300ms
    'http_req_failed': ['rate<0.01'],   // Error rate must be less than 1%
    'websocket_connect_time': ['p(95)<1000'], // 95% of WS connections within 1s
    'websocket_message_latency': ['p(95)<100'], // 95% of messages within 100ms
    'errors': ['rate<0.01'],            // Overall error rate less than 1%
  },
};

// Environment configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8081';
const WS_URL = __ENV.WS_URL || 'ws://localhost:8082';

// Test data
const testUsers = [];
const testSignals = [];

export function setup() {
  console.log('🚀 Setting up performance test...');
  
  // Create test users for the load test
  const users = [];
  for (let i = 0; i < 50; i++) {
    const userData = {
      email: `loadtest-user-${i}-${Date.now()}@signal.com`,
      name: `Load Test User ${i}`,
      latitude: 37.4981 + (Math.random() - 0.5) * 0.01,
      longitude: 127.0276 + (Math.random() - 0.5) * 0.01,
    };
    
    const response = http.post(`${BASE_URL}/auth/register`, JSON.stringify(userData), {
      headers: { 'Content-Type': 'application/json' },
    });
    
    if (response.status === 200) {
      const authData = JSON.parse(response.body);
      users.push({
        id: authData.user.id,
        email: userData.email,
        name: userData.name,
        token: authData.token,
        latitude: userData.latitude,
        longitude: userData.longitude,
      });
    }
  }
  
  // Create test signals
  const signals = [];
  const categories = ['맛집', '운동', '스터디', '여행', '취미'];
  
  for (let i = 0; i < 20; i++) {
    if (users[i]) {
      const signalData = {
        title: `Load Test Signal ${i}`,
        description: `Performance test signal created by user ${i}`,
        category: categories[i % categories.length],
        latitude: users[i].latitude,
        longitude: users[i].longitude,
        max_count: Math.floor(Math.random() * 10) + 5,
        meet_time: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(), // 2 hours from now
      };
      
      const response = http.post(`${BASE_URL}/signals`, JSON.stringify(signalData), {
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${users[i].token}`
        },
      });
      
      if (response.status === 201) {
        const signal = JSON.parse(response.body);
        signals.push({
          ...signal,
          creator_token: users[i].token,
        });
      }
    }
  }
  
  console.log(`✅ Setup complete: ${users.length} users, ${signals.length} signals`);
  
  return { users, signals };
}

export default function(data) {
  const { users, signals } = data;
  
  // Select random user for this VU iteration
  const user = users[Math.floor(Math.random() * users.length)];
  if (!user) {
    errorRate.add(1);
    return;
  }
  
  group('API Load Tests', function() {
    // Test 1: Health check
    group('Health Check', function() {
      const response = http.get(`${BASE_URL}/health`);
      check(response, {
        'health check status is 200': (r) => r.status === 200,
        'health check response time < 100ms': (r) => r.timings.duration < 100,
      }) || errorRate.add(1);
    });
    
    // Test 2: User authentication
    group('User Authentication', function() {
      const response = http.get(`${BASE_URL}/users/profile`, {
        headers: { 'Authorization': `Bearer ${user.token}` },
      });
      check(response, {
        'profile fetch status is 200': (r) => r.status === 200,
        'profile contains user data': (r) => JSON.parse(r.body).email === user.email,
      }) || errorRate.add(1);
    });
    
    // Test 3: Signal search
    group('Signal Search', function() {
      const searchParams = `lat=${user.latitude}&lng=${user.longitude}&radius=5000`;
      const response = http.get(`${BASE_URL}/signals/search?${searchParams}`, {
        headers: { 'Authorization': `Bearer ${user.token}` },
      });
      check(response, {
        'search status is 200': (r) => r.status === 200,
        'search response is array': (r) => Array.isArray(JSON.parse(r.body)),
        'search response time < 200ms': (r) => r.timings.duration < 200,
      }) || errorRate.add(1);
    });
    
    // Test 4: Signal participation (randomly)
    if (Math.random() < 0.3 && signals.length > 0) {
      group('Signal Participation', function() {
        const randomSignal = signals[Math.floor(Math.random() * signals.length)];
        const response = http.post(`${BASE_URL}/signals/${randomSignal.id}/join`, null, {
          headers: { 'Authorization': `Bearer ${user.token}` },
        });
        check(response, {
          'join request processed': (r) => r.status === 200 || r.status === 409, // 409 for already joined
        }) || errorRate.add(1);
      });
    }
  });
  
  // Test 5: WebSocket chat simulation (25% of users)
  if (Math.random() < 0.25) {
    group('WebSocket Chat Test', function() {
      testWebSocketChat(user, signals);
    });
  }
  
  sleep(Math.random() * 3 + 1); // Sleep between 1-4 seconds
}

function testWebSocketChat(user, signals) {
  // Find a signal with chat room
  let chatRoom = null;
  for (const signal of signals.slice(0, 5)) { // Check first 5 signals only for performance
    const response = http.get(`${BASE_URL}/chat/rooms?signal_id=${signal.id}`, {
      headers: { 'Authorization': `Bearer ${user.token}` },
    });
    
    if (response.status === 200) {
      chatRoom = JSON.parse(response.body);
      break;
    }
  }
  
  if (!chatRoom) {
    // Create a test chat room
    const testSignal = signals[0];
    if (!testSignal) return;
    
    const response = http.post(`${BASE_URL}/signals/${testSignal.id}/join`, null, {
      headers: { 'Authorization': `Bearer ${user.token}` },
    });
    
    if (response.status === 200) {
      // Wait a bit for chat room creation
      sleep(1);
      
      const roomResponse = http.get(`${BASE_URL}/chat/rooms?signal_id=${testSignal.id}`, {
        headers: { 'Authorization': `Bearer ${user.token}` },
      });
      
      if (roomResponse.status === 200) {
        chatRoom = JSON.parse(roomResponse.body);
      }
    }
  }
  
  if (!chatRoom) return;
  
  // WebSocket chat simulation
  const wsUrl = `${WS_URL}/ws/chat/${chatRoom.id}?token=${user.token}`;
  const connectStart = Date.now();
  
  const res = ws.connect(wsUrl, null, function(socket) {
    const connectTime = Date.now() - connectStart;
    wsConnectTime.add(connectTime);
    
    socket.on('open', function() {
      console.log(`WebSocket connected for user ${user.email}`);
      
      // Send test messages
      const messages = [
        { type: 'text', content: '안녕하세요!' },
        { type: 'text', content: '잘 부탁드립니다.' },
        { 
          type: 'location', 
          content: '현재 위치입니다.',
          location: {
            latitude: user.latitude,
            longitude: user.longitude
          }
        },
        { type: 'quick_reply', content: '도착했어요' },
      ];
      
      messages.forEach((msg, index) => {
        setTimeout(() => {
          const sendTime = Date.now();
          socket.send(JSON.stringify({
            ...msg,
            timestamp: sendTime,
          }));
          messagesSent.add(1);
        }, index * 1000); // Send messages 1 second apart
      });
      
      // Close connection after 5 seconds
      setTimeout(() => {
        socket.close();
      }, 5000);
    });
    
    socket.on('message', function(data) {
      const message = JSON.parse(data);
      messagesReceived.add(1);
      
      // Calculate message latency if timestamp is present
      if (message.timestamp) {
        const latency = Date.now() - message.timestamp;
        wsMessageLatency.add(latency);
      }
    });
    
    socket.on('error', function(error) {
      console.error(`WebSocket error for user ${user.email}:`, error);
      errorRate.add(1);
    });
    
    socket.setTimeout(function() {
      socket.close();
    }, 10000); // 10 second timeout
  });
  
  check(res, {
    'websocket connection successful': (r) => r && r.status === 101,
  }) || errorRate.add(1);
}

export function teardown(data) {
  console.log('🧹 Cleaning up performance test data...');
  
  const { users, signals } = data;
  
  // Clean up test signals
  signals.forEach(signal => {
    http.del(`${BASE_URL}/admin/signals/${signal.id}`, null, {
      headers: { 'Authorization': `Bearer ${signal.creator_token}` },
    });
  });
  
  // Clean up test users
  users.forEach(user => {
    http.del(`${BASE_URL}/admin/users/${user.id}`, null, {
      headers: { 'Authorization': `Bearer ${user.token}` },
    });
  });
  
  console.log('✅ Teardown complete');
}