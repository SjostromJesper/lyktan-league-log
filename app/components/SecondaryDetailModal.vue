<script setup lang="ts">
import type { SecondaryEntry } from './SecondaryTracker.vue'

const props = defineProps<{ entry: SecondaryEntry; maxPointsPerRound: number; description: string }>()
const emit = defineEmits<{ close: []; remove: [] }>()

function addOption() {
  props.entry.options.push({ label: '', points: null, roundsCompleted: Array.from({ length: 5 }, () => false) })
}

function removeOption(index: number) {
  props.entry.options.splice(index, 1)
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

        <div class="mt-4 space-y-3">
          <p class="text-sm text-wh-mute">Alternativ</p>
          <div v-for="(opt, oi) in entry.options" :key="oi" class="rounded-md border border-wh-border p-3">
            <div class="flex items-center gap-2">
              <input
                v-model="opt.label"
                type="text"
                placeholder="T.ex. 1 mål cleansat"
                class="flex-1 rounded-md border border-wh-border bg-wh-surface-alt px-2 py-1 text-sm text-wh-ink outline-none focus:border-wh-accent"
              >
              <button type="button" class="shrink-0 text-wh-mute hover:text-wh-accent" @click="removeOption(oi)">
                ✕
              </button>
            </div>
            <div class="mt-2 flex flex-wrap items-end gap-3">
              <div class="w-20">
                <label class="mb-1 block text-xs text-wh-mute">Poäng</label>
                <input
                  v-model.number="opt.points"
                  type="number"
                  min="0"
                  :max="maxPointsPerRound"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-2 py-1 text-sm text-wh-ink outline-none focus:border-wh-accent"
                >
              </div>
              <div>
                <label class="mb-1 block text-xs text-wh-mute">Klar i runda</label>
                <div class="flex gap-1">
                  <button
                    v-for="(done, ri) in opt.roundsCompleted"
                    :key="ri"
                    type="button"
                    :title="`Runda ${ri + 1}`"
                    :class="[
                      'flex h-8 w-8 items-center justify-center rounded-md text-sm font-medium transition-colors',
                      done ? 'bg-wh-gold text-wh-bg' : 'border border-wh-border text-wh-mute hover:border-wh-gold'
                    ]"
                    @click="opt.roundsCompleted[ri] = !opt.roundsCompleted[ri]"
                  >
                    {{ ri + 1 }}
                  </button>
                </div>
              </div>
            </div>
          </div>
          <p v-if="!entry.options.length" class="text-xs text-wh-mute">Inga alternativ tillagda än.</p>
          <button
            type="button"
            class="rounded-md border border-dashed border-wh-border px-3 py-1.5 text-xs text-wh-ink hover:border-wh-accent"
            @click="addOption"
          >
            + Lägg till alternativ
          </button>
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
