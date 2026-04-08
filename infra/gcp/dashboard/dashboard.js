/**
 * hapai Dashboard — Google OAuth2 + BigQuery Analytics
 */

// Configuration
const CONFIG = {
  clientId: "YOUR_GOOGLE_OAUTH_CLIENT_ID", // Replace with actual client ID
  scopes: [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/bigquery",
  ],
  projectId: "YOUR_GCP_PROJECT_ID", // Replace with actual project ID
};

// Validate configuration on load
function validateConfig() {
  if (!CONFIG.projectId || CONFIG.projectId === "YOUR_GCP_PROJECT_ID") {
    showError("Configuration error: projectId not set. Update CONFIG in dashboard.js");
    return false;
  }
  if (!CONFIG.clientId || CONFIG.clientId === "YOUR_GOOGLE_OAUTH_CLIENT_ID") {
    showError("Configuration error: clientId not set. Update CONFIG in dashboard.js");
    return false;
  }
  // Validate projectId format (alphanumeric, hyphens only)
  if (!/^[a-z0-9\-]+$/.test(CONFIG.projectId)) {
    showError("Configuration error: Invalid projectId format");
    return false;
  }
  return true;
}

// Sanitize BigQuery identifier (table names, dataset names)
function sanitizeIdentifier(identifier) {
  // Allow alphanumeric, underscore, and backticks for BigQuery identifiers
  // Backticks are used in the queries, so validate the content is safe
  if (!/^[a-zA-Z0-9_\-]+$/.test(identifier.replace(/`/g, ""))) {
    throw new Error("Invalid identifier format");
  }
  return identifier;
}

// Global state
let accessToken = null;
let charts = {};

// ─── Authentication ──────────────────────────────────────────────────────────

async function initAuth() {
  // Check sessionStorage for token (only persists for current session)
  const storedToken = sessionStorage.getItem("authToken");
  if (storedToken && validateToken(storedToken)) {
    accessToken = storedToken;
    showDashboard();
  } else {
    // Clear invalid/expired token
    sessionStorage.removeItem("authToken");
    showAuthRequired();
  }
}

function validateToken(token) {
  // Ensure token looks like a valid OAuth token (basic validation)
  return token && typeof token === "string" && token.length > 0 && !token.includes("<") && !token.includes(">");
}

function signIn() {
  // Use OAuth 2.0 Authorization Code Flow (secure for web apps)
  const state = generateRandomState();
  sessionStorage.setItem("oauth_state", state);

  const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?${new URLSearchParams(
    {
      client_id: CONFIG.clientId,
      redirect_uri: window.location.origin,
      response_type: "code",
      scope: CONFIG.scopes.join(" "),
      state: state,
      prompt: "consent",
      access_type: "online",
    }
  ).toString()}`;

  window.location.href = authUrl;
}

function generateRandomState() {
  // Generate cryptographically random state for CSRF protection
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function handleAuthCallback() {
  // Handle OAuth redirect with authorization code
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");
  const state = params.get("state");

  // Verify state parameter (CSRF protection)
  const storedState = sessionStorage.getItem("oauth_state");
  if (!state || state !== storedState) {
    showError("Invalid state parameter. Authentication failed.");
    return;
  }

  if (code) {
    // Exchange code for token (requires backend service)
    // For now, use implicit grant as fallback, but note this is less secure
    exchangeCodeForToken(code);
  }

  // Clear state after processing
  sessionStorage.removeItem("oauth_state");
  window.history.replaceState({}, document.title, window.location.origin);
}

function exchangeCodeForToken(code) {
  // In production, exchange code with backend to get token
  // Backend must keep client_secret secure (never expose in frontend)
  console.warn(
    "Authorization code received. Backend must exchange with Google to get access token. " +
      "Configure backend endpoint in CONFIG.tokenExchangeUrl"
  );
  // Placeholder: assume backend handles this and returns token
  // This is where you'd call your backend API
  showError("Token exchange not yet configured. Configure backend OAuth handler.");
}

function signOut() {
  accessToken = null;
  sessionStorage.removeItem("authToken");
  sessionStorage.removeItem("oauth_state");
  showAuthRequired();
}

function showAuthRequired() {
  document.getElementById("authRequired").style.display = "block";
  document.getElementById("dashboard").style.display = "none";
  document.getElementById("signInBtn").style.display = "inline-block";
  document.getElementById("signOutBtn").style.display = "none";
}

function showDashboard() {
  document.getElementById("authRequired").style.display = "none";
  document.getElementById("dashboard").style.display = "block";
  document.getElementById("signInBtn").style.display = "none";
  document.getElementById("signOutBtn").style.display = "inline-block";
  refreshData();
}

// ─── BigQuery Queries ───────────────────────────────────────────────────────

async function queryBigQuery(query) {
  if (!accessToken) {
    throw new Error("Not authenticated");
  }

  const body = {
    query: query,
    useLegacySql: false,
    useQueryCache: false,
  };

  const response = await fetch(
    `https://www.googleapis.com/bigquery/v2/projects/${CONFIG.projectId}/queries`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  if (!response.ok) {
    if (response.status === 401) {
      // Token expired
      signOut();
      throw new Error("Authentication expired. Please sign in again.");
    }
    throw new Error(`BigQuery error: ${response.statusText}`);
  }

  const data = await response.json();

  if (data.errors) {
    throw new Error(`BigQuery query error: ${data.errors[0].message}`);
  }

  return data.rows || [];
}

// ─── Data Loading ───────────────────────────────────────────────────────────

async function refreshData() {
  showLoading();
  try {
    const [stats, timeline, hooks, denials, tools, projects, trends] =
      await Promise.all([
        loadStats(),
        loadTimeline(),
        loadTopHooks(),
        loadRecentDenials(),
        loadToolsDistribution(),
        loadProjectsDistribution(),
        loadTrends(),
      ]);

    hideLoading();
    updateUI(stats, timeline, hooks, denials, tools, projects, trends);
  } catch (error) {
    hideLoading();
    showError(error.message);
  }
}

async function loadStats() {
  const query = `
    SELECT
      COUNTIF(event = 'deny') as denials,
      COUNTIF(event = 'warn') as warnings
    FROM \`${CONFIG.projectId}.hapai_dataset.events\`
    WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  `;

  const rows = await queryBigQuery(query);
  return rows[0]?.f?.[0] || { denials: 0, warnings: 0 };
}

async function loadTimeline() {
  const query = `
    SELECT
      DATE(ts) as day,
      event,
      COUNT(*) as count
    FROM \`${CONFIG.projectId}.hapai_dataset.events\`
    WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    GROUP BY day, event
    ORDER BY day DESC
  `;

  const rows = await queryBigQuery(query);
  return rows.map((row) => ({
    day: row.f[0].v,
    event: row.f[1].v,
    count: parseInt(row.f[2].v),
  }));
}

async function loadTopHooks() {
  const query = `
    SELECT
      hook,
      COUNT(*) as blocks
    FROM \`${CONFIG.projectId}.hapai_dataset.events\`
    WHERE event = 'deny' AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    GROUP BY hook
    ORDER BY blocks DESC
    LIMIT 10
  `;

  const rows = await queryBigQuery(query);
  return rows.map((row) => ({
    hook: row.f[0].v,
    blocks: parseInt(row.f[1].v),
  }));
}

async function loadRecentDenials() {
  const query = `
    SELECT
      ts,
      event,
      hook,
      tool,
      result
    FROM \`${CONFIG.projectId}.hapai_dataset.events\`
    WHERE event IN ('deny', 'warn')
    ORDER BY ts DESC
    LIMIT 50
  `;

  const rows = await queryBigQuery(query);
  return rows.map((row) => ({
    ts: row.f[0].v,
    event: row.f[1].v,
    hook: row.f[2].v,
    tool: row.f[3].v,
    result: row.f[4].v || "",
  }));
}

async function loadToolsDistribution() {
  const query = `
    SELECT
      tool,
      COUNT(*) as count
    FROM \`${CONFIG.projectId}.hapai_dataset.events\`
    WHERE event = 'deny' AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    GROUP BY tool
    ORDER BY count DESC
  `;

  const rows = await queryBigQuery(query);
  return rows.map((row) => ({
    tool: row.f[0].v,
    count: parseInt(row.f[1].v),
  }));
}

async function loadProjectsDistribution() {
  const query = `
    SELECT
      project,
      COUNT(*) as count
    FROM \`${CONFIG.projectId}.hapai_dataset.events\`
    WHERE event = 'deny' AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
      AND project IS NOT NULL
    GROUP BY project
    ORDER BY count DESC
    LIMIT 10
  `;

  const rows = await queryBigQuery(query);
  return rows.map((row) => ({
    project: row.f[0].v || "unknown",
    count: parseInt(row.f[1].v),
  }));
}

async function loadTrends() {
  const query = `
    SELECT
      DATE(ts) as day,
      COUNTIF(event = 'deny') as denies
    FROM \`${CONFIG.projectId}.hapai_dataset.events\`
    WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    GROUP BY day
    ORDER BY day
  `;

  const rows = await queryBigQuery(query);
  return rows.map((row) => ({
    day: row.f[0].v,
    denies: parseInt(row.f[1].v),
  }));
}

// ─── UI Updates ──────────────────────────────────────────────────────────────

function updateUI(stats, timeline, hooks, denials, tools, projects, trends) {
  updateStats(stats);
  updateTimeline(timeline);
  updateHooks(hooks);
  updateDenials(denials);
  updateTools(tools);
  updateProjects(projects);
  updateTrends(trends);
}

function updateStats(stats) {
  document.getElementById("statDenials").textContent =
    stats.f[0].v || "0";
  document.getElementById("statWarnings").textContent =
    stats.f[1].v || "0";
}

function updateTimeline(data) {
  const byDay = {};
  data.forEach((row) => {
    const day = row.day;
    if (!byDay[day]) byDay[day] = { day, denies: 0, warns: 0 };
    if (row.event === "deny") byDay[day].denies = row.count;
    if (row.event === "warn") byDay[day].warns = row.count;
  });

  const sorted = Object.values(byDay).sort((a, b) =>
    a.day.localeCompare(b.day)
  );

  const ctx = document.getElementById("timelineChart").getContext("2d");
  if (charts.timeline) charts.timeline.destroy();

  charts.timeline = new Chart(ctx, {
    type: "bar",
    data: {
      labels: sorted.map((d) => d.day),
      datasets: [
        {
          label: "Denials",
          data: sorted.map((d) => d.denies),
          backgroundColor: "rgba(239, 68, 68, 0.6)",
          borderColor: "rgba(239, 68, 68, 1)",
        },
        {
          label: "Warnings",
          data: sorted.map((d) => d.warns),
          backgroundColor: "rgba(202, 138, 4, 0.6)",
          borderColor: "rgba(202, 138, 4, 1)",
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { labels: { color: "#cbd5e1" } } },
      scales: {
        y: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.1)" } },
        x: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.1)" } },
      },
    },
  });
}

function updateHooks(data) {
  const ctx = document.getElementById("hooksChart").getContext("2d");
  if (charts.hooks) charts.hooks.destroy();

  charts.hooks = new Chart(ctx, {
    type: "doughnut",
    data: {
      labels: data.map((d) => d.hook),
      datasets: [
        {
          data: data.map((d) => d.blocks),
          backgroundColor: [
            "rgba(239, 68, 68, 0.8)",
            "rgba(249, 115, 22, 0.8)",
            "rgba(202, 138, 4, 0.8)",
            "rgba(34, 197, 94, 0.8)",
            "rgba(59, 130, 246, 0.8)",
            "rgba(168, 85, 247, 0.8)",
            "rgba(236, 72, 153, 0.8)",
            "rgba(8, 145, 178, 0.8)",
          ],
          borderColor: "rgba(30, 41, 59, 0.9)",
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { labels: { color: "#cbd5e1" } } },
    },
  });
}

function updateDenials(data) {
  const tbody = document.getElementById("denialTableBody");
  tbody.innerHTML = "";

  data.forEach((row) => {
    const tr = document.createElement("tr");

    const tdTime = document.createElement("td");
    tdTime.textContent = new Date(row.ts).toLocaleString();
    tr.appendChild(tdTime);

    const tdEvent = document.createElement("td");
    const eventSpan = document.createElement("span");
    eventSpan.className = `event-badge event-${row.event}`;
    eventSpan.textContent = row.event.toUpperCase();
    tdEvent.appendChild(eventSpan);
    tr.appendChild(tdEvent);

    const tdHook = document.createElement("td");
    tdHook.textContent = row.hook;
    tr.appendChild(tdHook);

    const tdTool = document.createElement("td");
    tdTool.textContent = row.tool;
    tr.appendChild(tdTool);

    const tdResult = document.createElement("td");
    tdResult.textContent = row.result || "—";
    tdResult.style.maxWidth = "300px";
    tdResult.style.whiteSpace = "nowrap";
    tdResult.style.overflow = "hidden";
    tdResult.style.textOverflow = "ellipsis";
    tr.appendChild(tdResult);

    tbody.appendChild(tr);
  });
}

function updateTools(data) {
  const ctx = document.getElementById("toolsChart").getContext("2d");
  if (charts.tools) charts.tools.destroy();

  charts.tools = new Chart(ctx, {
    type: "bar",
    data: {
      labels: data.map((d) => d.tool),
      datasets: [
        {
          label: "Denials",
          data: data.map((d) => d.count),
          backgroundColor: "rgba(59, 130, 246, 0.6)",
          borderColor: "rgba(59, 130, 246, 1)",
        },
      ],
    },
    options: {
      indexAxis: "y",
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { labels: { color: "#cbd5e1" } } },
      scales: {
        y: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.1)" } },
        x: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.1)" } },
      },
    },
  });
}

function updateProjects(data) {
  const ctx = document.getElementById("projectsChart").getContext("2d");
  if (charts.projects) charts.projects.destroy();

  charts.projects = new Chart(ctx, {
    type: "bar",
    data: {
      labels: data.map((d) => d.project.split("/").pop()),
      datasets: [
        {
          label: "Denials",
          data: data.map((d) => d.count),
          backgroundColor: "rgba(168, 85, 247, 0.6)",
          borderColor: "rgba(168, 85, 247, 1)",
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { labels: { color: "#cbd5e1" } } },
      scales: {
        y: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.1)" } },
        x: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.1)" } },
      },
    },
  });
}

function updateTrends(data) {
  const ctx = document.getElementById("trendsChart").getContext("2d");
  if (charts.trends) charts.trends.destroy();

  charts.trends = new Chart(ctx, {
    type: "line",
    data: {
      labels: data.map((d) => d.day),
      datasets: [
        {
          label: "Deny Rate",
          data: data.map((d) => d.denies),
          borderColor: "rgba(239, 68, 68, 1)",
          backgroundColor: "rgba(239, 68, 68, 0.1)",
          tension: 0.4,
          fill: true,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { labels: { color: "#cbd5e1" } } },
      scales: {
        y: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.1)" } },
        x: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.1)" } },
      },
    },
  });
}

// ─── UI Helpers ─────────────────────────────────────────────────────────────

function showLoading() {
  document.getElementById("loading").style.display = "block";
  document.getElementById("error").style.display = "none";
}

function hideLoading() {
  document.getElementById("loading").style.display = "none";
}

function showError(message) {
  const errorEl = document.getElementById("error");
  errorEl.textContent = message;
  errorEl.style.display = "block";
}

// ─── Initialization ─────────────────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  handleAuthCallback();
  initAuth();
});
