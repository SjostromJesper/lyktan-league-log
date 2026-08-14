<script setup lang="ts">
interface LeaguePayload {
  name: string
  description: string
  phaseCount: number
  matchesPerPhase: number
}

const props = defineProps<{
  mode: 'create' | 'edit'
  initialName?: string
  initialDescription?: string
  initialPhaseCount?: number
  initialMatchesPerPhase?: number
  onSubmit: (payload: LeaguePayload) => Promise<void>
}>()
const emit = defineEmits<{ close: [] }>()

const name = ref(props.initialName ?? '')
const description = ref(props.initialDescription ?? '')
const phaseCount = ref(props.initialPhaseCount ?? 1)
const matchesPerPhase = ref(props.initialMatchesPerPhase ?? 3)
const error = ref('')
const submitting = ref(false)

async function submit() {
  error.value = ''
  if (!name.value.trim()) {
    error.value = 'Ligan måste ha ett namn.'
    return
  }
  submitting.value = true
  try {
    await props.onSubmit({
      name: name.value,
      description: description.value,
      phaseCount: phaseCount.value,
      matchesPerPhase: matchesPerPhase.value
    })
    emit('close')
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" @click.self="emit('close')">
    <div class="w-full max-w-lg rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="text-lg font-semibold text-wh-ink">{{ mode === 'create' ? 'Ny liga' : 'Redigera liga' }}</h2>

      <form class="mt-4 space-y-3" @submit.prevent="submit">
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Namn</label>
          <input
            v-model="name"
            type="text"
            required
            placeholder="T.ex. Liga 1 2026"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Beskrivning (valfritt)</label>
          <textarea
            v-model="description"
            rows="2"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          />
        </div>
        <div class="flex gap-3">
          <div class="w-32">
            <label class="mb-1 block text-sm text-wh-mute">Antal faser</label>
            <input
              v-model.number="phaseCount"
              type="number"
              min="1"
              required
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
          <div class="w-32">
            <label class="mb-1 block text-sm text-wh-mute">Matcher per fas</label>
            <input
              v-model.number="matchesPerPhase"
              type="number"
              min="1"
              required
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
        </div>
        <p v-if="error" class="text-sm text-wh-accent">{{ error }}</p>
        <div class="flex justify-end gap-3 pt-2">
          <button
            type="button"
            class="rounded-md border border-wh-border px-4 py-2 text-sm text-wh-ink hover:border-wh-accent"
            @click="emit('close')"
          >
            Avbryt
          </button>
          <button
            type="submit"
            :disabled="submitting"
            class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
          >
            {{ mode === 'create' ? 'Skapa' : 'Spara' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
