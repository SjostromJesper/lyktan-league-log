import type { Profile } from '~/types'

export default defineNuxtPlugin(() => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const profile = useState<Profile | null>('profile', () => null)

  async function load() {
    const userId = user.value?.sub
    if (!userId) {
      profile.value = null
      return
    }
    const { data } = await supabase.from('profiles').select('*').eq('id', userId).single()
    profile.value = (data as Profile) ?? null
  }

  watch(user, load, { immediate: true })
})
