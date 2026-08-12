<script setup lang="ts">
defineProps<{ title: string; armyList: string }>()
const emit = defineEmits<{ close: [] }>()
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" @click.self="emit('close')">
    <div class="w-full max-w-lg rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="text-lg font-semibold text-wh-ink">{{ title }}</h2>

      <pre class="mt-4 max-h-[60vh] overflow-y-auto whitespace-pre-wrap rounded-md border border-wh-border bg-wh-surface-alt p-3 text-sm text-wh-ink">{{ armyList }}</pre>

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
