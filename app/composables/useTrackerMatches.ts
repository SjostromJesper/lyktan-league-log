import type { TrackerMatch } from '~/types'

export const TRACKER_MATCH_RETENTION_DAYS = 3

export function useTrackerStats() {
  const supabase = useSupabaseClient()
  const rows = useState<TrackerMatch[]>('tracker-stats-rows', () => [])
  const loaded = useState('tracker-stats-loaded', () => false)
  const loading = ref(false)
  const error = ref('')

  async function refresh() {
    loading.value = true
    error.value = ''
    try {
      const { data, error: err } = await supabase.from('tracker_matches').select('*')
      if (err) throw new Error(err.message)
      rows.value = (data as TrackerMatch[]) ?? []
      loaded.value = true
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Något gick fel.'
    } finally {
      loading.value = false
    }
  }

  return { rows, loaded, loading, error, refresh }
}

export function useTrackerMatches() {
  const supabase = useSupabaseClient()
  const currentUserId = useCurrentUserId()

  const matches = useState<TrackerMatch[]>('tracker-matches', () => [])
  const loaded = useState('tracker-matches-loaded', () => false)

  async function refresh() {
    if (!currentUserId.value) {
      matches.value = []
      return
    }

    const cutoff = new Date(Date.now() - TRACKER_MATCH_RETENTION_DAYS * 24 * 60 * 60 * 1000).toISOString()
    await supabase
      .from('tracker_matches')
      .delete()
      .eq('user_id', currentUserId.value)
      .eq('saved_to_history', false)
      .lt('created_at', cutoff)

    const { data, error } = await supabase
      .from('tracker_matches')
      .select('*')
      .eq('user_id', currentUserId.value)
      .order('updated_at', { ascending: false })
    if (error) throw new Error(error.message)
    matches.value = (data as TrackerMatch[]) ?? []
    loaded.value = true
  }

  async function createMatch(name: string | null) {
    if (!currentUserId.value) throw new Error('Not logged in.')
    const trimmed = name?.trim().slice(0, 50) || null
    const { data, error } = await supabase
      .from('tracker_matches')
      .insert({ user_id: currentUserId.value, name: trimmed })
      .select()
      .single()
    if (error) throw new Error(error.message)
    const created = data as TrackerMatch
    matches.value = [created, ...matches.value]
    return created
  }

  async function updateMatch(id: string, fields: Partial<TrackerMatch>) {
    const patch = { ...fields, updated_at: new Date().toISOString() }
    const { error } = await supabase.from('tracker_matches').update(patch).eq('id', id)
    if (error) throw new Error(error.message)
    const existing = matches.value.find(m => m.id === id)
    if (existing) Object.assign(existing, patch)
  }

  async function deleteMatch(id: string) {
    const { error } = await supabase.from('tracker_matches').delete().eq('id', id)
    if (error) throw new Error(error.message)
    matches.value = matches.value.filter(m => m.id !== id)
  }

  async function setSavedToHistory(id: string, value: boolean) {
    await updateMatch(id, { saved_to_history: value })
  }

  function expiresAt(match: TrackerMatch) {
    return new Date(new Date(match.created_at).getTime() + TRACKER_MATCH_RETENTION_DAYS * 24 * 60 * 60 * 1000)
  }

  return {
    matches,
    loaded,
    refresh,
    createMatch,
    updateMatch,
    deleteMatch,
    setSavedToHistory,
    expiresAt
  }
}
