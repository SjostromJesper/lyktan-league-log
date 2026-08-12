export function useViewMode() {
  const { isAdmin } = useProfile()
  const viewAsPlayer = useState('view-as-player', () => false)

  const isAdminView = computed(() => isAdmin.value && !viewAsPlayer.value)

  function toggle() {
    viewAsPlayer.value = !viewAsPlayer.value
  }

  return { viewAsPlayer, isAdminView, toggle }
}
