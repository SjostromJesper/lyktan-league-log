<script setup lang="ts">
import type { Match } from '~/types'

const route = useRoute()
const playerId = computed(() => route.params.id as string)

const supabase = useSupabaseClient()
const { allLeagues, refresh: refreshLeagues } = useLeague()
const { refresh: refreshProfiles, name: profileName, byId } = useProfiles()

const playerMatches = ref<Match[]>([])

async function loadPlayerMatches() {
  const { data } = await supabase
    .from('matches')
    .select('*')
    .or(`player1_id.eq.${playerId.value},player2_id.eq.${playerId.value}`)
    .in('status', ['confirmed', 'disputed'])
    .order('created_at', { ascending: false })
  playerMatches.value = (data as Match[]) ?? []
}

onMounted(async () => {
  await Promise.all([refreshLeagues(), refreshProfiles(), loadPlayerMatches()])
})

watch(playerId, loadPlayerMatches)

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

const groupedByLeague = computed(() => {
  const groups: Record<string, Match[]> = {}
  for (const m of playerMatches.value) {
    ;(groups[m.league_id] ??= []).push(m)
  }
  return Object.entries(groups)
    .map(([leagueId, matches]) => {
      const confirmed = matches.filter(m => m.status === 'confirmed')
      const leaguePoints = confirmed.reduce((sum, m) => sum + (playerLeaguePoints(m) ?? 0), 0)
      return { leagueId, name: leagueName(leagueId), matches, matchesPlayed: confirmed.length, leaguePoints }
    })
    .sort((a, b) => a.name.localeCompare(b.name))
})
</script>

<template>
  <div class="max-w-2xl space-y-6">
    <div v-if="!player" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
      Spelaren hittades inte.
    </div>

    <template v-else>
      <div>
        <h1 class="text-2xl font-semibold text-wh-ink">{{ player.name }}</h1>
        <p v-if="player.army" class="mt-1 text-sm text-wh-mute">{{ player.army }}</p>
        <p v-if="player.discord" class="text-sm text-wh-mute">Discord: {{ player.discord }}</p>
      </div>

      <div v-if="!groupedByLeague.length" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
        Inga avslutade matcher än.
      </div>

      <div v-for="group in groupedByLeague" :key="group.leagueId" class="space-y-3">
        <h2 class="text-lg font-medium text-wh-ink">{{ group.name }}</h2>

        <div class="grid grid-cols-2 gap-4">
          <div class="rounded-lg border border-wh-border bg-wh-surface p-6">
            <p class="text-sm text-wh-mute">Matcher</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ group.matchesPlayed }}</p>
          </div>
          <div class="rounded-lg border border-wh-border bg-wh-surface p-6">
            <p class="text-sm text-wh-mute">League Points</p>
            <p class="mt-1 text-xl font-semibold text-wh-gold">{{ group.leaguePoints }}</p>
          </div>
        </div>

        <ul class="space-y-2">
          <li
            v-for="m in group.matches"
            :key="m.id"
            class="flex items-center justify-between gap-3 rounded-md border border-wh-border bg-wh-surface p-3 text-sm"
          >
            <NuxtLink :to="`/players/${opponentId(m)}`" class="text-wh-ink hover:text-wh-gold hover:underline">
              mot {{ profileName(opponentId(m)) }}
            </NuxtLink>
            <span v-if="m.status === 'disputed'" class="text-wh-accent">Bestridd</span>
            <span v-else class="text-wh-mute">
              {{ playerVp(m) }}–{{ opponentVp(m) }} VP · League Points {{ playerLeaguePoints(m) }}–{{ opponentLeaguePoints(m) }}
            </span>
          </li>
        </ul>
      </div>
    </template>
  </div>
</template>
