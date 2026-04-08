const BQ_PROXY_URL = import.meta.env.VITE_BQ_PROXY_URL ||
  'https://us-east1-hapai-oute.cloudfunctions.net/bq-query'

export async function queryBQ(queryName, idToken) {
  const resp = await fetch(BQ_PROXY_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query_name: queryName }),
  })

  if (!resp.ok) {
    const err = await resp.json().catch(() => ({}))
    throw new Error(err.error || `Query ${queryName} failed: ${resp.status}`)
  }

  return resp.json()
}
