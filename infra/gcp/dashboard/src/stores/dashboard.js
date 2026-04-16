import { writable } from 'svelte/store'
import { queryBQ } from '../lib/api.js'

export const dashboardStore = writable({
  loading: false,
  error: null,
  period: 7,

  // Core stats (current + previous period for trend comparison)
  statsComparison: null,

  // Timeline of deny/warn rates per day
  timeline: null,

  // Per-project health scores
  projectHealth: null,

  // Top guards (hooks) by denials
  hooks: null,

  // Top denial reasons (aggregated)
  denialReasons: null,

  // Context breakdown (file categories, risk categories, branches, etc.)
  contextBreakdown: null,

  // Recent events feed
  denials: null,
  denialsOffset: 0,
  denialsHasMore: false,

  // Drill-down state
  drilldownDetail: null,
  drilldownDetailLoading: false,
  drilldownDetailError: null,
})

export async function loadDashboard(idToken, period = 7) {
  dashboardStore.update(s => ({ ...s, loading: true, error: null, period }))
  try {
    const [
      statsComparison,
      timeline,
      projectHealth,
      hooks,
      denialReasons,
      contextBreakdown,
      denials,
    ] = await Promise.all([
      queryBQ('stats_comparison', idToken, { period }),
      queryBQ('timeline',         idToken, { period }),
      queryBQ('project_health',   idToken, { period }),
      queryBQ('hooks',            idToken, { period }),
      queryBQ('denial_reasons',   idToken, { period }),
      queryBQ('context_breakdown',idToken, { period }),
      queryBQ('denials',          idToken, { period }),
    ])
    dashboardStore.set({
      loading: false, error: null, period,
      statsComparison, timeline, projectHealth,
      hooks, denialReasons, contextBreakdown,
      denials,
      denialsOffset: 0, denialsHasMore: denials.length >= 100,
      drilldownDetail: null, drilldownDetailLoading: false, drilldownDetailError: null,
    })
  } catch (err) {
    dashboardStore.update(s => ({ ...s, loading: false, error: err.message }))
  }
}

export async function setPeriod(idToken, period) {
  return loadDashboard(idToken, period)
}

export async function loadMoreDenials(idToken, period) {
  let nextOffset = 0
  dashboardStore.update(s => { nextOffset = s.denialsOffset + 100; return s })
  try {
    const more = await queryBQ('denials', idToken, { offset: nextOffset, period })
    dashboardStore.update(s => ({
      ...s,
      denials: [...(s.denials ?? []), ...more],
      denialsOffset: nextOffset,
      denialsHasMore: more.length >= 100,
    }))
  } catch (_) { /* silently ignore — existing rows remain valid */ }
}

export async function loadDrilldownDetail(type, name, idToken, period = 7) {
  if (type === 'project') return
  dashboardStore.update(s => ({
    ...s, drilldownDetail: null, drilldownDetailLoading: true, drilldownDetailError: null
  }))
  try {
    const queryName = type === 'guard' ? 'hook_detail' : 'tool_detail'
    const paramKey  = type === 'guard' ? 'hook_name'   : 'tool_name'
    const detail = await queryBQ(queryName, idToken, { [paramKey]: name, period })
    dashboardStore.update(s => ({ ...s, drilldownDetail: detail, drilldownDetailLoading: false }))
  } catch (err) {
    dashboardStore.update(s => ({
      ...s, drilldownDetailLoading: false, drilldownDetailError: err.message
    }))
  }
}
