import { writable } from 'svelte/store'
import { queryBQ } from '../lib/api.js'

export const dashboardStore = writable({
  loading: false, error: null,
  stats: null, timeline: null, hooks: null, denials: null, tools: null, projects: null,
  period: 30,
  denialsOffset: 0, denialsHasMore: false,
  drilldownDetail: null, drilldownDetailLoading: false, drilldownDetailError: null,
})

export async function loadDashboard(idToken, period = 30) {
  dashboardStore.update(s => ({ ...s, loading: true, error: null, period }))
  try {
    const [stats, timeline, hooks, denials, tools, projects] = await Promise.all([
      queryBQ('stats',    idToken, { period }),
      queryBQ('timeline', idToken, { period }),
      queryBQ('hooks',    idToken, { period }),
      queryBQ('denials',  idToken),
      queryBQ('tools',    idToken, { period }),
      queryBQ('projects', idToken, { period }),
    ])
    dashboardStore.set({
      loading: false, error: null,
      stats, timeline, hooks, denials, tools, projects,
      period,
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

export async function loadMoreDenials(idToken) {
  let nextOffset = 0
  dashboardStore.update(s => { nextOffset = s.denialsOffset + 100; return s })
  try {
    const more = await queryBQ('denials', idToken, { offset: nextOffset })
    dashboardStore.update(s => ({
      ...s,
      denials: [...(s.denials ?? []), ...more],
      denialsOffset:  nextOffset,
      denialsHasMore: more.length >= 100,
    }))
  } catch (_) { /* silently ignore — existing rows remain valid */ }
}

export async function loadDrilldownDetail(type, name, idToken, period = 30) {
  if (type === 'project') return  // no BQ detail query for projects
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
