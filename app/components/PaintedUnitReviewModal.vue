<script setup lang="ts">
import type { PaintedUnitKey, PaintedUnitPhoto } from '~/types'

const props = defineProps<{
  leagueId: string
  playerName: string
  unitKey: PaintedUnitKey
  unitNumber: number
  photo: PaintedUnitPhoto
}>()
const emit = defineEmits<{ close: [] }>()

const { publicUrl, approveUnit, rejectUnit } = usePaintedUnitPhotos()

const error = ref('')
const submitting = ref(false)

const unpaintedUrl = computed(() => (props.photo.unpainted_path ? publicUrl(props.photo.unpainted_path) : null))
const paintedUrl = computed(() => (props.photo.painted_path ? publicUrl(props.photo.painted_path) : null))

async function handleApprove() {
  error.value = ''
  submitting.value = true
  try {
    await approveUnit(props.leagueId, props.photo.user_id, props.unitKey)
    emit('close')
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    submitting.value = false
  }
}

async function handleReject() {
  error.value = ''
  submitting.value = true
  try {
    await rejectUnit(props.leagueId, props.photo.user_id, props.unitKey)
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
    <div class="w-full max-w-md rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="flex items-start justify-between gap-3">
        <h2 class="text-lg font-semibold text-wh-ink">{{ playerName }} — Unit {{ unitNumber }}</h2>
        <button type="button" class="text-wh-mute hover:text-wh-accent" @click="emit('close')">✕</button>
      </div>
      <p class="mt-1 text-sm text-wh-mute">Skickades in {{ new Date(photo.submitted_at ?? '').toLocaleString() }}</p>

      <div class="mt-4 grid grid-cols-2 gap-3">
        <div>
          <p class="mb-1 text-xs text-wh-mute">Omålad</p>
          <div class="aspect-square overflow-hidden rounded-md border border-wh-border bg-wh-surface-alt">
            <img v-if="unpaintedUrl" :src="unpaintedUrl" alt="Omålad unit" class="h-full w-full object-cover">
          </div>
        </div>
        <div>
          <p class="mb-1 text-xs text-wh-mute">Målad</p>
          <div class="aspect-square overflow-hidden rounded-md border border-wh-border bg-wh-surface-alt">
            <img v-if="paintedUrl" :src="paintedUrl" alt="Målad unit" class="h-full w-full object-cover">
          </div>
        </div>
      </div>

      <p v-if="error" class="mt-3 text-sm text-wh-accent">{{ error }}</p>

      <div class="mt-4 flex gap-3">
        <button
          type="button"
          :disabled="submitting"
          class="flex-1 rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
          @click="handleApprove"
        >
          Godkänn
        </button>
        <button
          type="button"
          :disabled="submitting"
          class="flex-1 rounded-md border border-wh-border px-4 py-2 text-sm text-wh-mute hover:border-wh-accent hover:text-wh-accent disabled:opacity-50"
          @click="handleReject"
        >
          Skicka tillbaka
        </button>
      </div>
    </div>
  </div>
</template>
