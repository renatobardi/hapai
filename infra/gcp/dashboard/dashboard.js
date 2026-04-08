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

// Global state
let accessToken = null;
let charts = {};

// ─── Authentication ──────────────────────────────────────────────────────────

async function initAuth() {
  if (localStorage.getItem("authToken")) {
    accessToken = localStorage.getItem("authToken");
    showDashboard();
  } else {
    showAuthRequired();
  }
}

function signIn() {
  // Use OAuth 2.0 flow
  const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?${new URLSearchParams(
    {
      client_id: CONFIG.clientId,
      redirect_uri: window.location.origin,
      response_type: "token",
      scope: CONFIG.scopes.join(" "),
      prompt: "consent",
    }
  ).toString()}`;

  window.location.href = authUrl;
}

function handleAuthCallback() {
  const hash = window.location.hash.substring(1);
  const params = new URLSearchParams(hash);
  const token = params.get("access_token");

  if (token) {
    accessToken = token;
    localStorage.setItem("authToken", token);
    window.location.hash = "";
    showDashboard();
  }
}

function signOut() {
  accessToken = null;
  localStorage.removeItem("authToken");
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
    const badge = document.createElement("span");
    badge.className = `event-badge event-${row.event}`;
    badge.textContent = row.event.toUpperCase();
    tdEvent.appendChild(badge);
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
