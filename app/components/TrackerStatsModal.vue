<script setup lang="ts">
import type { TrackerMatch } from '~/types'

const emit = defineEmits<{ close: [] }>()

const { rows, loading, error, refresh } = useTrackerStats()
const { name: profileName } = useProfiles()

onMounted(refresh)

interface RawSecondary {
  name?: string
  discarded?: boolean
}

const totalSessions = computed(() => rows.value.length)
const savedCount = computed(() => rows.value.filter(r => r.saved_to_history).length)
const linkedCount = computed(() => rows.value.filter(r => r.apply_to_match).length)

const perUser = computed(() => {
  const map = new Map<
    string,
    { userId: string; count: number; saved: number; linked: number; lastActive: string }
  >()
  for (const r of rows.value) {
    const entry = map.get(r.user_id) ?? { userId: r.user_id, count: 0, saved: 0, linked: 0, lastActive: r.updated_at }
    entry.count++
    if (r.saved_to_history) entry.saved++
    if (r.apply_to_match) entry.linked++
    if (r.updated_at > entry.lastActive) entry.lastActive = r.updated_at
    map.set(r.user_id, entry)
  }
  return Array.from(map.values()).sort((a, b) => b.count - a.count)
})

const dispositionCounts = computed(() => {
  const counts: Record<string, number> = {}
  for (const r of rows.value) {
    if (r.my_disposition) counts[r.my_disposition] = (counts[r.my_disposition] ?? 0) + 1
    if (r.opponent_disposition) counts[r.opponent_disposition] = (counts[r.opponent_disposition] ?? 0) + 1
  }
  return Object.entries(counts).sort((a, b) => b[1] - a[1])
})

function secondariesOf(match: TrackerMatch, key: 'my_secondaries' | 'opponent_secondaries') {
  return (match[key] as RawSecondary[] | null) ?? []
}

const secondaryCounts = computed(() => {
  const counts: Record<string, number> = {}
  for (const r of rows.value) {
    for (const key of ['my_secondaries', 'opponent_secondaries'] as const) {
      for (const entry of secondariesOf(r, key)) {
        if (!entry.name || entry.discarded) continue
        counts[entry.name] = (counts[entry.name] ?? 0) + 1
      }
    }
  }
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
})

const avgSessionMinutes = computed(() => {
  if (!rows.value.length) return 0
  const totalMs = rows.value.reduce(
    (sum, r) => sum + Math.max(0, new Date(r.updated_at).getTime() - new Date(r.created_at).getTime()),
    0
  )
  return Math.round(totalMs / rows.value.length / 60000)
})

function formatDate(iso: string) {
  return new Date(iso).toLocaleString('sv-SE', { dateStyle: 'short', timeStyle: 'short' })
}
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" @click.self="emit('close')">
    <div class="w-full max-w-2xl max-h-[85vh] overflow-y-auto rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="flex items-start justify-between gap-3">
        <div>
          <h2 class="text-lg font-semibold text-wh-ink">Score keeper — statistik</h2>
          <p class="mt-1 text-xs text-wh-mute">
            Övergivna (ej sparade) sessioner rensas först nästa gång spelaren själv öppnar spårningen efter 3 dagar
            — siffrorna kan därför innehålla gamla sessioner som ännu inte rensats bort.
          </p>
        </div>
        <button type="button" class="shrink-0 text-wh-mute hover:text-wh-accent" @click="emit('close')">✕</button>
      </div>

      <p v-if="loading" class="mt-4 text-sm text-wh-mute">Laddar...</p>
      <p v-else-if="error" class="mt-4 text-sm text-wh-accent">{{ error }}</p>

      <template v-else>
        <div class="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3 text-center">
            <p class="text-xl font-semibold text-wh-ink">{{ totalSessions }}</p>
            <p class="text-xs text-wh-mute">Sessioner totalt</p>
          </div>
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3 text-center">
            <p class="text-xl font-semibold text-wh-ink">{{ perUser.length }}</p>
            <p class="text-xs text-wh-mute">Unika användare</p>
          </div>
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3 text-center">
            <p class="text-xl font-semibold text-wh-ink">{{ linkedCount }}</p>
            <p class="text-xs text-wh-mute">Kopplade till ligamatch</p>
          </div>
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3 text-center">
            <p class="text-xl font-semibold text-wh-ink">{{ savedCount }}</p>
            <p class="text-xs text-wh-mute">Sparade till historik</p>
          </div>
        </div>

        <p class="mt-3 text-xs text-wh-mute">
          Snittid per session (skapad → senast ändrad): <span class="text-wh-ink">{{ avgSessionMinutes }} min</span>
        </p>

        <h3 class="mb-2 mt-6 text-sm font-medium text-wh-ink">Vilka använder den</h3>
        <div class="overflow-x-auto rounded-md border border-wh-border">
          <table class="w-full text-left text-sm">
            <thead>
              <tr class="border-b border-wh-border text-xs text-wh-mute">
                <th class="px-3 py-2 font-normal">Spelare</th>
                <th class="px-3 py-2 font-normal">Sessioner</th>
                <th class="px-3 py-2 font-normal">Ligakopplade</th>
                <th class="px-3 py-2 font-normal">Sparade</th>
                <th class="px-3 py-2 font-normal">Senast aktiv</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="u in perUser" :key="u.userId" class="border-b border-wh-border last:border-0">
                <td class="px-3 py-2 text-wh-ink">{{ profileName(u.userId) }}</td>
                <td class="px-3 py-2 text-wh-mute">{{ u.count }}</td>
                <td class="px-3 py-2 text-wh-mute">{{ u.linked }}</td>
                <td class="px-3 py-2 text-wh-mute">{{ u.saved }}</td>
                <td class="px-3 py-2 text-wh-mute">{{ formatDate(u.lastActive) }}</td>
              </tr>
              <tr v-if="!perUser.length">
                <td colspan="5" class="px-3 py-3 text-center text-wh-mute">Ingen har använt score keeper än.</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="mt-6 grid gap-6 sm:grid-cols-2">
          <div>
            <h3 class="mb-2 text-sm font-medium text-wh-ink">Mest valda dispositioner</h3>
            <ul class="space-y-1 text-sm">
              <li v-for="[d, c] in dispositionCounts" :key="d" class="flex justify-between text-wh-mute">
                <span class="text-wh-ink">{{ d }}</span>
                <span>{{ c }}</span>
              </li>
              <li v-if="!dispositionCounts.length" class="text-wh-mute">Inget valt än.</li>
            </ul>
          </div>
          <div>
            <h3 class="mb-2 text-sm font-medium text-wh-ink">Mest valda secondaries</h3>
            <ul class="space-y-1 text-sm">
              <li v-for="[s, c] in secondaryCounts" :key="s" class="flex justify-between text-wh-mute">
                <span class="text-wh-ink">{{ s }}</span>
                <span>{{ c }}</span>
              </li>
              <li v-if="!secondaryCounts.length" class="text-wh-mute">Inget valt än.</li>
            </ul>
          </div>
        </div>
      </template>

      <div class="mt-6 flex justify-end">
        <button
          type="button"
          class="rounded-md border border-wh-border px-4 py-2 text-sm text-wh-ink hover:border-wh-accent"
          @click="emit('close')"
        >
          Stäng
        </button>
      </div>
    </div>
  </div>
</template>
