import type { Profile } from '~/types'

export function useProfile() {
  const supabase = useSupabaseClient()
  const userId = useCurrentUserId()
  const profile = useState<Profile | null>('profile', () => null)

  const isAdmin = computed(() => profile.value?.role === 'admin')

  async function refresh() {
    if (!userId.value) {
      profile.value = null
      return
    }
    const { data } = await supabase.from('profiles').select('*').eq('id', userId.value).single()
    profile.value = (data as Profile) ?? null
  }

  async function updateProfile(fields: { name?: string; army?: string; password_change_required?: boolean }) {
    if (!userId.value) throw new Error('Du är inte inloggad.')
    const { error } = await supabase.from('profiles').update(fields).eq('id', userId.value)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function changePassword(password: string) {
    if (password.length < 6) throw new Error('Lösenordet måste vara minst 6 tecken.')
    const { error } = await supabase.auth.updateUser({ password })
    if (error) throw new Error(error.message)
    await updateProfile({ password_change_required: false })
  }

  return { profile, isAdmin, refresh, updateProfile, changePassword }
}
