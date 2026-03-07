/**
 * GeoNote - Carte interactive Leaflet
 * Version Docker MVP
 */

const GEONOTE_CONFIG = {
  map: {
    defaultCenter: [48.8584, 2.3470],
    defaultZoom: 13,
    tileUrl: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap contributors',
  },
  api: {
    baseUrl: '/api',
  },
  defaults: {
    radius: 10000,
    maxMessages: 50,
  },
  colors: {
    primary: '#FF6B35',
    marker: '#FF6B35',
    userLocation: '#4A90D9',
  },
};

let map;
let markersLayer;
let userMarker;
let currentPosition = null;
let currentRadius = GEONOTE_CONFIG.defaults.radius;

function initMap() {
  try {
    console.log('[GeoNote] Initialisation carte...');

    map = L.map('map-container', {
      center: GEONOTE_CONFIG.map.defaultCenter,
      zoom: GEONOTE_CONFIG.map.defaultZoom,
      zoomControl: false,
    });

    L.tileLayer(GEONOTE_CONFIG.map.tileUrl, {
      attribution: GEONOTE_CONFIG.map.attribution,
      maxZoom: 18,
    }).addTo(map);

    L.control.zoom({ position: 'topright' }).addTo(map);

    // MarkerCluster ou fallback sur un simple layer group
    if (typeof L.markerClusterGroup === 'function') {
      console.log('[GeoNote] MarkerCluster charge');
      markersLayer = L.markerClusterGroup({
        maxClusterRadius: 50,
        spiderfyOnMaxZoom: true,
        showCoverageOnHover: false,
        iconCreateFunction: function (cluster) {
          return L.divIcon({
            html: '<div class="geonote-cluster">' + cluster.getChildCount() + '</div>',
            className: 'geonote-cluster-icon',
            iconSize: [40, 40],
          });
        },
      });
    } else {
      console.warn('[GeoNote] MarkerCluster non disponible, fallback layerGroup');
      markersLayer = L.layerGroup();
    }
    map.addLayer(markersLayer);

    console.log('[GeoNote] Carte prete, chargement messages...');

    // Charger les messages immediatement (sans attendre la geoloc)
    loadNearbyMessages();

    // Tenter la geolocalisation en parallele
    locateUser();

    // Recharger quand la carte bouge
    map.on('moveend', debounce(function () {
      loadNearbyMessages();
    }, 800));

  } catch (err) {
    console.error('[GeoNote] Erreur init carte:', err);
  }
}

function locateUser() {
  if (!navigator.geolocation) {
    console.warn('[GeoNote] Geolocalisation non supportee');
    return;
  }

  navigator.geolocation.getCurrentPosition(
    function (position) {
      currentPosition = {
        lat: position.coords.latitude,
        lng: position.coords.longitude,
      };
      console.log('[GeoNote] Position:', currentPosition);
      map.setView([currentPosition.lat, currentPosition.lng], 15);
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
    function (err) {
      console.warn('[GeoNote] Geoloc refusee:', err.message, '- utilisation Paris par defaut');
    },
    { enableHighAccuracy: true, timeout: 5000 }
  );
}

async function loadNearbyMessages() {
  var center = map.getCenter();
  var lat = currentPosition ? currentPosition.lat : center.lat;
  var lng = currentPosition ? currentPosition.lng : center.lng;

  var searchInput = document.getElementById('search-hashtag');
  var hashtag = searchInput ? searchInput.value.trim() : '';

  var sortSelect = document.getElementById('filter-sort');
  var sort = sortSelect ? sortSelect.value : 'distance';

  var url = GEONOTE_CONFIG.api.baseUrl + '/messages/nearby'
    + '?latitude=' + lat
    + '&longitude=' + lng
    + '&radius=' + currentRadius
    + '&limit=' + GEONOTE_CONFIG.defaults.maxMessages
    + '&sort=' + sort;
  if (hashtag) url += '&hashtag=' + encodeURIComponent(hashtag);

  console.log('[GeoNote] Chargement messages:', url);

  try {
    var response = await fetch(url);
    if (!response.ok) {
      console.error('[GeoNote] API erreur:', response.status);
      return;
    }
    var data = await response.json();
    console.log('[GeoNote] Messages recus:', (data.messages || []).length);
    displayMessages(data.messages || []);
  } catch (error) {
    console.error('[GeoNote] Erreur fetch messages:', error);
  }
}

function displayMessages(messages) {
  markersLayer.clearLayers();

  // Update count badge
  var badge = document.getElementById('msg-count-badge');
  if (badge) {
    if (messages.length > 0) {
      badge.textContent = messages.length + ' message' + (messages.length > 1 ? 's' : '') + ' autour de vous';
      badge.style.display = 'block';
    } else {
      badge.textContent = 'Aucun message dans cette zone';
      badge.style.display = 'block';
    }
  }

  if (messages.length === 0) {
    console.log('[GeoNote] Aucun message a afficher');
    return;
  }

  messages.forEach(function (msg) {
    var marker = L.circleMarker([msg.latitude, msg.longitude], {
      radius: 10,
      fillColor: GEONOTE_CONFIG.colors.marker,
      fillOpacity: 0.9,
      color: 'white',
      weight: 2,
    });

    marker.bindPopup(createPopupHTML(msg), {
      maxWidth: 300,
      className: 'geonote-popup',
    });

    markersLayer.addLayer(marker);
  });

  console.log('[GeoNote] ' + messages.length + ' markers affiches');
}

function createPopupHTML(msg) {
  var timeAgo = formatRelativeTime(msg.created_at);
  var hashtagsHTML = (msg.hashtags || [])
    .map(function (tag) { return '<span class="geonote-hashtag">#' + escapeHTML(tag) + '</span>'; })
    .join(' ');

  return '<div class="geonote-popup-content">'
    + '<div class="geonote-popup-header">'
    +   '<strong>@' + escapeHTML(msg.username) + '</strong>'
    +   '<span class="geonote-popup-time">' + timeAgo + '</span>'
    + '</div>'
    + '<p class="geonote-popup-text">' + escapeHTML(msg.content) + '</p>'
    + (hashtagsHTML ? '<div class="geonote-popup-tags">' + hashtagsHTML + '</div>' : '')
    + '<div class="geonote-popup-actions">'
    +   '<button class="geonote-btn-like" onclick="toggleLike(\'' + msg.id + '\')" data-message-id="' + msg.id + '">'
    +     '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>'
    +     ' <span>' + (msg.likes_count || 0) + '</span>'
    +   '</button>'
    +   '<button class="geonote-btn-comment" onclick="openComments(\'' + msg.id + '\')">'
    +     '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>'
    +     ' <span>' + (msg.comments_count || 0) + '</span>'
    +   '</button>'
    + '</div>'
    + '</div>';
}

async function toggleLike(messageId) {
  try {
    var response = await fetch(GEONOTE_CONFIG.api.baseUrl + '/interactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message_id: messageId, type: 'like' }),
    });
    var data = await response.json();
    var btn = document.querySelector('[data-message-id="' + messageId + '"] span');
    if (btn) btn.textContent = data.likes_count;
    console.log('[GeoNote] Like toggle:', data);
  } catch (error) {
    console.error('[GeoNote] Erreur like:', error);
  }
}

async function openComments(messageId) {
  try {
    var response = await fetch(
      GEONOTE_CONFIG.api.baseUrl + '/interactions?message_id=' + messageId + '&type=comment'
    );
    var data = await response.json();
    showCommentsPanel(messageId, data.comments || []);
  } catch (error) {
    console.error('[GeoNote] Erreur commentaires:', error);
  }
}

function showCommentsPanel(messageId, comments) {
  var existing = document.getElementById('comments-panel');
  if (existing) existing.remove();

  var panel = document.createElement('div');
  panel.id = 'comments-panel';
  panel.className = 'geonote-comments-panel';

  var commentsHTML = comments.length
    ? comments.map(function (c) {
        return '<div class="geonote-comment">'
          + '<strong>@' + escapeHTML(c.username) + '</strong>'
          + '<p>' + escapeHTML(c.content) + '</p>'
          + '<span class="geonote-comment-time">' + formatRelativeTime(c.created_at) + '</span>'
          + '</div>';
      }).join('')
    : '<p class="geonote-empty">Aucun commentaire</p>';

  panel.innerHTML =
    '<div class="geonote-comments-header">'
    + '<h3>Commentaires</h3>'
    + '<button onclick="document.getElementById(\'comments-panel\').remove()">X</button>'
    + '</div>'
    + '<div class="geonote-comments-list">' + commentsHTML + '</div>'
    + '<form class="geonote-comment-form" onsubmit="submitComment(event, \'' + messageId + '\')">'
    + '<input type="text" placeholder="Votre commentaire..." maxlength="300" required />'
    + '<button type="submit">Envoyer</button>'
    + '</form>';

  document.body.appendChild(panel);
}

async function submitComment(event, messageId) {
  event.preventDefault();
  var input = event.target.querySelector('input');
  var content = input.value.trim();
  if (!content) return;

  try {
    await fetch(GEONOTE_CONFIG.api.baseUrl + '/interactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message_id: messageId, type: 'comment', content: content }),
    });
    input.value = '';
    openComments(messageId);
  } catch (error) {
    console.error('[GeoNote] Erreur commentaire:', error);
  }
}

function openCreateMessage() {
  if (!currentPosition) {
    var center = map.getCenter();
    currentPosition = { lat: center.lat, lng: center.lng };
  }
  var modal = document.getElementById('create-message-modal');
  if (modal) {
    modal.style.display = 'flex';
    document.getElementById('msg-lat').value = currentPosition.lat;
    document.getElementById('msg-lng').value = currentPosition.lng;
  }
}

function closeCreateMessage() {
  var modal = document.getElementById('create-message-modal');
  if (modal) modal.style.display = 'none';
}

async function submitMessage(event) {
  event.preventDefault();
  var form = event.target;
  var content = form.querySelector('[name="content"]').value.trim();
  var checkedRadio = form.querySelector('[name="visibility"]:checked');
  var visibility = checkedRadio ? checkedRadio.value : 'public';

  if (!content) return;

  try {
    var response = await fetch(GEONOTE_CONFIG.api.baseUrl + '/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        content: content,
        visibility: visibility,
        latitude: parseFloat(document.getElementById('msg-lat').value),
        longitude: parseFloat(document.getElementById('msg-lng').value),
      }),
    });

    if (response.ok) {
      form.querySelector('[name="content"]').value = '';
      document.getElementById('char-count').textContent = '0';
      closeCreateMessage();
      loadNearbyMessages();
      showNotification('Message publie !', 'success');
    } else {
      var err = await response.json();
      showNotification(err.error || 'Erreur lors de la publication', 'error');
    }
  } catch (error) {
    console.error('[GeoNote] Erreur publication:', error);
    showNotification('Erreur de connexion', 'error');
  }
}

function updateRadius(value) {
  currentRadius = parseInt(value, 10);
  var display = currentRadius >= 1000
    ? (currentRadius / 1000) + 'km'
    : currentRadius + 'm';
  document.getElementById('radius-display').textContent = display;
  loadNearbyMessages();
}

function escapeHTML(str) {
  if (!str) return '';
  var div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function formatRelativeTime(dateStr) {
  if (!dateStr) return '';
  var now = new Date();
  var date = new Date(dateStr);
  var diffMs = now - date;
  var diffMins = Math.floor(diffMs / 60000);
  var diffHours = Math.floor(diffMs / 3600000);
  var diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return "a l'instant";
  if (diffMins < 60) return 'il y a ' + diffMins + 'min';
  if (diffHours < 24) return 'il y a ' + diffHours + 'h';
  if (diffDays < 7) return 'il y a ' + diffDays + 'j';
  return date.toLocaleDateString('fr-FR');
}

function debounce(fn, delay) {
  var timer;
  return function () {
    var ctx = this;
    var args = arguments;
    clearTimeout(timer);
    timer = setTimeout(function () { fn.apply(ctx, args); }, delay);
  };
}

function showNotification(message, type) {
  type = type || 'info';
  var notif = document.createElement('div');
  notif.className = 'geonote-notification geonote-notification-' + type;
  notif.textContent = message;
  document.body.appendChild(notif);
  setTimeout(function () {
    notif.classList.add('geonote-notification-fade');
    setTimeout(function () { notif.remove(); }, 300);
  }, 3000);
}

document.addEventListener('DOMContentLoaded', initMap);
