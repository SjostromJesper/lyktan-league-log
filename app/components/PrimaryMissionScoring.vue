<script setup lang="ts">
import {
  primaryMissionTotal,
  primaryOptionPoints,
  primaryRoundPoints,
  setTierGroupCount,
  tierGroupCount,
  tierGroupOptions,
  type PrimaryMissionOption
} from '~/utils/primaryScoring'

export type { PrimaryMissionOption }

const props = defineProps<{
  label: string
  name: string
  description: string
  options: PrimaryMissionOption[]
  maxPointsPerRound: number
}>()

const activeRound = ref(1)
const showDescription = ref(false)
const showModal = ref(false)

const roundOptions = computed(() => props.options.filter(o => o.rounds.includes(activeRound.value)))
const roundTotal = computed(() => primaryRoundPoints(props.options, activeRound.value))
const missionTotal = computed(() => primaryMissionTotal(props.options, props.maxPointsPerRound))

type RoundItem = { kind: 'tier'; tierGroup: string } | { kind: 'flat'; option: PrimaryMissionOption }

const roundItems = computed<RoundItem[]>(() => {
  const items: RoundItem[] = []
  const seenGroups = new Set<string>()
  for (const o of roundOptions.value) {
    if (o.tierGroup) {
      if (!seenGroups.has(o.tierGroup)) {
        seenGroups.add(o.tierGroup)
        items.push({ kind: 'tier', tierGroup: o.tierGroup })
      }
    } else {
      items.push({ kind: 'flat', option: o })
    }
  }
  return items
})

function tierMax(tierGroup: string) {
  const opts = tierGroupOptions(props.options, tierGroup)
  return Math.max(...opts.map(o => o.tierCount ?? 0))
}

function tierCount(tierGroup: string) {
  return tierGroupCount(props.options, tierGroup, activeRound.value)
}

function tierLabel(tierGroup: string) {
  const opts = tierGroupOptions(props.options, tierGroup)
  const count = tierCount(tierGroup)
  return (opts.find(o => o.tierCount === count) ?? opts[0])?.label ?? ''
}

function tierPoints(tierGroup: string) {
  const count = tierCount(tierGroup)
  if (!count) return 0
  const opts = tierGroupOptions(props.options, tierGroup)
  return opts.find(o => o.tierCount === count)?.points ?? 0
}

function stepTier(tierGroup: string, delta: number) {
  const next = Math.max(0, Math.min(tierMax(tierGroup), tierCount(tierGroup) + delta))
  setTierGroupCount(props.options, tierGroup, activeRound.value, next)
}

function displayPoints(opt: PrimaryMissionOption) {
  if (opt.scalesWithTierGroup) {
    const parts = []
    if (opt.points) parts.push(`${opt.points}p`)
    if (opt.scaleRate) parts.push(`${opt.scaleRate}p/obj`)
    return parts.join(' + ') || '0p'
  }
  return `${primaryOptionPoints(opt, props.options, activeRound.value)}p`
}

function toggleFlat(opt: PrimaryMissionOption) {
  opt.roundsCompleted[activeRound.value - 1] = !opt.roundsCompleted[activeRound.value - 1]
}
</script>

<template>
  <!-- Small screens: the whole card is a button that opens a combined modal. -->
  <button
    type="button"
    class="block w-full rounded-md border border-wh-gold/50 bg-wh-surface-alt p-3 text-left text-sm text-wh-ink sm:hidden"
    @click="showModal = true"
  >
    <p class="text-xs text-wh-mute">{{ label }}</p>
    <span class="mt-1 flex items-center justify-between gap-2">
      <span class="font-semibold text-wh-gold">{{ name }}</span>
      <span v-if="missionTotal" class="shrink-0 text-xs text-wh-gold">{{ missionTotal }}p</span>
    </span>
  </button>

  <!-- sm and up: inline round tabs + checklist, name opens a description-only modal. -->
  <div class="hidden rounded-md border border-wh-gold/50 bg-wh-surface-alt p-3 text-sm text-wh-ink sm:block">
    <p class="text-xs text-wh-mute">{{ label }}</p>
    <button type="button" class="mt-1 font-semibold text-wh-gold hover:underline" @click="showDescription = true">
      {{ name }}
    </button>

    <div class="mt-3 flex gap-1">
      <button
        v-for="r in 5"
        :key="r"
        type="button"
        :class="[
          'flex h-7 w-7 items-center justify-center rounded-md text-xs font-medium transition-colors',
          activeRound === r ? 'bg-wh-gold text-wh-bg' : 'border border-wh-border text-wh-mute hover:border-wh-gold'
        ]"
        @click="activeRound = r"
      >
        {{ r }}
      </button>
    </div>

    <div class="mt-2 space-y-1.5">
      <template v-for="item in roundItems" :key="item.kind === 'tier' ? item.tierGroup : item.option.label">
        <div
          v-if="item.kind === 'tier'"
          class="rounded-md border px-2 py-1.5 text-xs transition-colors"
          :class="tierCount(item.tierGroup) ? 'border-wh-gold bg-wh-gold/10 text-wh-ink' : 'border-wh-border bg-wh-surface text-wh-ink'"
        >
          <div class="flex items-start justify-between gap-2">
            <span>{{ tierLabel(item.tierGroup) }}</span>
            <span class="shrink-0 text-wh-gold">{{ tierPoints(item.tierGroup) }}p</span>
          </div>
          <div class="mt-1.5 flex items-center gap-2">
            <button
              type="button"
              class="flex h-6 w-6 items-center justify-center rounded-md border border-wh-border text-wh-mute hover:border-wh-gold hover:text-wh-ink disabled:opacity-30"
              :disabled="tierCount(item.tierGroup) === 0"
              @click="stepTier(item.tierGroup, -1)"
            >
              −
            </button>
            <span class="w-6 text-center font-semibold text-wh-ink">
              {{ tierCount(item.tierGroup) }}{{ tierCount(item.tierGroup) === tierMax(item.tierGroup) ? '+' : '' }}
            </span>
            <button
              type="button"
              class="flex h-6 w-6 items-center justify-center rounded-md border border-wh-border text-wh-mute hover:border-wh-gold hover:text-wh-ink disabled:opacity-30"
              :disabled="tierCount(item.tierGroup) === tierMax(item.tierGroup)"
              @click="stepTier(item.tierGroup, 1)"
            >
              +
            </button>
          </div>
        </div>

        <label
          v-else
          class="flex cursor-pointer items-start justify-between gap-2 rounded-md border px-2 py-1.5 text-xs transition-colors"
          :class="
            item.option.roundsCompleted[activeRound - 1]
              ? 'border-wh-gold bg-wh-gold/10 text-wh-ink'
              : 'border-wh-border bg-wh-surface text-wh-ink hover:border-wh-gold/50'
          "
        >
          <span class="flex items-start gap-2">
            <input
              type="checkbox"
              :checked="item.option.roundsCompleted[activeRound - 1]"
              class="sr-only"
              @click.prevent="toggleFlat(item.option)"
            >
            <span
              class="mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-sm border transition-colors"
              :class="item.option.roundsCompleted[activeRound - 1] ? 'border-wh-gold bg-wh-gold' : 'border-wh-mute'"
            >
              <span v-if="item.option.roundsCompleted[activeRound - 1]" class="text-[10px] leading-none text-wh-bg">✓</span>
            </span>
            {{ item.option.label }}
          </span>
          <span class="shrink-0 text-wh-gold">{{ displayPoints(item.option) }}</span>
        </label>
      </template>
      <p v-if="!roundItems.length" class="text-xs text-wh-mute">No scoring options this round.</p>
    </div>

    <p class="mt-2 text-xs text-wh-mute">
      Round {{ activeRound }} total: {{ Math.min(roundTotal, maxPointsPerRound) }}p
    </p>
  </div>

  <!-- Description-only modal, used on sm and up. -->
  <div
    v-if="showDescription"
    class="fixed inset-0 z-50 hidden items-center justify-center bg-black/70 p-4 sm:flex"
    @click.self="showDescription = false"
  >
    <div class="w-full max-w-md rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="flex items-start justify-between gap-3">
        <h2 class="text-lg font-semibold text-wh-ink">{{ name }}</h2>
        <button type="button" class="text-wh-mute hover:text-wh-accent" @click="showDescription = false">✕</button>
      </div>
      <p class="mt-2 text-sm text-wh-mute">{{ description }}</p>
      <button
        type="button"
        class="mt-6 w-full rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
        @click="showDescription = false"
      >
        Close
      </button>
    </div>
  </div>

  <!-- Combined modal (description + round tabs + checklist), used below sm. -->
  <div
    v-if="showModal"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 sm:hidden"
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
        <template v-for="item in roundItems" :key="item.kind === 'tier' ? item.tierGroup : item.option.label">
          <div
            v-if="item.kind === 'tier'"
            class="rounded-md border px-2 py-1.5 text-xs transition-colors"
            :class="tierCount(item.tierGroup) ? 'border-wh-gold bg-wh-gold/10 text-wh-ink' : 'border-wh-border bg-wh-surface-alt text-wh-ink'"
          >
            <div class="flex items-start justify-between gap-2">
              <span>{{ tierLabel(item.tierGroup) }}</span>
              <span class="shrink-0 text-wh-gold">{{ tierPoints(item.tierGroup) }}p</span>
            </div>
            <div class="mt-1.5 flex items-center gap-2">
              <button
                type="button"
                class="flex h-7 w-7 items-center justify-center rounded-md border border-wh-border text-wh-mute hover:border-wh-gold hover:text-wh-ink disabled:opacity-30"
                :disabled="tierCount(item.tierGroup) === 0"
                @click="stepTier(item.tierGroup, -1)"
              >
                −
              </button>
              <span class="w-6 text-center font-semibold text-wh-ink">
                {{ tierCount(item.tierGroup) }}{{ tierCount(item.tierGroup) === tierMax(item.tierGroup) ? '+' : '' }}
              </span>
              <button
                type="button"
                class="flex h-7 w-7 items-center justify-center rounded-md border border-wh-border text-wh-mute hover:border-wh-gold hover:text-wh-ink disabled:opacity-30"
                :disabled="tierCount(item.tierGroup) === tierMax(item.tierGroup)"
                @click="stepTier(item.tierGroup, 1)"
              >
                +
              </button>
            </div>
          </div>

          <label
            v-else
            class="flex cursor-pointer items-start justify-between gap-2 rounded-md border px-2 py-1.5 text-xs transition-colors"
            :class="
              item.option.roundsCompleted[activeRound - 1]
                ? 'border-wh-gold bg-wh-gold/10 text-wh-ink'
                : 'border-wh-border bg-wh-surface-alt text-wh-ink hover:border-wh-gold/50'
            "
          >
            <span class="flex items-start gap-2">
              <input
                type="checkbox"
                :checked="item.option.roundsCompleted[activeRound - 1]"
                class="sr-only"
                @click.prevent="toggleFlat(item.option)"
              >
              <span
                class="mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-sm border transition-colors"
                :class="item.option.roundsCompleted[activeRound - 1] ? 'border-wh-gold bg-wh-gold' : 'border-wh-mute'"
              >
                <span v-if="item.option.roundsCompleted[activeRound - 1]" class="text-[10px] leading-none text-wh-bg">✓</span>
              </span>
              {{ item.option.label }}
            </span>
            <span class="shrink-0 text-wh-gold">{{ displayPoints(item.option) }}</span>
          </label>
        </template>
        <p v-if="!roundItems.length" class="text-xs text-wh-mute">No scoring options this round.</p>
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
</template>
