<script setup lang="ts">
export interface SecondaryStep {
  label: string
  points: number
  done: boolean
}

export interface SecondaryEntry {
  name: string
  discarded: boolean
  expanded: boolean
  steps: SecondaryStep[]
  stepDraftLabel: string
  stepDraftPoints: number | null
}

defineProps<{ label: string; entries: SecondaryEntry[]; available: string[] }>()
const emit = defineEmits<{ add: [name: string]; remove: [index: number] }>()

function entryPoints(entry: SecondaryEntry) {
  if (entry.discarded) return 0
  return entry.steps.filter(s => s.done).reduce((sum, s) => sum + s.points, 0)
}

function addStep(entry: SecondaryEntry) {
  const label = entry.stepDraftLabel.trim()
  const points = entry.stepDraftPoints
  if (!label || !points || points <= 0) return
  entry.steps.push({ label, points, done: false })
  entry.stepDraftLabel = ''
  entry.stepDraftPoints = null
}

function removeStep(entry: SecondaryEntry, index: number) {
  entry.steps.splice(index, 1)
}

function handleAdd(event: Event) {
  const select = event.target as HTMLSelectElement
  const value = select.value
  select.value = ''
  if (!value) return
  emit('add', value)
}
</script>

<template>
  <div>
    <p class="mb-1 text-xs text-wh-mute">{{ label }}</p>
    <ul class="space-y-2">
      <li
        v-for="(entry, i) in entries"
        :key="entry.name"
        class="overflow-hidden rounded-md border border-wh-border"
        :class="entry.discarded ? 'opacity-50' : ''"
      >
        <div class="flex items-center gap-2 bg-wh-surface-alt px-3 py-2">
          <button
            type="button"
            class="flex-1 text-left text-sm text-wh-ink"
            @click="entry.expanded = !entry.expanded"
          >
            {{ entry.name }}
            <span v-if="entry.discarded" class="ml-1 text-xs text-wh-mute">(discardad)</span>
            <span v-else-if="entryPoints(entry)" class="ml-1 text-xs text-wh-gold">{{ entryPoints(entry) }}p</span>
          </button>
          <button
            type="button"
            class="shrink-0 text-xs text-wh-mute hover:text-wh-accent"
            @click="entry.discarded = !entry.discarded"
          >
            {{ entry.discarded ? 'Återställ' : 'Discarda' }}
          </button>
          <button type="button" class="shrink-0 text-wh-mute hover:text-wh-accent" @click="emit('remove', i)">✕</button>
        </div>

        <div v-if="entry.expanded && !entry.discarded" class="space-y-2 border-t border-wh-border p-3">
          <label
            v-for="(step, si) in entry.steps"
            :key="si"
            class="flex items-center justify-between gap-2 text-sm text-wh-ink"
          >
            <span class="flex items-center gap-2">
              <input v-model="step.done" type="checkbox" class="accent-wh-accent">
              {{ step.label }} ({{ step.points }}p)
            </span>
            <button type="button" class="text-xs text-wh-mute hover:text-wh-accent" @click="removeStep(entry, si)">
              ✕
            </button>
          </label>
          <p v-if="!entry.steps.length" class="text-xs text-wh-mute">Inga steg tillagda än.</p>

          <div class="flex flex-wrap items-end gap-2 pt-1">
            <div class="flex-1">
              <label class="mb-1 block text-xs text-wh-mute">Steg</label>
              <input
                v-model="entry.stepDraftLabel"
                type="text"
                placeholder="T.ex. Runda 1"
                class="w-full rounded-md border border-wh-border bg-wh-surface px-2 py-1 text-sm text-wh-ink outline-none focus:border-wh-accent"
              >
            </div>
            <div class="w-20">
              <label class="mb-1 block text-xs text-wh-mute">Poäng</label>
              <input
                v-model.number="entry.stepDraftPoints"
                type="number"
                min="1"
                class="w-full rounded-md border border-wh-border bg-wh-surface px-2 py-1 text-sm text-wh-ink outline-none focus:border-wh-accent"
              >
            </div>
            <button
              type="button"
              class="rounded-md border border-wh-border px-2 py-1 text-xs text-wh-ink hover:border-wh-accent"
              @click="addStep(entry)"
            >
              + Lägg till steg
            </button>
          </div>
        </div>
      </li>
    </ul>

    <select
      value=""
      class="mt-2 w-full rounded-md border border-dashed border-wh-border bg-wh-surface-alt px-3 py-2 text-sm text-wh-mute outline-none focus:border-wh-accent"
      @change="handleAdd"
    >
      <option value="" disabled selected>+ Lägg till secondary</option>
      <option v-for="s in available" :key="s" :value="s">{{ s }}</option>
    </select>
  </div>
</template>
