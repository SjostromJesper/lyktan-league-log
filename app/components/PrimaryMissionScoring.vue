<script setup lang="ts">
export interface PrimaryMissionOption {
  label: string
  points: number
  timing: string
  rounds: number[]
  roundsCompleted: boolean[]
}

const props = defineProps<{
  label: string
  name: string
  description: string
  options: PrimaryMissionOption[]
  maxPointsPerRound: number
}>()

const activeRound = ref(1)
const showModal = ref(false)

const roundOptions = computed(() => props.options.filter(o => o.rounds.includes(activeRound.value)))
const roundTotal = computed(() =>
  roundOptions.value.reduce((sum, o) => (o.roundsCompleted[activeRound.value - 1] ? sum + o.points : sum), 0)
)

const missionTotal = computed(() => {
  let total = 0
  for (let round = 1; round <= 5; round++) {
    const pts = props.options.reduce((sum, o) => (o.roundsCompleted[round - 1] ? sum + o.points : sum), 0)
    total += Math.min(props.maxPointsPerRound, pts)
  }
  return total
})
</script>

<template>
  <div class="rounded-md border border-wh-gold/50 bg-wh-surface-alt p-3 text-sm text-wh-ink">
    <p class="text-xs text-wh-mute">{{ label }}</p>
    <button type="button" class="mt-1 flex w-full items-center justify-between gap-2 text-left" @click="showModal = true">
      <span class="font-semibold text-wh-gold hover:underline">{{ name }}</span>
      <span v-if="missionTotal" class="shrink-0 text-xs text-wh-gold">{{ missionTotal }}p</span>
    </button>

    <div
      v-if="showModal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      @click.self="showModal = false"
    >
      <div class="w-full max-w-md rounded-lg border border-wh-border bg-wh-surface p-6">
        <div class="flex items-start justify-between gap-3">
          <h2 class="text-lg font-semibold text-wh-ink">{{ name }}</h2>
          <button type="button" class="text-wh-mute hover:text-wh-accent" @click="showModal = false">✕</button>
        </div>
        <p v-if="description" class="mt-1 text-sm text-wh-mute">{{ description }}</p>

        <div class="mt-4 flex gap-1">
          <button
            v-for="r in 5"
            :key="r"
            type="button"
            :class="[
              'flex h-8 w-8 items-center justify-center rounded-md text-sm font-medium transition-colors',
              activeRound === r ? 'bg-wh-gold text-wh-bg' : 'border border-wh-border text-wh-mute hover:border-wh-gold'
            ]"
            @click="activeRound = r"
          >
            {{ r }}
          </button>
        </div>

        <div class="mt-3 space-y-1.5">
          <label
            v-for="(opt, oi) in roundOptions"
            :key="oi"
            class="flex items-start justify-between gap-2 rounded-md border border-wh-border bg-wh-surface-alt px-2 py-1.5 text-xs text-wh-ink"
          >
            <span class="flex items-start gap-2">
              <input v-model="opt.roundsCompleted[activeRound - 1]" type="checkbox" class="mt-0.5 accent-wh-accent">
              {{ opt.label }}
            </span>
            <span class="shrink-0 text-wh-gold">{{ opt.points }}p</span>
          </label>
          <p v-if="!roundOptions.length" class="text-xs text-wh-mute">No scoring options this round.</p>
        </div>

        <p class="mt-2 text-xs text-wh-mute">
          Round {{ activeRound }} total: {{ Math.min(roundTotal, maxPointsPerRound) }}p
        </p>

        <button
          type="button"
          class="mt-6 w-full rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
          @click="showModal = false"
        >
          Close
        </button>
      </div>
    </div>
  </div>
</template>
