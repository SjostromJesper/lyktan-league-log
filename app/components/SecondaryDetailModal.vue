<script setup lang="ts">
import type { SecondaryEntry } from './SecondaryTracker.vue'

const props = defineProps<{ entry: SecondaryEntry; maxPointsPerRound: number; description: string }>()
const emit = defineEmits<{ close: []; remove: [] }>()

// Tactical Secondary Missions are discarded the moment they're scored (see the
// Tournament Companion's "Achieving Secondary Missions" rule) — so a secondary can only
// ever be achieved in one battle round. Ticking a new round clears every other round
// across all options, but leaves other options' ticks in *that same* round alone, since
// some secondaries (e.g. Defend Stronghold) have cumulative bonuses scored together.
function toggleRound(optionIndex: number, roundIndex: number) {
  const wasCompleted = props.entry.options[optionIndex].roundsCompleted[roundIndex]
  if (!wasCompleted) {
    for (const option of props.entry.options) {
      option.roundsCompleted = option.roundsCompleted.map((done, ri) => (ri === roundIndex ? done : false))
    }
  }
  props.entry.options[optionIndex].roundsCompleted[roundIndex] = !wasCompleted
}
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" @click.self="emit('close')">
    <div class="w-full max-w-md rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="flex items-start justify-between gap-3">
        <h2 class="text-lg font-semibold text-wh-ink">{{ entry.name }}</h2>
        <button type="button" class="text-wh-mute hover:text-wh-accent" @click="emit('close')">✕</button>
      </div>
      <p v-if="description" class="mt-1 text-sm text-wh-mute">{{ description }}</p>

      <label class="mt-4 flex items-center gap-2 text-sm text-wh-ink">
        <input v-model="entry.discarded" type="checkbox" class="accent-wh-accent">
        Discarded
      </label>

      <template v-if="!entry.discarded">
        <div class="mt-4 space-y-3">
          <p class="text-sm text-wh-mute">Scoring options</p>
          <div v-for="(opt, oi) in entry.options" :key="oi" class="rounded-md border border-wh-border p-3">
            <div class="flex items-start justify-between gap-3">
              <p class="text-sm text-wh-ink">{{ opt.label }}</p>
              <span class="shrink-0 rounded-md bg-wh-surface-alt px-2 py-0.5 text-xs font-semibold text-wh-gold">
                {{ opt.points }}p
              </span>
            </div>
            <p class="mt-1 text-xs text-wh-mute">Resolves: {{ opt.timing }}</p>
            <div class="mt-2">
              <label class="mb-1 block text-xs text-wh-mute">Achieved in round</label>
              <div class="flex gap-1">
                <button
                  v-for="(done, ri) in opt.roundsCompleted"
                  :key="ri"
                  type="button"
                  :title="`Round ${ri + 1}`"
                  :class="[
                    'flex h-8 w-8 items-center justify-center rounded-md text-sm font-medium transition-colors',
                    done ? 'bg-wh-gold text-wh-bg' : 'border border-wh-border text-wh-mute hover:border-wh-gold'
                  ]"
                  @click="toggleRound(oi, ri)"
                >
                  {{ ri + 1 }}
                </button>
              </div>
            </div>
          </div>
          <p v-if="!entry.options.length" class="text-xs text-wh-mute">No scoring options for this secondary.</p>
        </div>
      </template>

      <div class="mt-6 flex items-center justify-between gap-3">
        <button
          type="button"
          class="text-sm text-wh-accent hover:underline"
          @click="emit('remove')"
        >
          Remove secondary
        </button>
        <button
          type="button"
          class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
          @click="emit('close')"
        >
          Close
        </button>
      </div>
    </div>
  </div>
</template>
