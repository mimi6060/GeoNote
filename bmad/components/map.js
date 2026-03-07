/**
 * GeoNote - Carte interactive Leaflet
 * Code JS minimal pour le MVP
 */

// ============================================
// CONFIGURATION
// ============================================
const GEONOTE_CONFIG = {
  map: {
    defaultCenter: [48.8566, 2.3522], // Paris
    defaultZoom: 14,
    tileUrl: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap contributors',
  },
  api: {
    baseUrl: '/api', // Adapter selon backend BMAD
    endpoints: {
      messages: '/messages',
      nearby: '/messages/nearby',
      interactions: '/interactions',
    },
  },
  defaults: {
    radius: 500,
    maxMessages: 50,
  },
  colors: {
    primary: '#FF6B35',
    marker: '#FF6B35',
    userLocation: '#4A90D9',
  },
};

// ============================================
// INITIALISATION CARTE
// ============================================
let map;
let markersLayer;
let userMarker;
let currentPosition = null;
let currentRadius = GEONOTE_CONFIG.defaults.radius;

function initMap() {
  map = L.map('map-container', {
    center: GEONOTE_CONFIG.map.defaultCenter,
    zoom: GEONOTE_CONFIG.map.defaultZoom,
    zoomControl: false,
  });

  L.tileLayer(GEONOTE_CONFIG.map.tileUrl, {
    attribution: GEONOTE_CONFIG.map.attribution,
    maxZoom: 18,
  }).addTo(map);

  // Controle zoom en haut a droite
  L.control.zoom({ position: 'topright' }).addTo(map);

  // Layer pour les marqueurs avec clustering
  markersLayer = L.markerClusterGroup({
    maxClusterRadius: 50,
    spiderfyOnMaxZoom: true,
    showCoverageOnHover: false,
    iconCreateFunction: function (cluster) {
      const count = cluster.getChildCount();
      return L.divIcon({
        html: `<div class="geonote-cluster">${count}</div>`,
        className: 'geonote-cluster-icon',
        iconSize: [40, 40],
      });
    },
  });
  map.addLayer(markersLayer);

  // Geolocalisation
  locateUser();

  // Recharger les messages quand la carte bouge
  map.on('moveend', debounce(loadNearbyMessages, 500));
}

// ============================================
// GEOLOCALISATION
// ============================================
function locateUser() {
  if (!navigator.geolocation) {
    console.warn('Geolocalisation non supportee');
    loadNearbyMessages();
    return;
  }

  navigator.geolocation.getCurrentPosition(
    (position) => {
      currentPosition = {
        lat: position.coords.latitude,
        lng: position.coords.longitude,
      };

      map.setView([currentPosition.lat, currentPosition.lng], 15);

      // Marqueur position utilisateur
      if (userMarker) map.removeLayer(userMarker);
      userMarker = L.circleMarker([currentPosition.lat, currentPosition.lng], {
        radius: 8,
        fillColor: GEONOTE_CONFIG.colors.userLocation,
        fillOpacity: 1,
        color: 'white',
        weight: 3,
      }).addTo(map);

      loadNearbyMessages();
    },
    (error) => {
      console.warn('Erreur geolocalisation:', error.message);
      loadNearbyMessages();
    },
    { enableHighAccuracy: true, timeout: 10000 }
  );
}

// ============================================
// CHARGEMENT DES MESSAGES
// ============================================
async function loadNearbyMessages() {
  const center = map.getCenter();
  const lat = currentPosition?.lat || center.lat;
  const lng = currentPosition?.lng || center.lng;

  try {
    const params = new URLSearchParams({
      latitude: lat,
      longitude: lng,
      radius: currentRadius,
      limit: GEONOTE_CONFIG.defaults.maxMessages,
    });

    const response = await fetch(
      `${GEONOTE_CONFIG.api.baseUrl}${GEONOTE_CONFIG.api.endpoints.nearby}?${params}`
    );
    const data = await response.json();

    displayMessages(data.messages || []);
  } catch (error) {
    console.error('Erreur chargement messages:', error);
  }
}

// ============================================
// AFFICHAGE DES MESSAGES SUR LA CARTE
// ============================================
function displayMessages(messages) {
  markersLayer.clearLayers();

  messages.forEach((msg) => {
    const marker = L.circleMarker([msg.latitude, msg.longitude], {
      radius: 8,
      fillColor: GEONOTE_CONFIG.colors.marker,
      fillOpacity: 0.85,
      color: 'white',
      weight: 2,
    });

    const popupContent = createPopupHTML(msg);
    marker.bindPopup(popupContent, {
      maxWidth: 280,
      className: 'geonote-popup',
    });

    markersLayer.addLayer(marker);
  });
}

function createPopupHTML(msg) {
  const timeAgo = formatRelativeTime(msg.created_at);
  const hashtagsHTML = (msg.hashtags || [])
    .map((tag) => `<span class="geonote-hashtag">#${tag}</span>`)
    .join(' ');

  return `
    <div class="geonote-popup-content">
      <div class="geonote-popup-header">
        <strong>@${escapeHTML(msg.username)}</strong>
        <span class="geonote-popup-time">${timeAgo}</span>
      </div>
      <p class="geonote-popup-text">${escapeHTML(msg.content)}</p>
      ${hashtagsHTML ? `<div class="geonote-popup-tags">${hashtagsHTML}</div>` : ''}
      <div class="geonote-popup-actions">
        <button class="geonote-btn-like" onclick="toggleLike('${msg.id}')" data-message-id="${msg.id}">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
          </svg>
          <span>${msg.likes_count || 0}</span>
        </button>
        <button class="geonote-btn-comment" onclick="openComments('${msg.id}')">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
          </svg>
          <span>${msg.comments_count || 0}</span>
        </button>
      </div>
    </div>
  `;
}

// ============================================
// INTERACTIONS
// ============================================
async function toggleLike(messageId) {
  try {
    const response = await fetch(
      `${GEONOTE_CONFIG.api.baseUrl}${GEONOTE_CONFIG.api.endpoints.interactions}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message_id: messageId,
          type: 'like',
        }),
      }
    );
    const data = await response.json();

    // Mettre a jour le compteur dans le popup
    const btn = document.querySelector(`[data-message-id="${messageId}"] span`);
    if (btn) btn.textContent = data.likes_count;
  } catch (error) {
    console.error('Erreur like:', error);
  }
}

async function openComments(messageId) {
  try {
    const response = await fetch(
      `${GEONOTE_CONFIG.api.baseUrl}${GEONOTE_CONFIG.api.endpoints.interactions}?message_id=${messageId}&type=comment`
    );
    const data = await response.json();
    showCommentsPanel(messageId, data.comments || []);
  } catch (error) {
    console.error('Erreur commentaires:', error);
  }
}

function showCommentsPanel(messageId, comments) {
  const existing = document.getElementById('comments-panel');
  if (existing) existing.remove();

  const panel = document.createElement('div');
  panel.id = 'comments-panel';
  panel.className = 'geonote-comments-panel';

  const commentsHTML = comments.length
    ? comments
        .map(
          (c) => `
        <div class="geonote-comment">
          <strong>@${escapeHTML(c.username)}</strong>
          <p>${escapeHTML(c.content)}</p>
          <span class="geonote-comment-time">${formatRelativeTime(c.created_at)}</span>
        </div>
      `
        )
        .join('')
    : '<p class="geonote-empty">Aucun commentaire</p>';

  panel.innerHTML = `
    <div class="geonote-comments-header">
      <h3>Commentaires</h3>
      <button onclick="document.getElementById('comments-panel').remove()">X</button>
    </div>
    <div class="geonote-comments-list">${commentsHTML}</div>
    <form class="geonote-comment-form" onsubmit="submitComment(event, '${messageId}')">
      <input type="text" placeholder="Votre commentaire..." maxlength="300" required />
      <button type="submit">Envoyer</button>
    </form>
  `;

  document.body.appendChild(panel);
}

async function submitComment(event, messageId) {
  event.preventDefault();
  const input = event.target.querySelector('input');
  const content = input.value.trim();
  if (!content) return;

  try {
    await fetch(
      `${GEONOTE_CONFIG.api.baseUrl}${GEONOTE_CONFIG.api.endpoints.interactions}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message_id: messageId,
          type: 'comment',
          content: content,
        }),
      }
    );
    input.value = '';
    openComments(messageId); // Rafraichir
  } catch (error) {
    console.error('Erreur envoi commentaire:', error);
  }
}

// ============================================
// CREATION DE MESSAGE
// ============================================
function openCreateMessage() {
  if (!currentPosition) {
    alert('Position GPS requise pour laisser un message');
    locateUser();
    return;
  }

  const modal = document.getElementById('create-message-modal');
  if (modal) {
    modal.style.display = 'flex';
    document.getElementById('msg-lat').value = currentPosition.lat;
    document.getElementById('msg-lng').value = currentPosition.lng;
  }
}

function closeCreateMessage() {
  const modal = document.getElementById('create-message-modal');
  if (modal) modal.style.display = 'none';
}

async function submitMessage(event) {
  event.preventDefault();
  const form = event.target;
  const content = form.querySelector('[name="content"]').value.trim();
  const visibility = form.querySelector('[name="visibility"]:checked')?.value || 'public';

  if (!content) return;

  try {
    const response = await fetch(
      `${GEONOTE_CONFIG.api.baseUrl}${GEONOTE_CONFIG.api.endpoints.messages}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          content,
          visibility,
          latitude: currentPosition.lat,
          longitude: currentPosition.lng,
        }),
      }
    );

    if (response.ok) {
      closeCreateMessage();
      loadNearbyMessages();
      showNotification('Message publie !', 'success');
    } else {
      showNotification('Erreur lors de la publication', 'error');
    }
  } catch (error) {
    console.error('Erreur publication:', error);
    showNotification('Erreur de connexion', 'error');
  }
}

// ============================================
// FILTRES
// ============================================
function updateRadius(value) {
  currentRadius = parseInt(value, 10);
  document.getElementById('radius-display').textContent = `${currentRadius}m`;
  loadNearbyMessages();
}

// ============================================
// UTILITAIRES
// ============================================
function escapeHTML(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function formatRelativeTime(dateStr) {
  const now = new Date();
  const date = new Date(dateStr);
  const diffMs = now - date;
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return "a l'instant";
  if (diffMins < 60) return `il y a ${diffMins}min`;
  if (diffHours < 24) return `il y a ${diffHours}h`;
  if (diffDays < 7) return `il y a ${diffDays}j`;
  return date.toLocaleDateString('fr-FR');
}

function debounce(fn, delay) {
  let timer;
  return function (...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delay);
  };
}

function showNotification(message, type = 'info') {
  const notif = document.createElement('div');
  notif.className = `geonote-notification geonote-notification-${type}`;
  notif.textContent = message;
  document.body.appendChild(notif);

  setTimeout(() => {
    notif.classList.add('geonote-notification-fade');
    setTimeout(() => notif.remove(), 300);
  }, 3000);
}

// ============================================
// INITIALISATION
// ============================================
document.addEventListener('DOMContentLoaded', initMap);
