<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()
const { updateProfile } = useProfile()
const router = useRouter()

const newPassword = ref('')
const newPasswordRepeat = ref('')
const error = ref('')
const submitting = ref(false)
const checking = ref(true)

watch(
  user,
  u => {
    if (u) checking.value = false
  },
  { immediate: true }
)

onMounted(() => {
  setTimeout(() => {
    checking.value = false
  }, 2000)
})

async function submit() {
  error.value = ''
  if (newPassword.value.length < 6) {
    error.value = 'Lösenordet måste vara minst 6 tecken.'
    return
  }
  if (newPassword.value !== newPasswordRepeat.value) {
    error.value = 'Lösenorden matchar inte.'
    return
  }
  submitting.value = true
  try {
    const { error: updateError } = await supabase.auth.updateUser({ password: newPassword.value })
    if (updateError) throw new Error(updateError.message)
    await updateProfile({ password_change_required: false })
    router.push('/')
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-sm">
    <h1 class="mb-6 text-2xl font-semibold text-wh-ink">Välkommen!</h1>

    <div v-if="checking && !user" class="text-sm text-wh-mute">Loggar in...</div>

    <div v-else-if="!user" class="space-y-3 text-sm text-wh-mute">
      <p>Länken är ogiltig eller har gått ut. Be en admin skicka en ny inbjudan.</p>
      <NuxtLink to="/login" class="text-wh-accent hover:underline">Till inloggningen</NuxtLink>
    </div>

    <form v-else class="space-y-4" @submit.prevent="submit">
      <p class="text-sm text-wh-mute">Sätt ett lösenord för att slutföra ditt konto.</p>
      <div>
        <label class="mb-1 block text-sm text-wh-mute">Lösenord</label>
        <input
          v-model="newPassword"
          type="password"
          required
          minlength="6"
          class="w-full rounded-md border border-wh-border bg-wh-surface px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
        >
      </div>
      <div>
        <label class="mb-1 block text-sm text-wh-mute">Upprepa lösenord</label>
        <input
          v-model="newPasswordRepeat"
          type="password"
          required
          minlength="6"
          class="w-full rounded-md border border-wh-border bg-wh-surface px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
        >
      </div>
      <p v-if="error" class="text-sm text-wh-accent">{{ error }}</p>
      <button
        type="submit"
        :disabled="submitting"
        class="w-full rounded-md bg-wh-accent px-4 py-2 font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
      >
        {{ submitting ? 'Sparar...' : 'Kom igång' }}
      </button>
    </form>
  </div>
</template>
