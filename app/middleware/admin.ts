export default defineNuxtRouteMiddleware(async () => {
  const user = useSupabaseUser()
  if (!user.value) {
    return navigateTo('/login')
  }
  const { profile, refresh } = useProfile()
  if (!profile.value) {
    await refresh()
  }
  const { isAdminView } = useViewMode()
  if (!isAdminView.value) {
    return navigateTo('/')
  }
})
