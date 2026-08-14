<script setup lang="ts">
export interface SecondaryEntry {
  name: string
  discarded: boolean
  expanded: boolean
  pointsPerRound: number | null
  roundsCompleted: boolean[]
}

defineProps<{ label: string; entries: SecondaryEntry[]; available: string[] }>()
const emit = defineEmits<{ add: [name: string]; remove: [index: number] }>()

function entryPoints(entry: SecondaryEntry) {
  if (entry.discarded) return 0
  const completedCount = entry.roundsCompleted.filter(Boolean).length
  return completedCount * (entry.pointsPerRound ?? 0)
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

        <div v-if="entry.expanded && !entry.discarded" class="space-y-3 border-t border-wh-border p-3">
          <div class="w-28">
            <label class="mb-1 block text-xs text-wh-mute">Poäng per runda</label>
            <input
              v-model.number="entry.pointsPerRound"
              type="number"
              min="0"
              class="w-full rounded-md border border-wh-border bg-wh-surface px-2 py-1 text-sm text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
          <div>
            <p class="mb-1 text-xs text-wh-mute">Klar i runda</p>
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
