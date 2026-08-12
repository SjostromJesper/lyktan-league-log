export function useCurrentUserId() {
  const user = useSupabaseUser()
  return computed(() => user.value?.sub ?? null)
}
