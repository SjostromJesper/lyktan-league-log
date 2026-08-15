<script setup lang="ts">
import type { PaintedUnitKey, PaintedUnitPhoto } from '~/types'

const props = defineProps<{
  leagueId: string
  unitKey: PaintedUnitKey
  unitNumber: number
  photo: PaintedUnitPhoto | null
}>()
const emit = defineEmits<{ close: [] }>()

const { publicUrl, uploadPhoto, submitUnit } = usePaintedUnitPhotos()

const uploadingUnpainted = ref(false)
const uploadingPainted = ref(false)
const error = ref('')
const submitting = ref(false)

const unpaintedUrl = computed(() => (props.photo?.unpainted_path ? publicUrl(props.photo.unpainted_path) : null))
const paintedUrl = computed(() => (props.photo?.painted_path ? publicUrl(props.photo.painted_path) : null))
const canSubmit = computed(() => !!props.photo?.unpainted_path && !!props.photo?.painted_path)

async function handleUpload(kind: 'unpainted' | 'painted', event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  error.value = ''
  const busy = kind === 'unpainted' ? uploadingUnpainted : uploadingPainted
  busy.value = true
  try {
    await uploadPhoto(props.leagueId, props.unitKey, kind, file)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    busy.value = false
  }
}

async function handleSubmit() {
  error.value = ''
  submitting.value = true
  try {
    await submitUnit(props.leagueId, props.unitKey)
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
        <h2 class="text-lg font-semibold text-wh-ink">Unit {{ unitNumber }}</h2>
        <button type="button" class="text-wh-mute hover:text-wh-accent" @click="emit('close')">✕</button>
      </div>

      <p v-if="photo?.status === 'approved'" class="mt-1 text-sm text-wh-gold">✓ Godkänd</p>
      <p v-else-if="photo?.status === 'submitted'" class="mt-1 text-sm text-wh-mute">
        Skickad in — väntar på att en admin godkänner den.
      </p>
      <p v-else class="mt-1 text-sm text-wh-mute">Ladda upp en bild omålad och en målad, klicka sedan skicka in.</p>

      <div class="mt-4 grid grid-cols-2 gap-3">
        <div>
          <p class="mb-1 text-xs text-wh-mute">Omålad</p>
          <div class="aspect-square overflow-hidden rounded-md border border-wh-border bg-wh-surface-alt">
            <img v-if="unpaintedUrl" :src="unpaintedUrl" alt="Omålad unit" class="h-full w-full object-cover">
          </div>
          <label
            v-if="photo?.status !== 'submitted' && photo?.status !== 'approved'"
            class="mt-2 block cursor-pointer rounded-md border border-dashed border-wh-border px-2 py-1.5 text-center text-xs text-wh-mute hover:border-wh-accent"
          >
            {{ uploadingUnpainted ? 'Laddar upp...' : unpaintedUrl ? 'Byt bild' : '+ Ladda upp' }}
            <input type="file" accept="image/*" class="hidden" :disabled="uploadingUnpainted" @change="handleUpload('unpainted', $event)">
          </label>
        </div>
        <div>
          <p class="mb-1 text-xs text-wh-mute">Målad</p>
          <div class="aspect-square overflow-hidden rounded-md border border-wh-border bg-wh-surface-alt">
            <img v-if="paintedUrl" :src="paintedUrl" alt="Målad unit" class="h-full w-full object-cover">
          </div>
          <label
            v-if="photo?.status !== 'submitted' && photo?.status !== 'approved'"
            class="mt-2 block cursor-pointer rounded-md border border-dashed border-wh-border px-2 py-1.5 text-center text-xs text-wh-mute hover:border-wh-accent"
          >
            {{ uploadingPainted ? 'Laddar upp...' : paintedUrl ? 'Byt bild' : '+ Ladda upp' }}
            <input type="file" accept="image/*" class="hidden" :disabled="uploadingPainted" @change="handleUpload('painted', $event)">
          </label>
        </div>
      </div>

      <p v-if="error" class="mt-3 text-sm text-wh-accent">{{ error }}</p>

      <button
        v-if="photo?.status !== 'submitted' && photo?.status !== 'approved'"
        type="button"
        :disabled="!canSubmit || submitting"
        class="mt-4 w-full rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
        @click="handleSubmit"
      >
        {{ submitting ? 'Skickar...' : 'Skicka in för godkännande' }}
      </button>
      <button
        v-else
        type="button"
        class="mt-4 w-full rounded-md border border-wh-border px-4 py-2 text-sm text-wh-ink hover:border-wh-accent"
        @click="emit('close')"
      >
        Stäng
      </button>
    </div>
  </div>
</template>
