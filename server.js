const express = require('express');
const fetch = require('node-fetch');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

const OREF_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Referer': 'https://www.oref.org.il/',
  'X-Requested-With': 'XMLHttpRequest',
  'Accept': 'application/json, text/plain, */*',
  'Accept-Language': 'he-IL,he;q=0.9,en-US;q=0.8,en;q=0.7',
};

app.use(express.static(path.join(__dirname, 'public')));

// Current active alerts
app.get('/api/alerts', async (req, res) => {
  try {
    const response = await fetch('https://www.oref.org.il/WarningMessages/alert/alerts.json', {
      headers: OREF_HEADERS,
    });

    if (response.status === 204 || response.headers.get('content-length') === '0') {
      return res.json(null);
    }

    const text = await response.text();
    if (!text || !text.trim()) {
      return res.json(null);
    }

    // OREF sometimes returns with BOM, strip it
    const cleaned = text.replace(/^\uFEFF/, '').trim();
    const data = JSON.parse(cleaned);
    res.json(data);
  } catch (err) {
    // No active alert = empty/invalid response from OREF
    res.json(null);
  }
});

// Alert history (last 24h)
app.get('/api/history', async (req, res) => {
  try {
    const response = await fetch('https://www.oref.org.il/WarningMessages/History/AlertsHistory.json', {
      headers: OREF_HEADERS,
    });

    const text = await response.text();
    if (!text || !text.trim()) {
      return res.json([]);
    }

    const cleaned = text.replace(/^\uFEFF/, '').trim();
    const data = JSON.parse(cleaned);
    res.json(Array.isArray(data) ? data : []);
  } catch (err) {
    res.json([]);
  }
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});
