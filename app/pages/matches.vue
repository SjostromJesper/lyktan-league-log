<script setup lang="ts">
import type { Match } from '~/types'

const { myHistory, refresh } = useLeague()
const { refresh: refreshProfiles, name: profileName } = useProfiles()
const currentUserId = useCurrentUserId()

onMounted(async () => {
  await Promise.all([refresh(), refreshProfiles()])
})

function amPlayer1(m: Match) {
  return m.player1_id === currentUserId.value
}

function opponentId(m: Match) {
  return amPlayer1(m) ? m.player2_id : m.player1_id
}

function myVp(m: Match) {
  return amPlayer1(m) ? m.player1_vp : m.player2_vp
}

function opponentVp(m: Match) {
  return amPlayer1(m) ? m.player2_vp : m.player1_vp
}

function myLeaguePoints(m: Match) {
  return amPlayer1(m) ? m.player1_league_points : m.player2_league_points
}

function opponentLeaguePoints(m: Match) {
  return amPlayer1(m) ? m.player2_league_points : m.player1_league_points
}

const sorted = computed(() => [...myHistory.value].sort((a, b) => b.created_at.localeCompare(a.created_at)))
</script>

<template>
  <div class="max-w-2xl space-y-6">
    <h1 class="text-2xl font-semibold text-wh-ink">Mina matcher</h1>

    <div v-if="!sorted.length" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
      Du har inga avslutade matcher än.
    </div>

    <ul v-else class="space-y-2">
      <li
        v-for="m in sorted"
        :key="m.id"
        class="flex items-center justify-between gap-3 rounded-md border border-wh-border bg-wh-surface p-3 text-sm"
      >
        <NuxtLink :to="`/players/${opponentId(m)}`" class="text-wh-ink hover:text-wh-gold hover:underline">
          mot {{ profileName(opponentId(m)) }}
        </NuxtLink>
        <span v-if="m.status === 'disputed'" class="text-wh-accent">Bestridd</span>
        <span v-else class="text-wh-mute">
          {{ myVp(m) }}–{{ opponentVp(m) }} VP · League Points {{ myLeaguePoints(m) }}–{{ opponentLeaguePoints(m) }}
        </span>
      </li>
    </ul>
  </div>
</template>
