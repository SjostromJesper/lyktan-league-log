<script setup lang="ts">
withDefaults(defineProps<{ title: string; defaultOpen?: boolean; badge?: string | number }>(), {
  defaultOpen: false,
  badge: undefined
})
</script>

<template>
  <details class="group overflow-hidden rounded-lg border border-wh-border bg-wh-surface" :open="defaultOpen">
    <summary class="flex list-none cursor-pointer items-center justify-between gap-3 p-6 select-none">
      <span class="flex items-center gap-2">
        <span class="text-lg font-medium text-wh-ink">{{ title }}</span>
        <span
          v-if="badge !== undefined && badge !== 0 && badge !== ''"
          class="rounded-full bg-wh-accent px-2 py-0.5 text-xs font-semibold text-white"
        >
          {{ badge }}
        </span>
      </span>
      <svg
        class="h-5 w-5 shrink-0 text-wh-mute transition-transform duration-150 group-open:rotate-180"
        viewBox="0 0 20 20"
        fill="currentColor"
      >
        <path
          fill-rule="evenodd"
          d="M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.24 4.25a.75.75 0 01-1.06 0L5.21 8.29a.75.75 0 01.02-1.08z"
          clip-rule="evenodd"
        />
      </svg>
    </summary>
    <div class="border-t border-wh-border p-6 pt-4">
      <slot />
    </div>
  </details>
</template>
