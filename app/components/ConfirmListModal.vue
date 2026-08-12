<script setup lang="ts">
defineProps<{ armyList: string }>()
const emit = defineEmits<{ confirm: []; cancel: [] }>()
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
    <div class="w-full max-w-lg rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="text-lg font-semibold text-wh-ink">Stämmer listan?</h2>
      <p class="mt-1 text-sm text-wh-mute">
        Kontrollera din armélista nedan innan du anmäler dig som redo.
      </p>

      <pre class="mt-4 max-h-72 overflow-y-auto whitespace-pre-wrap rounded-md border border-wh-border bg-wh-surface-alt p-3 text-sm text-wh-ink">{{ armyList }}</pre>

      <div class="mt-6 flex flex-wrap justify-end gap-3">
        <button
          type="button"
          class="rounded-md border border-wh-border px-4 py-2 text-sm text-wh-ink hover:border-wh-accent"
          @click="emit('cancel')"
        >
          Ändra listan
        </button>
        <button
          type="button"
          class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
          @click="emit('confirm')"
        >
          Bekräfta, jag är redo
        </button>
      </div>
    </div>
  </div>
</template>
