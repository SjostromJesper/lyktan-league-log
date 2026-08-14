import type { League, LeagueMember, Match, PaintedUnits, Signup } from '~/types'

export const PAINTED_UNIT_KEYS = ['unit1', 'unit2', 'unit3', 'unit4', 'unit5'] as const
export type PaintedUnitKey = (typeof PAINTED_UNIT_KEYS)[number]
export const PAINTING_POINTS_PER_UNIT = 3

export function useLeague() {
  const supabase = useSupabaseClient()
  const currentUserId = useCurrentUserId()

  const selectedLeagueId = useState<string | null>('selected-league-id', () => null)
  const allLeagues = useState<League[]>('all-leagues', () => [])
  const members = useState<LeagueMember[]>('league-members', () => [])
  const allMembers = useState<LeagueMember[]>('all-league-members', () => [])
  const signups = useState<Signup[]>('league-signups', () => [])
  const matches = useState<Match[]>('league-matches', () => [])
  const paintedUnits = useState<PaintedUnits[]>('league-painted-units', () => [])
  const loaded = useState('league-loaded', () => false)

  const selectedLeague = computed(() => allLeagues.value.find(l => l.id === selectedLeagueId.value) ?? null)

  const myLeagues = computed(() => {
    if (!currentUserId.value) return []
    const myIds = new Set(
      allMembers.value.filter(m => m.user_id === currentUserId.value).map(m => m.league_id)
    )
    return allLeagues.value.filter(l => myIds.has(l.id) && !l.is_archived)
  })

  function persistedLeagueKey() {
    return currentUserId.value ? `wh-selected-league:${currentUserId.value}` : null
  }

  function loadPersistedLeagueId(): string | null {
    const key = persistedLeagueKey()
    if (!key || typeof window === 'undefined') return null
    return window.localStorage.getItem(key)
  }

  function persistLeagueId(leagueId: string | null) {
    const key = persistedLeagueKey()
    if (!key || typeof window === 'undefined') return
    if (leagueId) window.localStorage.setItem(key, leagueId)
    else window.localStorage.removeItem(key)
  }

  async function refreshLeagueScopedData() {
    if (!selectedLeagueId.value) {
      members.value = []
      signups.value = []
      matches.value = []
      paintedUnits.value = []
      return
    }
    const [{ data: memberData }, { data: signupData }, { data: matchData }, { data: paintedData }] =
      await Promise.all([
        supabase.from('league_members').select('*').eq('league_id', selectedLeagueId.value),
        supabase.from('signups').select('*').eq('league_id', selectedLeagueId.value),
        supabase
          .from('matches')
          .select('*')
          .eq('league_id', selectedLeagueId.value)
          .order('created_at', { ascending: false }),
        supabase.from('painted_units').select('*').eq('league_id', selectedLeagueId.value)
      ])
    members.value = (memberData as LeagueMember[]) ?? []
    signups.value = (signupData as Signup[]) ?? []
    matches.value = (matchData as Match[]) ?? []
    paintedUnits.value = (paintedData as PaintedUnits[]) ?? []
  }

  async function selectLeague(leagueId: string) {
    selectedLeagueId.value = leagueId
    persistLeagueId(leagueId)
    await refreshLeagueScopedData()
  }

  async function refresh() {
    const [{ data: leaguesData }, { data: allMembersData }] = await Promise.all([
      supabase.from('leagues').select('*').order('created_at', { ascending: false }),
      supabase.from('league_members').select('*')
    ])
    allLeagues.value = (leaguesData as League[]) ?? []
    allMembers.value = (allMembersData as LeagueMember[]) ?? []

    if (!selectedLeagueId.value || !allLeagues.value.some(l => l.id === selectedLeagueId.value)) {
      const persisted = loadPersistedLeagueId()
      const myIds = new Set(
        allMembers.value.filter(m => m.user_id === currentUserId.value).map(m => m.league_id)
      )
      const mine = allLeagues.value.filter(l => myIds.has(l.id) && !l.is_archived)
      selectedLeagueId.value =
        (persisted && allLeagues.value.some(l => l.id === persisted) ? persisted : null) ??
        mine.find(l => l.is_active)?.id ??
        mine[0]?.id ??
        allLeagues.value.find(l => l.is_active && !l.is_archived)?.id ??
        null
    }

    await refreshLeagueScopedData()
    loaded.value = true
  }

  const isMember = computed(() => !!currentUserId.value && members.value.some(m => m.user_id === currentUserId.value))

  const mySignup = computed(() => signups.value.find(s => s.user_id === currentUserId.value) ?? null)

  const myActiveMatch = computed(
    () =>
      matches.value.find(
        m =>
          (m.player1_id === currentUserId.value || m.player2_id === currentUserId.value) &&
          (m.status === 'pending' || m.status === 'reported' || m.status === 'disputed')
      ) ?? null
  )

  const pendingConfirmations = computed(() =>
    matches.value.filter(
      m =>
        m.status === 'reported' &&
        m.reporter_id !== currentUserId.value &&
        (m.player1_id === currentUserId.value || m.player2_id === currentUserId.value)
    )
  )

  const myHistory = computed(() =>
    matches.value.filter(
      m =>
        (m.status === 'confirmed' || m.status === 'disputed') &&
        (m.player1_id === currentUserId.value || m.player2_id === currentUserId.value)
    )
  )

  const disputedMatches = computed(() => matches.value.filter(m => m.status === 'disputed'))

  const myPhaseMatchCount = computed(() => {
    if (!selectedLeague.value || !currentUserId.value) return 0
    return matches.value.filter(
      m =>
        m.phase_number === selectedLeague.value!.current_phase &&
        (m.status === 'confirmed' || m.status === 'disputed') &&
        (m.player1_id === currentUserId.value || m.player2_id === currentUserId.value)
    ).length
  })

  function historyForUser(userId: string) {
    return matches.value.filter(
      m => (m.status === 'confirmed' || m.status === 'disputed') && (m.player1_id === userId || m.player2_id === userId)
    )
  }

  function leaguesForUser(userId: string) {
    return allMembers.value.filter(m => m.user_id === userId).map(m => m.league_id)
  }

  interface LeagueSettings {
    description: string
    phaseCount: number
    matchesPerPhase: number
  }

  async function createLeague(name: string, settings: LeagueSettings) {
    if (!name.trim()) throw new Error('Ligan måste ha ett namn.')
    const { data, error } = await supabase
      .from('leagues')
      .insert({
        name: name.trim(),
        description: settings.description.trim(),
        phase_count: settings.phaseCount,
        matches_per_phase: settings.matchesPerPhase,
        current_phase: 1,
        is_active: true
      })
      .select()
      .single()
    if (error) throw new Error(error.message)
    await refresh()
    if (data?.id) await selectLeague(data.id)
  }

  async function setActiveLeague(leagueId: string) {
    const { error } = await supabase.from('leagues').update({ is_active: true }).eq('id', leagueId)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function deactivateLeague(leagueId: string) {
    const { error } = await supabase.from('leagues').update({ is_active: false }).eq('id', leagueId)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function updateLeague(
    leagueId: string,
    fields: { name?: string; description?: string; phase_count?: number; matches_per_phase?: number }
  ) {
    const { error } = await supabase.from('leagues').update(fields).eq('id', leagueId)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function advancePhase(leagueId: string) {
    const league = allLeagues.value.find(l => l.id === leagueId)
    if (!league) return
    if (league.current_phase >= league.phase_count) throw new Error('Det finns ingen fler fas i ligan.')
    const { error } = await supabase
      .from('leagues')
      .update({ current_phase: league.current_phase + 1 })
      .eq('id', leagueId)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function archiveLeague(leagueId: string) {
    const { error } = await supabase.from('leagues').update({ is_archived: true, is_active: false }).eq('id', leagueId)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function unarchiveLeague(leagueId: string) {
    const { error } = await supabase.from('leagues').update({ is_archived: false }).eq('id', leagueId)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function deleteLeague(leagueId: string) {
    const { error } = await supabase.from('leagues').delete().eq('id', leagueId)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function addMember(userId: string) {
    if (!selectedLeague.value) throw new Error('Ingen liga vald.')
    const { error } = await supabase
      .from('league_members')
      .insert({ league_id: selectedLeague.value.id, user_id: userId })
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function addMemberToLeague(userId: string, leagueId: string) {
    const { error } = await supabase.from('league_members').insert({ league_id: leagueId, user_id: userId })
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function removeMember(userId: string) {
    if (!selectedLeague.value) return
    const { error } = await supabase
      .from('league_members')
      .delete()
      .eq('league_id', selectedLeague.value.id)
      .eq('user_id', userId)
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function submitSignup(armyList: string) {
    if (!selectedLeague.value || !currentUserId.value) throw new Error('Ingen liga vald.')
    if (!armyList.trim()) throw new Error('Listan kan inte vara tom.')
    const { error } = await supabase
      .from('signups')
      .insert({ league_id: selectedLeague.value.id, user_id: currentUserId.value, army_list: armyList })
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function pairAll() {
    if (!selectedLeague.value) return
    const { error } = await supabase.rpc('pair_all_ready', { p_league_id: selectedLeague.value.id })
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function pairIndividual(userId: string) {
    if (!selectedLeague.value) return null
    const { data, error } = await supabase.rpc('pair_individual', {
      p_league_id: selectedLeague.value.id,
      p_user_id: userId
    })
    if (error) throw new Error(error.message)
    await refresh()
    // Postgres serializes `return null` from a composite-returning function as
    // a row of all-null fields, not a bare null, so check the id explicitly.
    const match = data as Match | null
    return match?.id ? match : null
  }

  async function pairManual(userId: string, opponentId: string) {
    if (!selectedLeague.value) return
    const { error } = await supabase.rpc('pair_manual', {
      p_league_id: selectedLeague.value.id,
      p_user_id: userId,
      p_opponent_id: opponentId
    })
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function reportMatch(matchId: string, myVp: number, opponentVp: number) {
    const { error } = await supabase.rpc('report_match', {
      p_match_id: matchId,
      p_my_vp: myVp,
      p_opponent_vp: opponentVp
    })
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function confirmMatch(matchId: string, action: 'confirm' | 'dispute') {
    const { error } = await supabase.rpc('confirm_match', { p_match_id: matchId, p_action: action })
    if (error) throw new Error(error.message)
    await refresh()
  }

  async function resolveDispute(matchId: string, action: 'confirm' | 'void', player1Vp?: number, player2Vp?: number) {
    const { error } = await supabase.rpc('admin_resolve_match', {
      p_match_id: matchId,
      p_action: action,
      p_player1_vp: player1Vp ?? null,
      p_player2_vp: player2Vp ?? null
    })
    if (error) throw new Error(error.message)
    await refresh()
  }

  function paintingPointsFor(userId: string) {
    const row = paintedUnits.value.find(p => p.user_id === userId)
    if (!row) return 0
    return PAINTED_UNIT_KEYS.filter(key => row[key]).length * PAINTING_POINTS_PER_UNIT
  }

  async function setPaintedUnit(userId: string, unit: PaintedUnitKey, value: boolean) {
    if (!selectedLeague.value) return
    const { error } = await supabase
      .from('painted_units')
      .upsert({ league_id: selectedLeague.value.id, user_id: userId, [unit]: value }, { onConflict: 'league_id,user_id' })
    if (error) throw new Error(error.message)
    await refreshLeagueScopedData()
  }

  const scoreboard = computed(() => {
    const tally: Record<
      string,
      {
        matchesPlayed: number
        wins: number
        ties: number
        losses: number
        matchPoints: number
        wtcPoints: number
        vpDiff: number
      }
    > = {}
    function ensure(id: string) {
      if (!tally[id]) {
        tally[id] = { matchesPlayed: 0, wins: 0, ties: 0, losses: 0, matchPoints: 0, wtcPoints: 0, vpDiff: 0 }
      }
      return tally[id]
    }
    for (const m of members.value) {
      ensure(m.user_id)
    }
    const confirmed = matches.value.filter(
      m => m.status === 'confirmed' && m.player1_vp != null && m.player2_vp != null
    )
    for (const m of confirmed) {
      const p1lp = m.player1_league_points ?? 0
      const p2lp = m.player2_league_points ?? 0

      const p1 = ensure(m.player1_id)
      p1.matchesPlayed++
      p1.matchPoints += p1lp
      p1.wtcPoints += m.player1_wtc ?? 0
      p1.vpDiff += (m.player1_vp ?? 0) - (m.player2_vp ?? 0)
      if (p1lp > p2lp) p1.wins++
      else if (p1lp === p2lp) p1.ties++
      else p1.losses++

      const p2 = ensure(m.player2_id)
      p2.matchesPlayed++
      p2.matchPoints += p2lp
      p2.wtcPoints += m.player2_wtc ?? 0
      p2.vpDiff += (m.player2_vp ?? 0) - (m.player1_vp ?? 0)
      if (p2lp > p1lp) p2.wins++
      else if (p2lp === p1lp) p2.ties++
      else p2.losses++
    }
    return Object.entries(tally)
      .map(([userId, stats]) => {
        const paintingPoints = paintingPointsFor(userId)
        return { userId, ...stats, paintingPoints, leaguePoints: stats.matchPoints + paintingPoints }
      })
      .sort((a, b) => b.leaguePoints - a.leaguePoints || b.wtcPoints - a.wtcPoints || b.vpDiff - a.vpDiff)
  })

  return {
    selectedLeague,
    selectLeague,
    myLeagues,
    allLeagues,
    members,
    allMembers,
    leaguesForUser,
    signups,
    matches,
    paintedUnits,
    loaded,
    isMember,
    mySignup,
    myActiveMatch,
    pendingConfirmations,
    myHistory,
    historyForUser,
    disputedMatches,
    myPhaseMatchCount,
    scoreboard,
    paintingPointsFor,
    setPaintedUnit,
    refresh,
    createLeague,
    setActiveLeague,
    deactivateLeague,
    updateLeague,
    advancePhase,
    archiveLeague,
    unarchiveLeague,
    deleteLeague,
    addMember,
    addMemberToLeague,
    removeMember,
    submitSignup,
    pairAll,
    pairIndividual,
    pairManual,
    reportMatch,
    confirmMatch,
    resolveDispute
  }
}
