<script setup lang="ts">
import type { SecondaryEntry } from './SecondaryTracker.vue'

defineProps<{ entry: SecondaryEntry; maxPointsPerRound: number }>()
const emit = defineEmits<{ close: []; remove: [] }>()
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" @click.self="emit('close')">
    <div class="w-full max-w-md rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="flex items-start justify-between gap-3">
        <h2 class="text-lg font-semibold text-wh-ink">{{ entry.name }}</h2>
        <button type="button" class="text-wh-mute hover:text-wh-accent" @click="emit('close')">✕</button>
      </div>

      <label class="mt-4 flex items-center gap-2 text-sm text-wh-ink">
        <input v-model="entry.discarded" type="checkbox" class="accent-wh-accent">
        Discardad
      </label>

      <template v-if="!entry.discarded">
        <div class="mt-4">
          <label class="mb-1 block text-sm text-wh-mute">Anteckningar</label>
          <textarea
            v-model="entry.notes"
            rows="3"
            placeholder="Egna anteckningar om hur du scorar den här secondaryn..."
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-sm text-wh-ink outline-none focus:border-wh-accent"
          />
        </div>

        <div class="mt-4 w-32">
          <label class="mb-1 block text-sm text-wh-mute">Poäng per runda</label>
          <input
            v-model.number="entry.pointsPerRound"
            type="number"
            min="0"
            :max="maxPointsPerRound"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-sm text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>

        <div class="mt-4">
          <p class="mb-1 text-sm text-wh-mute">Klar i runda</p>
          <div class="flex gap-2">
            <button
              v-for="(done, ri) in entry.roundsCompleted"
              :key="ri"
              type="button"
              :title="`Runda ${ri + 1}`"
              :class="[
                'flex h-9 w-9 items-center justify-center rounded-md text-sm font-medium transition-colors',
                done ? 'bg-wh-gold text-wh-bg' : 'border border-wh-border text-wh-mute hover:border-wh-gold'
              ]"
              @click="entry.roundsCompleted[ri] = !entry.roundsCompleted[ri]"
            >
              {{ ri + 1 }}
            </button>
          </div>
        </div>
      </template>

      <div class="mt-6 flex items-center justify-between gap-3">
        <button
          type="button"
          class="text-sm text-wh-accent hover:underline"
          @click="emit('remove')"
        >
          Ta bort secondary
        </button>
        <button
          type="button"
          class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
          @click="emit('close')"
        >
          Stäng
        </button>
      </div>
    </div>
  </div>
</template>
