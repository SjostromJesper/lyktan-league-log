<script setup lang="ts">
export interface SecondaryOption {
  label: string
  points: number | null
  roundsCompleted: boolean[]
}

export interface SecondaryEntry {
  name: string
  discarded: boolean
  notes: string
  options: SecondaryOption[]
}

const props = defineProps<{
  label: string
  entries: SecondaryEntry[]
  available: string[]
  maxPointsPerRound: number
}>()
const emit = defineEmits<{ add: [name: string]; remove: [index: number] }>()

function entryPoints(entry: SecondaryEntry) {
  if (entry.discarded) return 0
  return entry.options.reduce((sum, o) => sum + o.roundsCompleted.filter(Boolean).length * (o.points ?? 0), 0)
}

function handleAdd(event: Event) {
  const select = event.target as HTMLSelectElement
  const value = select.value
  select.value = ''
  if (!value) return
  emit('add', value)
}

const openIndex = ref<number | null>(null)

function handleRemoveOpen() {
  if (openIndex.value === null) return
  emit('remove', openIndex.value)
  openIndex.value = null
}
</script>

<template>
  <div>
    <p class="mb-1 text-xs text-wh-mute">{{ label }}</p>
    <ul class="space-y-1">
      <li
        v-for="(entry, i) in entries"
        :key="entry.name"
        class="rounded-md border border-wh-border bg-wh-surface-alt"
        :class="entry.discarded ? 'opacity-50' : ''"
      >
        <button
          type="button"
          class="block w-full px-3 py-2 text-left text-sm text-wh-ink"
          @click="openIndex = i"
        >
          {{ entry.name }}
          <span v-if="entry.discarded" class="ml-1 text-xs text-wh-mute">(discardad)</span>
          <span v-else-if="entryPoints(entry)" class="ml-1 text-xs text-wh-gold">{{ entryPoints(entry) }}p</span>
        </button>
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

    <SecondaryDetailModal
      v-if="openIndex !== null"
      :entry="entries[openIndex]"
      :max-points-per-round="maxPointsPerRound"
      @close="openIndex = null"
      @remove="handleRemoveOpen"
    />
  </div>
</template>
