# FunChat Signaling Server API Documentation

## Overview

The FunChat signaling server is a lightweight Cloudflare Worker built with HonoJS. It handles user registration, peer discovery, and WebRTC signaling (offer/answer/ICE exchange) for both direct messaging and group chat communications. All data transmitted through the signaling server is secured with API key authentication, and end-to-end encryption is handled client-side using Signal Protocol.

**Base URL**: `http://localhost:8787` (development)  
**Production**: `https://your-worker.workers.dev`

## Authentication

API key authentication is required for all endpoints. The API key must be provided in the `Authorization` header as `Bearer <api_key>`. Keys are configured via environment variables and validated on each request.

## Endpoints

### 1. Register User

Register a new user with their identity and pre-key bundle.

**Endpoint**: `POST /register`

**Request Body**:
```json
{
  "userId": "user@example.com",
  "preKeyBundle": {
    "identityKey": "base64_encoded_public_key",
    "registrationId": 12345,
    "preKeys": [
      {
        "id": 1,
        "publicKey": "base64_encoded_prekey"
      }
    ],
    "signedPreKey": {
      "id": 1,
      "publicKey": "base64_encoded_signed_prekey",
      "signature": "base64_encoded_signature"
    }
  }
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "userId": "user@example.com"
}
```

**Error Response** (400 Bad Request):
```json
{
  "error": "Missing userId or preKeyBundle"
}
```

**Example**:
```bash
curl -X POST http://localhost:8787/register \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "alice@example.com",
    "preKeyBundle": {...}
  }'
```

---

### 2. Lookup User

Retrieve a user's public identity and pre-key bundle.

**Endpoint**: `GET /lookup/:userId`

**Parameters**:
- `userId` (path) - User identifier

**Response** (200 OK):
```json
{
  "userId": "user@example.com",
  "preKeyBundle": {
    "identityKey": "base64_encoded_public_key",
    "registrationId": 12345,
    "preKeys": [...],
    "signedPreKey": {...}
  },
  "lastSeen": 1234567890000
}
```

**Error Response** (404 Not Found):
```json
{
  "error": "User not found"
}
```

**Example**:
```bash
curl http://localhost:8787/lookup/alice@example.com
```

---

### 3. Send Offer

Send a WebRTC offer to another user.

**Endpoint**: `POST /offer`

**Request Body**:
```json
{
  "from": "alice@example.com",
  "to": "bob@example.com",
  "offer": "{\"type\":\"offer\",\"sdp\":\"...\"}"
}
```

**Response** (200 OK):
```json
{
  "success": true
}
```

**Error Response** (400 Bad Request):
```json
{
  "error": "Missing required fields"
}
```

**Behavior**:
- If recipient is online (WebSocket connected), offer is sent immediately
- If recipient is offline, offer is queued and delivered when they connect

**Example**:
```bash
curl -X POST http://localhost:8787/offer \
  -H "Content-Type: application/json" \
  -d '{
    "from": "alice@example.com",
    "to": "bob@example.com",
    "offer": "{...}"
  }'
```

---

### 4. Send Answer

Send a WebRTC answer in response to an offer.

**Endpoint**: `POST /answer`

**Request Body**:
```json
{
  "from": "bob@example.com",
  "to": "alice@example.com",
  "answer": "{\"type\":\"answer\",\"sdp\":\"...\"}"
}
```

**Response** (200 OK):
```json
{
  "success": true
}
```

**Error Response** (400 Bad Request):
```json
{
  "error": "Missing required fields"
}
```

**Example**:
```bash
curl -X POST http://localhost:8787/answer \
  -H "Content-Type: application/json" \
  -d '{
    "from": "bob@example.com",
    "to": "alice@example.com",
    "answer": "{...}"
  }'
```

---

### 5. Send ICE Candidate

Exchange ICE candidates for NAT traversal.

**Endpoint**: `POST /ice`

**Request Body**:
```json
{
  "from": "alice@example.com",
  "to": "bob@example.com",
  "candidate": "{\"candidate\":\"...\",\"sdpMid\":\"...\",\"sdpMLineIndex\":0}"
}
```

**Response** (200 OK):
```json
{
  "success": true
}
```

**Error Response** (400 Bad Request):
```json
{
  "error": "Missing required fields"
}
```

**Note**: ICE candidates are only sent to online users. Offline users will renegotiate ICE when they reconnect.

**Example**:
```bash
curl -X POST http://localhost:8787/ice \
  -H "Content-Type: application/json" \
  -d '{
    "from": "alice@example.com",
    "to": "bob@example.com",
    "candidate": "{...}"
  }'
```

---

### 6. Check Presence

Check if a user is currently online.

**Endpoint**: `GET /presence/:userId`

**Parameters**:
- `userId` (path) - User identifier

**Response** (200 OK):
```json
{
  "online": true,
  "lastSeen": 1234567890000
}
```

**Example**:
```bash
curl http://localhost:8787/presence/alice@example.com
```

---

### 7. WebSocket Connection

Establish a persistent WebSocket connection for real-time signaling.

**Endpoint**: `GET /ws?userId=<userId>`

**Parameters**:
- `userId` (query) - User identifier

**Connection**:
```javascript
const ws = new WebSocket('ws://localhost:8787/ws?userId=alice@example.com');

ws.onopen = () => {
  console.log('Connected to signaling server');
};

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  // Handle offer, answer, or ICE candidate
};
```

**Message Types**:

#### Incoming Offer
```json
{
  "type": "offer",
  "from": "bob@example.com",
  "offer": "{...}"
}
```

#### Incoming Answer
```json
{
  "type": "answer",
  "from": "alice@example.com",
  "answer": "{...}"
}
```

#### Incoming ICE Candidate
```json
{
  "type": "ice",
  "from": "bob@example.com",
  "candidate": "{...}"
}
```

**Behavior**:
- On connection, any pending messages are immediately sent
- Connection is maintained until client disconnects
- On disconnect, user's `lastSeen` is updated

---

## Group Chat Support

Group chat is fully supported through multiple P2P WebRTC connections. Each group member establishes individual signaling connections for secure, end-to-end encrypted communication. Group management (creation, member addition/removal) is handled client-side with handshake tracking for encryption setup.

All group messages, files, images, videos, and documents are encrypted using Signal Protocol (X3DH + Double Ratchet) before transmission. Emoji support is built-in with native keyboard integration, providing a WhatsApp-like experience.

The signaling server facilitates the initial handshake and presence detection for all group members, ensuring reliable message delivery even when some members are offline. Messages are queued locally when recipients are unavailable and delivered upon reconnection.

---

## Data Models

### User
```typescript
{
  userId: string;
  preKeyBundle: PreKeyBundle;
  lastSeen: number;
}
```

### PreKeyBundle
```typescript
{
  identityKey: string;        // Base64 encoded
  registrationId: number;
  preKeys: PreKey[];
  signedPreKey: SignedPreKey;
}
```

### PreKey
```typescript
{
  id: number;
  publicKey: string;  // Base64 encoded
}
```

### SignedPreKey
```typescript
{
  id: number;
  publicKey: string;   // Base64 encoded
  signature: string;   // Base64 encoded
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad Request - Missing or invalid parameters |
| 404 | Not Found - User does not exist |
| 426 | Upgrade Required - WebSocket upgrade failed |
| 500 | Internal Server Error |

---

## Rate Limiting

Currently no rate limiting. In production, implement:
- Per-IP rate limiting
- Per-user rate limiting
- WebSocket connection limits

---

## Security Considerations

### Current Implementation
- API key authentication required for all endpoints
- End-to-end encryption using Signal Protocol (X3DH + Double Ratchet) for all messages, files, images, videos, and documents
- Message validation through cryptographic signatures
- No rate limiting (recommended for production)

### Production Recommendations
1. **Use WSS** (WebSocket Secure)
2. **Implement JWT authentication** (optional enhancement)
3. **Add rate limiting**
4. **Validate all inputs**
5. **Add CORS restrictions**
6. **Monitor for abuse**
7. **Implement user quotas**

---

## Deployment

### Development
```bash
cd backend
bun run dev
```

### Production (Cloudflare Workers)
```bash
# Login
wrangler login

# Deploy
bun run deploy

# View logs
wrangler tail
```

---

## Monitoring

### Metrics to Track
- Active WebSocket connections
- Messages per second
- Error rates
- User registrations
- Average connection duration

### Logging
```typescript
// Add to index.ts
console.log(`[${new Date().toISOString()}] ${message}`);
```

---

## Testing

### Manual Testing

#### Register User
```bash
curl -X POST http://localhost:8787/register \
  -H "Content-Type: application/json" \
  -d '{"userId":"test@example.com","preKeyBundle":{...}}'
```

#### Lookup User
```bash
curl http://localhost:8787/lookup/test@example.com
```

#### Check Presence
```bash
curl http://localhost:8787/presence/test@example.com
```

### Automated Testing
```bash
# Add to package.json
"scripts": {
  "test": "bun test"
}

# Create test file
# backend/test/api.test.ts
```

---

## WebSocket Flow Example

### Alice wants to call Bob

1. **Alice connects**:
```javascript
const ws = new WebSocket('ws://localhost:8787/ws?userId=alice@example.com');
```

2. **Alice creates offer**:
```javascript
const offer = await peerConnection.createOffer();
await peerConnection.setLocalDescription(offer);

// Send via HTTP
fetch('http://localhost:8787/offer', {
  method: 'POST',
  body: JSON.stringify({
    from: 'alice@example.com',
    to: 'bob@example.com',
    offer: JSON.stringify(offer)
  })
});
```

3. **Bob receives offer** (via WebSocket):
```javascript
ws.onmessage = async (event) => {
  const { type, from, offer } = JSON.parse(event.data);
  if (type === 'offer') {
    await peerConnection.setRemoteDescription(JSON.parse(offer));
    const answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    
    // Send answer
    fetch('http://localhost:8787/answer', {
      method: 'POST',
      body: JSON.stringify({
        from: 'bob@example.com',
        to: from,
        answer: JSON.stringify(answer)
      })
    });
  }
};
```

4. **Alice receives answer** (via WebSocket):
```javascript
ws.onmessage = async (event) => {
  const { type, answer } = JSON.parse(event.data);
  if (type === 'answer') {
    await peerConnection.setRemoteDescription(JSON.parse(answer));
  }
};
```

5. **ICE candidates exchanged**:
```javascript
peerConnection.onicecandidate = (event) => {
  if (event.candidate) {
    fetch('http://localhost:8787/ice', {
      method: 'POST',
      body: JSON.stringify({
        from: 'alice@example.com',
        to: 'bob@example.com',
        candidate: JSON.stringify(event.candidate)
      })
    });
  }
};
```

---

## Troubleshooting

### WebSocket won't connect
- Check if server is running: `curl http://localhost:8787`
- Verify userId parameter is provided
- Check browser console for errors

### Messages not delivered
- Verify recipient is online: `GET /presence/:userId`
- Check WebSocket connection state
- Review server logs

### High latency
- Check network conditions
- Verify server location
- Consider using Cloudflare's edge network

---


## Support

- GitHub Issues: [Report bugs](https://github.com/muhammad-fiaz/funchat/issues)
- Email: contact@muhammadfiaz.com
- Documentation: [Main README](../README.md)

---

**Version**: 1.0.0  
**Last Updated**: 2025  
**Maintainer**: muhammad-fiaz
