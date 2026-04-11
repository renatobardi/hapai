const URL = import.meta.env.VITE_BQ_PROXY_URL || 'https://us-east1-hapai-oute.cloudfunctions.net/bq-query'

export async function queryBQ(queryName, idToken, params = {}) {
  const resp = await fetch(URL, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${idToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query_name: queryName, ...params }),
  })
  if (!resp.ok) { const e = await resp.json().catch(() => ({})); throw new Error(e.error || `Query ${queryName} failed: ${resp.status}`) }
  return resp.json()
}
