<script setup lang="ts">
import type { League } from '~/types'

interface AccountPayload {
  name: string
  army: string
  email: string
  password: string
  leagueIds: string[]
}

const props = defineProps<{
  allLeagues: League[]
  onSubmit: (payload: AccountPayload) => Promise<void>
}>()
const emit = defineEmits<{ close: [] }>()

const name = ref('')
const army = ref('')
const email = ref('')
const password = ref('')
const selectedLeagueIds = ref<string[]>([])
const error = ref('')
const submitting = ref(false)

const created = ref<{ name: string; email: string; password: string } | null>(null)
const copyMessage = ref('')

async function submit() {
  error.value = ''
  submitting.value = true
  try {
    await props.onSubmit({
      name: name.value,
      army: army.value,
      email: email.value,
      password: password.value,
      leagueIds: selectedLeagueIds.value
    })
    created.value = { name: name.value, email: email.value, password: password.value }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    submitting.value = false
  }
}

async function copyCredentials() {
  if (!created.value) return
  const { name, email, password } = created.value
  const text = `Hej ${name}! Ditt konto till Lyktan League Log:\nURL: ${window.location.origin}\nE-post: ${email}\nLösenord: ${password}\n\nLogga in och byt lösenord under Inställningar.`
  try {
    await navigator.clipboard.writeText(text)
    copyMessage.value = 'Kopierat!'
  } catch {
    copyMessage.value = 'Kunde inte kopiera automatiskt, markera texten manuellt.'
  }
}

function reset() {
  created.value = null
  name.value = ''
  army.value = ''
  email.value = ''
  password.value = ''
  selectedLeagueIds.value = []
  copyMessage.value = ''
}
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" @click.self="emit('close')">
    <div class="w-full max-w-lg rounded-lg border border-wh-border bg-wh-surface p-6">
      <template v-if="!created">
        <h2 class="text-lg font-semibold text-wh-ink">Skapa spelarkonto</h2>
        <p class="mt-1 text-sm text-wh-mute">
          Sätt ett tillfälligt lösenord och dela det själv med spelaren (Discord, SMS, i person). Spelaren måste
          byta det vid första inloggning.
        </p>

        <form class="mt-4 grid gap-3 sm:grid-cols-2" @submit.prevent="submit">
          <div>
            <label class="mb-1 block text-sm text-wh-mute">Namn</label>
            <input
              v-model="name"
              type="text"
              required
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
          <div>
            <label class="mb-1 block text-sm text-wh-mute">Armé (valfritt)</label>
            <input
              v-model="army"
              type="text"
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
          <div>
            <label class="mb-1 block text-sm text-wh-mute">E-post</label>
            <input
              v-model="email"
              type="email"
              required
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
          <div>
            <label class="mb-1 block text-sm text-wh-mute">Tillfälligt lösenord</label>
            <input
              v-model="password"
              type="text"
              required
              minlength="6"
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
          <div class="sm:col-span-2">
            <label class="mb-1 block text-sm text-wh-mute">Lägg till i ligor (valfritt)</label>
            <div class="max-h-32 space-y-1 overflow-y-auto">
              <label v-for="l in allLeagues" :key="l.id" class="flex items-center gap-2 text-sm text-wh-ink">
                <input v-model="selectedLeagueIds" type="checkbox" :value="l.id" class="accent-wh-accent">
                {{ l.name }}
                <span v-if="l.is_active" class="text-xs text-wh-gold">Aktiv</span>
                <span v-if="l.is_archived" class="text-xs text-wh-mute">Arkiverad</span>
              </label>
              <p v-if="!allLeagues.length" class="text-sm text-wh-mute">Inga ligor skapade än.</p>
            </div>
          </div>
          <p v-if="error" class="text-sm text-wh-accent sm:col-span-2">{{ error }}</p>
          <div class="flex justify-end gap-3 pt-2 sm:col-span-2">
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
              {{ submitting ? 'Skapar...' : 'Skapa konto' }}
            </button>
          </div>
        </form>
      </template>

      <template v-else>
        <h2 class="text-lg font-semibold text-wh-ink">Kontot skapades</h2>
        <p class="mt-2 text-sm text-wh-ink">
          Dela inloggningen med <span class="font-medium">{{ created.name }}</span>:
        </p>
        <p class="mt-2 text-sm text-wh-mute">E-post: {{ created.email }}</p>
        <p class="text-sm text-wh-mute">Lösenord: {{ created.password }}</p>
        <div class="mt-4 flex flex-wrap items-center gap-3">
          <button
            type="button"
            class="rounded-md border border-wh-border px-3 py-1.5 text-xs text-wh-ink hover:border-wh-accent hover:text-wh-accent"
            @click="copyCredentials"
          >
            Kopiera meddelande
          </button>
          <span v-if="copyMessage" class="text-xs text-wh-mute">{{ copyMessage }}</span>
        </div>
        <div class="mt-6 flex justify-end gap-3">
          <button
            type="button"
            class="rounded-md border border-wh-border px-4 py-2 text-sm text-wh-ink hover:border-wh-accent"
            @click="reset"
          >
            Skapa ett till
          </button>
          <button
            type="button"
            class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
            @click="emit('close')"
          >
            Stäng
          </button>
        </div>
      </template>
    </div>
  </div>
</template>
