import { writable } from 'svelte/store'
import { queryBQ } from '../lib/api.js'

export const dashboardStore = writable({ loading: false, error: null, stats: null, timeline: null, hooks: null, denials: null, tools: null, projects: null, trends: null })

export async function loadDashboard(idToken) {
  dashboardStore.update(s => ({ ...s, loading: true, error: null }))
  try {
    const [stats, timeline, hooks, denials, tools, projects, trends] = await Promise.all([
      queryBQ('stats', idToken), queryBQ('timeline', idToken), queryBQ('hooks', idToken),
      queryBQ('denials', idToken), queryBQ('tools', idToken), queryBQ('projects', idToken), queryBQ('trends', idToken),
    ])
    dashboardStore.set({ loading: false, error: null, stats, timeline, hooks, denials, tools, projects, trends })
  } catch (err) {
    dashboardStore.update(s => ({ ...s, loading: false, error: err.message }))
  }
}
