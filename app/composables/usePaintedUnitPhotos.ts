import type { PaintedUnitKey, PaintedUnitPhoto } from '~/types'

const BUCKET = 'painted-units'

export function usePaintedUnitPhotos() {
  const supabase = useSupabaseClient()
  const currentUserId = useCurrentUserId()

  const photos = useState<PaintedUnitPhoto[]>('painted-unit-photos', () => [])

  async function refresh(leagueId: string) {
    if (!leagueId) {
      photos.value = []
      return
    }
    const { data, error } = await supabase.from('painted_unit_photos').select('*').eq('league_id', leagueId)
    if (error) throw new Error(error.message)
    photos.value = (data as PaintedUnitPhoto[]) ?? []
  }

  function photoFor(leagueId: string, userId: string, unitKey: PaintedUnitKey) {
    return (
      photos.value.find(p => p.league_id === leagueId && p.user_id === userId && p.unit_key === unitKey) ?? null
    )
  }

  function publicUrl(path: string) {
    return supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl
  }

  async function uploadPhoto(leagueId: string, unitKey: PaintedUnitKey, kind: 'unpainted' | 'painted', file: File) {
    if (!currentUserId.value) throw new Error('Du är inte inloggad.')
    const ext = file.name.split('.').pop()?.toLowerCase() || 'jpg'
    const path = `${currentUserId.value}/${leagueId}/${unitKey}/${kind}.${ext}`

    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(path, file, { upsert: true, cacheControl: '3600' })
    if (uploadError) throw new Error(uploadError.message)

    const column = kind === 'unpainted' ? 'unpainted_path' : 'painted_path'
    const { error } = await supabase
      .from('painted_unit_photos')
      .upsert(
        { league_id: leagueId, user_id: currentUserId.value, unit_key: unitKey, [column]: path, status: 'draft' },
        { onConflict: 'league_id,user_id,unit_key' }
      )
    if (error) throw new Error(error.message)
    await refresh(leagueId)
  }

  async function submitUnit(leagueId: string, unitKey: PaintedUnitKey) {
    if (!currentUserId.value) throw new Error('Du är inte inloggad.')
    const { error } = await supabase
      .from('painted_unit_photos')
      .update({ status: 'submitted', submitted_at: new Date().toISOString() })
      .eq('league_id', leagueId)
      .eq('user_id', currentUserId.value)
      .eq('unit_key', unitKey)
    if (error) throw new Error(error.message)
    await refresh(leagueId)
  }

  async function approveUnit(leagueId: string, userId: string, unitKey: PaintedUnitKey) {
    const { error } = await supabase.rpc('approve_painted_unit', {
      p_league_id: leagueId,
      p_user_id: userId,
      p_unit_key: unitKey
    })
    if (error) throw new Error(error.message)
    await refresh(leagueId)
  }

  async function rejectUnit(leagueId: string, userId: string, unitKey: PaintedUnitKey) {
    const { error } = await supabase.rpc('reject_painted_unit', {
      p_league_id: leagueId,
      p_user_id: userId,
      p_unit_key: unitKey
    })
    if (error) throw new Error(error.message)
    await refresh(leagueId)
  }

  async function revokeUnit(leagueId: string, userId: string, unitKey: PaintedUnitKey) {
    const { error } = await supabase.rpc('revoke_painted_unit', {
      p_league_id: leagueId,
      p_user_id: userId,
      p_unit_key: unitKey
    })
    if (error) throw new Error(error.message)
    await refresh(leagueId)
  }

  return { photos, refresh, photoFor, publicUrl, uploadPhoto, submitUnit, approveUnit, rejectUnit, revokeUnit }
}
