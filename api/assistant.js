Warning: truncated output (original token count: 3253)
Total output lines: 208

const MODEL = 'gemini-3.5-flash-lite';
const recentRequests = new Map();
const allowedActions = new Set([
  'navigate', 'read_screen', 'create_note', 'create_task', 'visitor_checkin',
  'visitor_checkout', 'create_call', 'create_appointment', 'create_enquiry',
  'create_document', 'create_email', 'find_learner', 'complete_task', 'answer', 'clarify',
  'edit_record', 'delete_record',
]);
const recordTypes = new Set([
  'note', 'task', 'appointment', 'call', 'enquiry', 'document', 'email', 'visitor',
]);
const editableFields = {
  note: ['title', 'body'],
  task: ['title', 'detail'],
  appointment: ['title', 'name', 'dateTime', 'location', 'detail'],
  call: ['name', 'phone', 'detail', 'callback', 'priority'],
  enquiry: ['name', 'category', 'detail', 'status', 'priority'],
  document: ['title', 'detail'],
  email: ['recipient', 'subject', 'body'],
  visitor: ['name', 'host', 'purpose'],
};
const screens = new Set([
  'Home', 'Calendar', 'Call log', 'Enquiries', 'Notes', 'Documents',
  'Learners', 'Knowledge', 'AI copilot', 'Visitors', 'Tasks', 'Emails',
]);

module.exports = async function handler(req, res) {
  const origin = req.headers.origin;
  const localOrigin = typeof origin === 'string' && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  if (origin && origin !== 'https://campuscare-reception-demo.vercel.app' && !localOrigin) {
    return res.status(403).json({ error: 'This Liyabona assistant endpoint only accepts requests from the app.' });
  }
  res.setHeader('Access-Control-Allow-Origin', origin || 'https://campuscare-reception-demo.vercel.app');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST.' });

  const ip = (req.headers['x-forwarded-for'] || 'unknown').toString().split(',')[0];
  const now = Date.now();
  const windowStart = now - 60_000;
  const recent = (recentRequests.get(ip) || []).filter((stamp) => stamp > windowStart);
  if (recent.length >= 15) return res.status(429).json({ error: 'Please wait a minute before asking again.' });
  recent.push(now);
  recentRequests.set(ip, recent);
  if (recentRequests.size > 5000) {
    for (const [key, stamps] of recentRequests) {
      if (!stamps.some((stamp) => stamp > windowStart)) recentRequests.delete(key);
    }
  }

  const prompt = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
  const audio = typeof req.body?.audio === 'string' ? req.body.audio : '';
  const yesNoConfirmation = req.body?.yesNoConfirmation === true;
  if (prompt.length > 600) return res.status(400).json({ error: 'Please send a request of up to 600 characters.' });
  if (audio && (audio.length > 1_300_000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(audio))) {
    return res.status(400).json({ error: 'The voice clip is empty or too long. Please try again.' });
  }
  if (!prompt && !audio) return res.status(400).json({ error: 'Please send a voice clip or a text request.' });

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return res.status(503).json({ error: 'Google Gemini is not configured for this service yet.' });

  const history = Array.isArray(req.body?.history) ? req.body.history.slice(-6).map((item) => ({
    role: item?.role === 'assistant' ? 'assistant' : 'user',
    content: typeof item?.content === 'string' ? item.content.slice(0, 500) : '',
  })).filter((item) => item.content) : [];
  const context = {
    screen: screens.has(req.body?.screen) ? req.body.screen : 'Home',
    summary: typeof req.body?.summary === 'string' ? req.body.summary.slice(0, 1200) : '',
    knowledge: typeof req.body?.knowledge === 'string' ? req.body.knowledge.slice(0, 5000) : '',
    records: Array.isArray(req.body?.records)
      ? req.body.records.slice(0, 80).map((record) => {
          if (!record || typeof record !== 'object' || Array.isArray(record)) return {};
          return Object.fromEntries(Object.entries(record)
            .filter(([key, value]) => typeof key === 'string' && typeof value === 'string')
            .map(([key, value]) => [key.slice(0, 24), value.slice(0, 300)]));
        })
      : [],
    localTime: new Date().toLocaleString('en-ZA', { timeZone: 'Africa/Johannesburg' }),
  };

  const transcriptionInstructions = yesNoConfirmation
    ? 'The user is answering a yes/no question. This is a very short spoken answer. Transcribe only what is clearly spoken; recognize South African English and common local answers: yes, yeah, yep, ja, yebo, no, nope, nah, nee. Do not turn silence, noise, or an uncertain word into yes or no. Set confidence based on the audio.'
    : 'Transcribe audio exactly in South African English (en-ZA); do not infer words from noise.';
  const system = `You are Liyabona, a friendly and careful assistant for TVET Student Support reception. Use clear, spoken-friendly English. Available screens: ${[...screens].join(', ')}. Return only JSON keys reply, action, destination, fields, needs_clarification, transcript and confidence. Allowed action: ${[...allowedActions].join(', ')}. ${transcriptionInstructions} If transcript is empty or confidence is below ${yesNoConfirmation ? '0.4' : '0.72'}, return clarify and no action fields. Use navigate to open a screen immediately; use read_screen only to read the current screen. Create actions: create_note(title,body), create_task(title,detail), visitor_checkin(name,host,purpose), visitor_checkout(name), create_call(name,phone,detail), create_appointment(name,title,dateTime,location,detail), create_enquiry(name,category,detail), create_document(title,detail), create_email(recipient,subject,body) for a draft only, find_learner(name), complete_task(title). For edit_record and delete_record, record_type must be one of ${[...recordTypes].join(', ')} and query must exactly identify one existing record fro…253 tokens truncated….content }],
    })),
    {
      role: 'user',
      parts: audio
        ? [
            { text: `This is a spoken ${yesNoConfirmation ? 'yes-or-no answer' : 'request'}. ${yesNoConfirmation ? 'Return the clearly heard answer in transcript and do not reinterpret it as another command.' : 'Transcribe it exactly and interpret it as a Liyabona app request.'} Current typed request: ${prompt || '(none)'}` },
            { inline_data: { mime_type: 'audio/wav', data: audio } },
          ]
        : [{ text: prompt }],
    },
  ];

  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
      method: 'POST',
      headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents,
        generationConfig: {
          temperature: audio ? 0 : 0.2,
          maxOutputTokens: 450,
          responseMimeType: 'application/json',
        },
      }),
      signal: AbortSignal.timeout(20_000),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const providerCode = payload?.error?.status || `http_${response.status}`;
      console.error('Google Gemini request failed', response.status, String(providerCode).slice(0, 80));
      const message = response.status === 401 || response.status === 403
        ? 'Google Gemini rejected the API key. Check the key and API access settings.'
        : response.status === 429
        ? 'Google Gemini has reached its free usage limit. Please try again later.'
        : 'Google Gemini could not answer right now.';
      return res.status(502).json({ error: message, providerCode });
    }
    const content = payload.candidates?.[0]?.content?.parts
      ?.map((part) => typeof part.text === 'string' ? part.text : '')
      .join('')
      .trim();
    if (!content) throw new Error('Google Gemini returned no text');
    const result = JSON.parse(content);
    let action = allowedActions.has(result?.action) ? result.action : 'clarify';
    const destination = screens.has(result?.destination) ? result.destination : '';
    const fields = result?.fields && typeof result.fields === 'object' && !Array.isArray(result.fields)
      ? Object.fromEntries(Object.entries(result.fields).filter(([, value]) => typeof value === 'string').map(([key, value]) => [key, value.slice(0, 600)]))
      : {};
    const confidence = Number(result?.confidence);
    let transcript = typeof result?.transcript === 'string'
      ? result.transcript.trim().slice(0, 600)
      : '';
    let reply = typeof result?.reply === 'string' ? result.reply.slice(0, 900) : 'I am ready to help. What would you like me to do?';
    const confidenceFloor = yesNoConfirmation ? 0.4 : 0.72;
    if (audio && (!transcript || !Number.isFinite(confidence) || confidence < confidenceFloor)) {
      action = 'clarify';
      transcript = '';
      reply = 'I did not hear that clearly. Please say it again.';
      for (const key of Object.keys(fields)) delete fields[key];
    }
    const requiredFields = {
      create_note: ['body'], create_task: ['title'], visitor_checkin: ['name'],
      visitor_checkout: ['name'], create_call: ['name', 'detail'],
      create_appointment: ['name', 'title', 'dateTime'], create_enquiry: ['detail'],
      create_document: ['title', 'detail'], create_email: ['recipient', 'subject', 'body'], find_learner: ['name'], complete_task: ['title'],
      edit_record: ['record_type', 'query'], delete_record: ['record_type', 'query'],
    };
    const missing = (requiredFields[action] || []).filter((key) => !fields[key]?.trim());
    if (missing.length) {
      action = 'clarify';
      reply = `I need a little more information before I can do that. Please tell me ${missing.join(' and ')}.`;
    }
    if (action === 'create_appointment' && !Number.isFinite(Date.parse(fields.dateTime || ''))) {
      action = 'clarify';
      reply = 'What date and time should I put on the appointment?';
    }
    if (action === 'edit_record' || action === 'delete_record') {
      const recordType = fields.record_type?.toLowerCase().trim();
      const query = fields.query?.trim().toLowerCase();
      const matches = context.records.filter((record) =>
        record.type?.toLowerCase() === recordType &&
        Object.entries(record).some(([key, value]) =>
          key !== 'type' && key !== 'checkedOut' && value.trim().toLowerCase() === query));
      if (!recordTypes.has(recordType) || matches.length !== 1) {
        action = 'clarify';
        reply = matches.length > 1
          ? 'I found more than one matching record. Please give me its exact title or name.'
          : 'I could not identify one exact record to change. Please give me its exact title or name.';
        for (const key of Object.keys(fields)) delete fields[key];
      } else if (action === 'edit_record') {
        const editable = editableFields[recordType];
        for (const key of Object.keys(fields)) {
          if (key !== 'record_type' && key !== 'query' && !editable.includes(key)) delete fields[key];
        }
        const changedFields = Object.keys(fields).filter((key) => key !== 'record_type' && key !== 'query');
        if (changedFields.length === 0) {
          action = 'clarify';
          reply = 'What would you like me to change in that record?';
          for (const key of Object.keys(fields)) delete fields[key];
        }
      }
    }
    return res.status(200).json({
      reply,
      action,
      destination,
      fields,
      needs_clarification: result?.needs_clarification === true || action === 'clarify',
      transcript,
      confidence: Number.isFinite(confidence) ? confidence : 0,
    });
  } catch (error) {
    console.error('Liyabona AI request failed', error?.name || 'UnknownError');
    return res.status(502).json({ error: 'I could not reach the AI service. Please try again.' });
  }
};
