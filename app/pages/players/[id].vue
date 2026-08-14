<script setup lang="ts">
import type { LeagueMember, Match, PaintedUnits } from '~/types'
import { PAINTED_UNIT_KEYS, PAINTING_POINTS_PER_UNIT } from '~/composables/useLeague'

const route = useRoute()
const playerId = computed(() => route.params.id as string)

const supabase = useSupabaseClient()
const { allLeagues, refresh: refreshLeagues } = useLeague()
const { refresh: refreshProfiles, name: profileName, byId } = useProfiles()

const playerMatches = ref<Match[]>([])
const playerMemberships = ref<LeagueMember[]>([])
const playerPainted = ref<PaintedUnits[]>([])

async function loadPlayerData() {
  const [{ data: matchData }, { data: memberData }, { data: paintedData }] = await Promise.all([
    supabase
      .from('matches')
      .select('*')
      .or(`player1_id.eq.${playerId.value},player2_id.eq.${playerId.value}`)
      .in('status', ['confirmed', 'disputed'])
      .order('created_at', { ascending: false }),
    supabase.from('league_members').select('*').eq('user_id', playerId.value),
    supabase.from('painted_units').select('*').eq('user_id', playerId.value)
  ])
  playerMatches.value = (matchData as Match[]) ?? []
  playerMemberships.value = (memberData as LeagueMember[]) ?? []
  playerPainted.value = (paintedData as PaintedUnits[]) ?? []
}

onMounted(async () => {
  await Promise.all([refreshLeagues(), refreshProfiles(), loadPlayerData()])
})

watch(playerId, loadPlayerData)

const player = computed(() => byId(playerId.value))

function amPlayer(m: Match) {
  return m.player1_id === playerId.value
}

function opponentId(m: Match) {
  return amPlayer(m) ? m.player2_id : m.player1_id
}

function playerVp(m: Match) {
  return amPlayer(m) ? m.player1_vp : m.player2_vp
}

function opponentVp(m: Match) {
  return amPlayer(m) ? m.player2_vp : m.player1_vp
}

function playerLeaguePoints(m: Match) {
  return amPlayer(m) ? m.player1_league_points : m.player2_league_points
}

function opponentLeaguePoints(m: Match) {
  return amPlayer(m) ? m.player2_league_points : m.player1_league_points
}

function leagueName(leagueId: string) {
  return allLeagues.value.find(l => l.id === leagueId)?.name ?? 'Okänd liga'
}

function paintingPointsFor(leagueId: string) {
  const row = playerPainted.value.find(p => p.league_id === leagueId)
  if (!row) return 0
  return PAINTED_UNIT_KEYS.filter(key => row[key]).length * PAINTING_POINTS_PER_UNIT
}

const groupedByLeague = computed(() => {
  const leagueIds = new Set(playerMemberships.value.map(m => m.league_id))
  for (const m of playerMatches.value) leagueIds.add(m.league_id)

  return Array.from(leagueIds)
    .map(leagueId => {
      const matches = playerMatches.value.filter(m => m.league_id === leagueId)
      const confirmed = matches.filter(m => m.status === 'confirmed')
      let wins = 0
      let ties = 0
      let losses = 0
      let matchPoints = 0
      for (const m of confirmed) {
        const mine = playerLeaguePoints(m) ?? 0
        const theirs = opponentLeaguePoints(m) ?? 0
        matchPoints += mine
        if (mine > theirs) wins++
        else if (mine === theirs) ties++
        else losses++
      }
      const paintingPoints = paintingPointsFor(leagueId)
      return {
        leagueId,
        name: leagueName(leagueId),
        matches,
        matchesPlayed: confirmed.length,
        wins,
        ties,
        losses,
        matchPoints,
        paintingPoints,
        leaguePoints: matchPoints + paintingPoints
      }
    })
    .sort((a, b) => a.name.localeCompare(b.name))
})

const overall = computed(() =>
  groupedByLeague.value.reduce(
    (acc, g) => ({
      matchesPlayed: acc.matchesPlayed + g.matchesPlayed,
      wins: acc.wins + g.wins,
      ties: acc.ties + g.ties,
      losses: acc.losses + g.losses,
      matchPoints: acc.matchPoints + g.matchPoints,
      paintingPoints: acc.paintingPoints + g.paintingPoints,
      leaguePoints: acc.leaguePoints + g.leaguePoints
    }),
    { matchesPlayed: 0, wins: 0, ties: 0, losses: 0, matchPoints: 0, paintingPoints: 0, leaguePoints: 0 }
  )
)
</script>

<template>
  <div class="max-w-2xl space-y-6">
    <div v-if="!player" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
      Spelaren hittades inte.
    </div>

    <template v-else>
      <div class="flex items-center gap-4 rounded-lg border border-wh-border bg-wh-surface p-6">
        <div
          class="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-wh-surface-alt text-xl font-semibold text-wh-gold"
        >
          {{ player.name.slice(0, 1).toUpperCase() || '?' }}
        </div>
        <div>
          <h1 class="text-2xl font-semibold text-wh-ink">{{ player.name }}</h1>
          <p v-if="player.army" class="mt-1 text-sm text-wh-mute">{{ player.army }}</p>
          <p v-if="player.discord" class="text-sm text-wh-mute">Discord: {{ player.discord }}</p>
        </div>
      </div>

      <section v-if="groupedByLeague.length > 1" class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="mb-4 text-lg font-medium text-wh-ink">Totalt, alla ligor</h2>
        <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <div>
            <p class="text-xs text-wh-mute">Matcher</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ overall.matchesPlayed }}</p>
            <p class="text-xs text-wh-mute">{{ overall.wins }}-{{ overall.ties }}-{{ overall.losses }}</p>
          </div>
          <div>
            <p class="text-xs text-wh-mute">Match Points</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ overall.matchPoints }}</p>
          </div>
          <div>
            <p class="text-xs text-wh-mute">Painted</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ overall.paintingPoints }}</p>
          </div>
          <div>
            <p class="text-xs text-wh-mute">League Points</p>
            <p class="mt-1 text-xl font-semibold text-wh-gold">{{ overall.leaguePoints }}</p>
          </div>
        </div>
      </section>

      <div v-if="!groupedByLeague.length" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
        Med i ingen liga än.
      </div>

      <section
        v-for="group in groupedByLeague"
        :key="group.leagueId"
        class="rounded-lg border border-wh-border bg-wh-surface p-6"
      >
        <h2 class="mb-4 text-lg font-medium text-wh-ink">{{ group.name }}</h2>

        <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <div>
            <p class="text-xs text-wh-mute">Matcher</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ group.matchesPlayed }}</p>
            <p class="text-xs text-wh-mute">{{ group.wins }}-{{ group.ties }}-{{ group.losses }}</p>
          </div>
          <div>
            <p class="text-xs text-wh-mute">Match Points</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ group.matchPoints }}</p>
          </div>
          <div>
            <p class="text-xs text-wh-mute">Painted</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ group.paintingPoints }}</p>
          </div>
          <div>
            <p class="text-xs text-wh-mute">League Points</p>
            <p class="mt-1 text-xl font-semibold text-wh-gold">{{ group.leaguePoints }}</p>
          </div>
        </div>

        <div class="mt-5">
          <h3 class="mb-2 text-sm font-medium text-wh-mute">Historik</h3>
          <ul v-if="group.matches.length" class="space-y-2">
            <li
              v-for="m in group.matches"
              :key="m.id"
              class="flex items-center justify-between gap-3 rounded-md border border-wh-border bg-wh-surface-alt p-3 text-sm"
            >
              <NuxtLink :to="`/players/${opponentId(m)}`" class="text-wh-ink hover:text-wh-gold hover:underline">
                mot {{ profileName(opponentId(m)) }}
              </NuxtLink>
              <span v-if="m.status === 'disputed'" class="text-wh-accent">Bestridd</span>
              <span v-else class="text-wh-mute">
                {{ playerVp(m) }}–{{ opponentVp(m) }} VP · League Points {{ playerLeaguePoints(m) }}–{{
                  opponentLeaguePoints(m)
                }}
              </span>
            </li>
          </ul>
          <p v-else class="text-sm text-wh-mute">Inga matcher spelade än.</p>
        </div>
      </section>
    </template>
  </div>
</template>
