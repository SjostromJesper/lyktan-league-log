import type { Profile } from '~/types'

export function useProfiles() {
  const supabase = useSupabaseClient()
  const profiles = useState<Profile[]>('all-profiles', () => [])

  async function refresh() {
    const { data } = await supabase.from('profiles').select('*').order('name')
    profiles.value = (data as Profile[]) ?? []
  }

  function name(userId: string) {
    const p = profiles.value.find(p => p.id === userId)
    return p?.name || p?.email || 'Okänd spelare'
  }

  function byId(userId: string) {
    return profiles.value.find(p => p.id === userId) ?? null
  }

  return { profiles, refresh, name, byId }
}
