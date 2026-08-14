<script setup lang="ts">
const { selectedLeague, scoreboard, refresh } = useLeague()
const { refresh: refreshProfiles, name: profileName, byId } = useProfiles()

onMounted(async () => {
  await Promise.all([refresh(), refreshProfiles()])
})

function army(userId: string) {
  return byId(userId)?.army ?? ''
}

function discord(userId: string) {
  return byId(userId)?.discord ?? ''
}
</script>

<template>
  <div class="max-w-2xl space-y-6">
    <h1 class="text-2xl font-semibold text-wh-ink">Tabell</h1>

    <div v-if="!selectedLeague" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
      Ingen liga vald just nu.
    </div>

    <div v-else-if="!scoreboard.length" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
      Inga medlemmar i {{ selectedLeague.name }} än.
    </div>

    <div v-else class="overflow-hidden rounded-lg border border-wh-border bg-wh-surface">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-wh-border text-wh-mute">
          <tr>
            <th class="px-4 py-3">#</th>
            <th class="px-4 py-3">Spelare</th>
            <th class="px-4 py-3 text-right">M</th>
            <th class="px-4 py-3 text-right">League Points</th>
            <th class="px-4 py-3 text-right">Painted</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, index) in scoreboard" :key="row.userId" class="border-b border-wh-border last:border-0">
            <td class="px-4 py-3 text-wh-mute">{{ index + 1 }}</td>
            <td class="px-4 py-3">
              <NuxtLink :to="`/players/${row.userId}`" class="text-wh-ink hover:text-wh-gold hover:underline">
                {{ profileName(row.userId) }}
              </NuxtLink>
              <p v-if="army(row.userId)" class="text-xs text-wh-mute">{{ army(row.userId) }}</p>
              <p v-if="discord(row.userId)" class="text-xs text-wh-mute">Discord: {{ discord(row.userId) }}</p>
            </td>
            <td class="px-4 py-3 text-right text-wh-ink">{{ row.matchesPlayed }}</td>
            <td class="px-4 py-3 text-right font-semibold text-wh-gold">{{ row.leaguePoints }}</td>
            <td class="px-4 py-3 text-right text-wh-ink">{{ row.paintingPoints }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
