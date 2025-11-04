import { Hono } from 'hono';
import { cors } from 'hono/cors';

type User = {
  userId: string;
  email: string;
  displayName: string;
  preKeyBundle: any;
  profileImage?: string;
  lastSeen: number;
};

type SignalingMessage = {
  from: string;
  to: string;
  offer?: string;
  answer?: string;
  candidate?: string;
};

const app = new Hono();

const users = new Map<string, User>();
const activeSessions = new Map<string, WebSocket>();
const pendingMessages = new Map<string, SignalingMessage[]>();

app.use('*', cors());

const authenticate = async (c: any, next: any) => {
  const apiKey = c.req.header('X-API-Key');
  const expectedKey = c.env?.API_KEY;
  
  if (!expectedKey) {
    return c.json({ error: 'Server configuration error: API_KEY not set' }, 500);
  }
  
  if (!apiKey || apiKey !== expectedKey) {
    return c.json({ error: 'Unauthorized' }, 401);
  }
  
  await next();
};

app.post('/register', authenticate, async (c) => {
  try {
    const { userId, email, displayName, preKeyBundle, profileImage } = await c.req.json();
    
    if (!userId || !preKeyBundle || !email || !displayName) {
      return c.json({ error: 'Missing required fields' }, 400);
    }

    users.set(userId, {
      userId,
      email,
      displayName,
      preKeyBundle,
      profileImage,
      lastSeen: Date.now(),
    });

    return c.json({ success: true, userId });
  } catch (error) {
    return c.json({ error: 'Registration failed' }, 500);
  }
});

app.get('/lookup/:userId', authenticate, (c) => {
  const userId = c.req.param('userId');
  const user = users.get(userId);

  if (!user) {
    return c.json({ error: 'User not found' }, 404);
  }

  return c.json({
    userId: user.userId,
    email: user.email,
    displayName: user.displayName,
    preKeyBundle: user.preKeyBundle,
    profileImage: user.profileImage,
    lastSeen: user.lastSeen,
  });
});

app.post('/offer', authenticate, async (c) => {
  try {
    const { from, to, offer } = await c.req.json();
    
    if (!from || !to || !offer) {
      return c.json({ error: 'Missing required fields' }, 400);
    }

    const targetSocket = activeSessions.get(to);
    
    if (targetSocket && targetSocket.readyState === WebSocket.OPEN) {
      targetSocket.send(JSON.stringify({ type: 'offer', from, offer }));
    } else {
      if (!pendingMessages.has(to)) {
        pendingMessages.set(to, []);
      }
      pendingMessages.get(to)!.push({ from, to, offer });
    }

    return c.json({ success: true });
  } catch (error) {
    return c.json({ error: 'Failed to send offer' }, 500);
  }
});

app.post('/answer', authenticate, async (c) => {
  try {
    const { from, to, answer } = await c.req.json();
    
    if (!from || !to || !answer) {
      return c.json({ error: 'Missing required fields' }, 400);
    }

    const targetSocket = activeSessions.get(to);
    
    if (targetSocket && targetSocket.readyState === WebSocket.OPEN) {
      targetSocket.send(JSON.stringify({ type: 'answer', from, answer }));
    } else {
      if (!pendingMessages.has(to)) {
        pendingMessages.set(to, []);
      }
      pendingMessages.get(to)!.push({ from, to, answer });
    }

    return c.json({ success: true });
  } catch (error) {
    return c.json({ error: 'Failed to send answer' }, 500);
  }
});

app.post('/ice', authenticate, async (c) => {
  try {
    const { from, to, candidate } = await c.req.json();
    
    if (!from || !to || !candidate) {
      return c.json({ error: 'Missing required fields' }, 400);
    }

    const targetSocket = activeSessions.get(to);
    
    if (targetSocket && targetSocket.readyState === WebSocket.OPEN) {
      targetSocket.send(JSON.stringify({ type: 'ice', from, candidate }));
    }

    return c.json({ success: true });
  } catch (error) {
    return c.json({ error: 'Failed to send ICE candidate' }, 500);
  }
});

app.get('/presence/:userId', (c) => {
  const userId = c.req.param('userId');
  const isOnline = activeSessions.has(userId);
  const user = users.get(userId);

  return c.json({
    online: isOnline,
    lastSeen: user?.lastSeen || null,
  });
});

app.get('/ws', (c) => {
  const upgradeHeader = c.req.header('Upgrade');
  
  if (upgradeHeader !== 'websocket') {
    return c.text('Expected websocket', 426);
  }

  const userId = c.req.query('userId');
  
  if (!userId) {
    return c.text('Missing userId', 400);
  }

  const pair = new WebSocketPair();
  const [client, server] = Object.values(pair);

  server.accept();
  activeSessions.set(userId, server);

  const pending = pendingMessages.get(userId) || [];
  for (const msg of pending) {
    server.send(JSON.stringify(msg));
  }
  pendingMessages.delete(userId);

  server.addEventListener('close', () => {
    activeSessions.delete(userId);
    const user = users.get(userId);
    if (user) {
      user.lastSeen = Date.now();
    }
  });

  server.addEventListener('error', () => {
    activeSessions.delete(userId);
  });

  return new Response(null, {
    status: 101,
    webSocket: client,
  });
});

export default {
  fetch: app.fetch,
};
