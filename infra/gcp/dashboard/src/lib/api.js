const BQ_URL = import.meta.env.VITE_BQ_PROXY_URL || 'https://us-east1-hapai-oute.cloudfunctions.net/hapai-audit-loader'
const FETCH_TIMEOUT_MS = 30_000

export async function queryBQ(queryName, idToken, params = {}) {
  if (!idToken) throw new Error('Not authenticated — please sign in.')

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)

  let resp
  try {
    resp = await fetch(BQ_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${idToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query_name: queryName, ...params }),
      signal: controller.signal,
    })
  } catch (err) {
    clearTimeout(timer)
    if (err.name === 'AbortError') {
      throw new Error(`Query "${queryName}" timed out after 30s. The server may be overloaded.`)
    }
    throw new Error(`Network error on query "${queryName}": ${err.message}`)
  }
  clearTimeout(timer)

  if (!resp.ok) {
    let detail = ''
    try {
      const body = await resp.json()
      detail = body?.error || ''
    } catch (parseErr) {
      // JSON parse failed; use HTTP status as fallback detail
      console.warn('Failed to parse error response:', parseErr)
      detail = `HTTP ${resp.status}`
    }
    if (resp.status === 401) throw new Error('Session expired — please sign in again.')
    if (resp.status === 403) throw new Error('Access denied.')
    if (resp.status === 404) throw new Error(`Endpoint not found. Check VITE_BQ_PROXY_URL. (${BQ_URL})`)
    throw new Error(detail || `Query "${queryName}" failed: HTTP ${resp.status}`)
  }

  return resp.json()
}
