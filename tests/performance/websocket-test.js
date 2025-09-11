import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Counter, Trend } from 'k6/metrics';

// Custom metrics for WebSocket testing
export const wsConnections = new Counter('websocket_connections');
export const wsConnectionsFailed = new Counter('websocket_connections_failed');
export const wsMessagesExchanged = new Counter('websocket_messages_exchanged');
export const wsConnectionDuration = new Trend('websocket_connection_duration');
export const wsMessageRoundTripTime = new Trend('websocket_message_rtt');
export const wsConcurrentConnections = new Trend('websocket_concurrent_connections');

export const options = {
  scenarios: {
    // Scenario 1: Connection stress test
    connection_stress: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '2m', target: 100 },
        { duration: '5m', target: 200 },
        { duration: '2m', target: 300 },
        { duration: '1m', target: 300 },
        { duration: '2m', target: 0 },
      ],
      tags: { test_type: 'connection_stress' },
    },
    
    // Scenario 2: Message throughput test
    message_throughput: {
      executor: 'constant-vus',
      vus: 50,
      duration: '5m',
      tags: { test_type: 'message_throughput' },
    },
    
    // Scenario 3: Long-lived connections
    long_connections: {
      executor: 'constant-vus',
      vus: 20,
      duration: '15m',
      tags: { test_type: 'long_connections' },
    },
  },
  thresholds: {
    'websocket_connections': ['count>1000'],
    'websocket_connections_failed': ['rate<0.01'],
    'websocket_connection_duration': ['p(95)<2000'], // 95% connect within 2s
    'websocket_message_rtt': ['p(95)<200'],          // 95% messages within 200ms
  },
};

const WS_URL = __ENV.WS_URL || 'ws://localhost:8082';
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8081';

// Test data - mock authentication tokens
const TEST_TOKENS = [
  'mock_token_1', 'mock_token_2', 'mock_token_3', 'mock_token_4', 'mock_token_5'
];

export default function() {
  const testType = __ENV.TEST_TYPE || 'connection_stress';
  
  switch (testType) {
    case 'connection_stress':
      testConnectionStress();
      break;
    case 'message_throughput':
      testMessageThroughput();
      break;
    case 'long_connections':
      testLongConnections();
      break;
    default:
      testConnectionStress();
  }
}

function testConnectionStress() {
  const token = TEST_TOKENS[Math.floor(Math.random() * TEST_TOKENS.length)];
  const roomId = Math.floor(Math.random() * 10) + 1; // Simulate 10 different chat rooms
  const url = `${WS_URL}/ws/chat/${roomId}?token=${token}`;
  
  const connectStart = Date.now();
  let connectionDuration = 0;
  let messagesExchanged = 0;
  
  const res = ws.connect(url, null, function(socket) {
    connectionDuration = Date.now() - connectStart;
    wsConnectionDuration.add(connectionDuration);
    wsConnections.add(1);
    
    socket.on('open', function() {
      // Send a few quick messages to test basic functionality
      for (let i = 0; i < 3; i++) {
        setTimeout(() => {
          const message = {
            type: 'text',
            content: `Stress test message ${i}`,
            timestamp: Date.now(),
          };
          socket.send(JSON.stringify(message));
        }, i * 100);
      }
      
      // Close connection after a short time
      setTimeout(() => {
        socket.close();
      }, 2000);
    });
    
    socket.on('message', function(data) {
      messagesExchanged++;
      wsMessagesExchanged.add(1);
    });
    
    socket.on('close', function() {
      // Record metrics
      if (messagesExchanged > 0) {
        wsConcurrentConnections.add(messagesExchanged);
      }
    });
    
    socket.on('error', function(error) {
      wsConnectionsFailed.add(1);
    });
  });
  
  check(res, {
    'websocket connection established': (r) => r && r.status === 101,
  });
  
  sleep(Math.random() * 2 + 1); // Sleep 1-3 seconds
}

function testMessageThroughput() {
  const token = TEST_TOKENS[Math.floor(Math.random() * TEST_TOKENS.length)];
  const roomId = Math.floor(Math.random() * 5) + 1; // Use fewer rooms for more concentrated testing
  const url = `${WS_URL}/ws/chat/${roomId}?token=${token}`;
  
  const res = ws.connect(url, null, function(socket) {
    wsConnections.add(1);
    
    let messagesSent = 0;
    let messagesReceived = 0;
    const messageTimestamps = new Map();
    
    socket.on('open', function() {
      // Send messages rapidly to test throughput
      const messageInterval = setInterval(() => {
        if (messagesSent < 20) { // Send 20 messages per connection
          const timestamp = Date.now();
          const message = {
            type: 'text',
            content: `Throughput test message ${messagesSent}`,
            id: `msg_${messagesSent}_${timestamp}`,
            timestamp: timestamp,
          };
          
          messageTimestamps.set(message.id, timestamp);
          socket.send(JSON.stringify(message));
          messagesSent++;
        } else {
          clearInterval(messageInterval);
          // Close after sending all messages
          setTimeout(() => socket.close(), 1000);
        }
      }, 50); // Send message every 50ms
    });
    
    socket.on('message', function(data) {
      messagesReceived++;
      wsMessagesExchanged.add(1);
      
      try {
        const message = JSON.parse(data);
        if (message.id && messageTimestamps.has(message.id)) {
          const rtt = Date.now() - messageTimestamps.get(message.id);
          wsMessageRoundTripTime.add(rtt);
        }
      } catch (e) {
        // Ignore parsing errors
      }
    });
    
    socket.on('error', function(error) {
      wsConnectionsFailed.add(1);
    });
    
    socket.setTimeout(function() {
      socket.close();
    }, 30000); // 30 second timeout
  });
  
  check(res, {
    'websocket connection established': (r) => r && r.status === 101,
  });
}

function testLongConnections() {
  const token = TEST_TOKENS[Math.floor(Math.random() * TEST_TOKENS.length)];
  const roomId = Math.floor(Math.random() * 3) + 1; // Use even fewer rooms for long connections
  const url = `${WS_URL}/ws/chat/${roomId}?token=${token}`;
  
  const connectStart = Date.now();
  let heartbeatCount = 0;
  
  const res = ws.connect(url, null, function(socket) {
    wsConnections.add(1);
    
    socket.on('open', function() {
      // Send periodic heartbeat messages to keep connection alive
      const heartbeatInterval = setInterval(() => {
        const heartbeat = {
          type: 'ping',
          timestamp: Date.now(),
          sequence: heartbeatCount++,
        };
        socket.send(JSON.stringify(heartbeat));
      }, 30000); // Every 30 seconds
      
      // Send occasional chat messages to simulate real usage
      const chatInterval = setInterval(() => {
        if (Math.random() < 0.1) { // 10% chance every interval
          const message = {
            type: 'text',
            content: `Long connection message ${Date.now()}`,
            timestamp: Date.now(),
          };
          socket.send(JSON.stringify(message));
        }
      }, 5000); // Check every 5 seconds
      
      // Clean up intervals when connection closes
      socket.on('close', function() {
        clearInterval(heartbeatInterval);
        clearInterval(chatInterval);
        
        const connectionTime = Date.now() - connectStart;
        wsConnectionDuration.add(connectionTime);
      });
    });
    
    socket.on('message', function(data) {
      wsMessagesExchanged.add(1);
      
      try {
        const message = JSON.parse(data);
        if (message.type === 'pong' && message.timestamp) {
          const rtt = Date.now() - message.timestamp;
          wsMessageRoundTripTime.add(rtt);
        }
      } catch (e) {
        // Ignore parsing errors
      }
    });
    
    socket.on('error', function(error) {
      wsConnectionsFailed.add(1);
    });
    
    // Keep connection alive for the full test duration
    socket.setTimeout(function() {
      socket.close();
    }, 15 * 60 * 1000); // 15 minutes
  });
  
  check(res, {
    'long websocket connection established': (r) => r && r.status === 101,
  });
  
  // For long connections, sleep longer between iterations
  sleep(10 + Math.random() * 10); // 10-20 seconds
}

// Additional scenario: Burst traffic simulation
export function handleSummary(data) {
  const summary = {
    'test_duration': data.state.testRunDurationMs,
    'total_websocket_connections': data.metrics.websocket_connections?.values?.count || 0,
    'failed_connections': data.metrics.websocket_connections_failed?.values?.count || 0,
    'total_messages_exchanged': data.metrics.websocket_messages_exchanged?.values?.count || 0,
    'avg_connection_time': data.metrics.websocket_connection_duration?.values?.avg || 0,
    'p95_connection_time': data.metrics.websocket_connection_duration?.values['p(95)'] || 0,
    'avg_message_rtt': data.metrics.websocket_message_rtt?.values?.avg || 0,
    'p95_message_rtt': data.metrics.websocket_message_rtt?.values['p(95)'] || 0,
  };
  
  console.log('📊 WebSocket Performance Test Summary:');
  console.log(`   Total Connections: ${summary.total_websocket_connections}`);
  console.log(`   Failed Connections: ${summary.failed_connections}`);
  console.log(`   Messages Exchanged: ${summary.total_messages_exchanged}`);
  console.log(`   Avg Connection Time: ${summary.avg_connection_time.toFixed(2)}ms`);
  console.log(`   95% Connection Time: ${summary.p95_connection_time.toFixed(2)}ms`);
  console.log(`   Avg Message RTT: ${summary.avg_message_rtt.toFixed(2)}ms`);
  console.log(`   95% Message RTT: ${summary.p95_message_rtt.toFixed(2)}ms`);
  
  return {
    'websocket-performance-summary.json': JSON.stringify(summary, null, 2),
  };
}