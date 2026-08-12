<script setup lang="ts">
const props = defineProps<{
  playerName: string
  candidates: { id: string; name: string }[]
}>()
const emit = defineEmits<{ confirm: [opponentId: string]; cancel: [] }>()

const selected = ref<{ id: string; name: string } | null>(null)
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
    <div class="w-full max-w-md rounded-lg border border-wh-border bg-wh-surface p-6">
      <template v-if="!selected">
        <h2 class="text-lg font-semibold text-wh-ink">Ingen ny motståndare</h2>
        <p class="mt-1 text-sm text-wh-mute">
          {{ playerName }} har redan mött alla som är redo just nu. Välj en motståndare manuellt om du vill matcha om dem.
        </p>
        <ul class="mt-4 max-h-64 space-y-2 overflow-y-auto">
          <li v-for="c in props.candidates" :key="c.id">
            <button
              type="button"
              class="w-full rounded-md border border-wh-border px-3 py-2 text-left text-sm text-wh-ink hover:border-wh-accent"
              @click="selected = c"
            >
              {{ c.name }}
            </button>
          </li>
          <li v-if="!props.candidates.length" class="text-sm text-wh-mute">Ingen annan är redo just nu.</li>
        </ul>
        <div class="mt-4 flex justify-end">
          <button
            type="button"
            class="rounded-md border border-wh-border px-4 py-2 text-sm text-wh-ink hover:border-wh-accent"
            @click="emit('cancel')"
          >
            Avbryt
          </button>
        </div>
      </template>

      <template v-else>
        <h2 class="text-lg font-semibold text-wh-ink">Bekräfta ommatchning</h2>
        <p class="mt-1 text-sm text-wh-ink">
          Är du säker på att du vill matcha <strong>{{ playerName }}</strong> mot <strong>{{ selected.name }}</strong>?
          De har mötts tidigare.
        </p>
        <div class="mt-4 flex justify-end gap-3">
          <button
            type="button"
            class="rounded-md border border-wh-border px-4 py-2 text-sm text-wh-ink hover:border-wh-accent"
            @click="emit('cancel')"
          >
            Avbryt
          </button>
          <button
            type="button"
            class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
            @click="emit('confirm', selected.id)"
          >
            Ja, matcha dem
          </button>
        </div>
      </template>
    </div>
  </div>
</template>
