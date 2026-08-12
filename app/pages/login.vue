<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

if (user.value) {
  router.push('/')
}

async function submit() {
  error.value = ''
  loading.value = true
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email: email.value.trim().toLowerCase(),
    password: password.value
  })
  loading.value = false
  if (signInError) {
    error.value = 'Fel e-post eller lösenord.'
    return
  }
  router.push('/')
}
</script>

<template>
  <div class="mx-auto max-w-sm">
    <h1 class="mb-6 text-2xl font-semibold text-wh-ink">Logga in</h1>

    <form class="space-y-4" @submit.prevent="submit">
      <div>
        <label class="mb-1 block text-sm text-wh-mute">E-post</label>
        <input
          v-model="email"
          type="email"
          required
          class="w-full rounded-md border border-wh-border bg-wh-surface px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
        >
      </div>

      <div>
        <label class="mb-1 block text-sm text-wh-mute">Lösenord</label>
        <input
          v-model="password"
          type="password"
          required
          class="w-full rounded-md border border-wh-border bg-wh-surface px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
        >
      </div>

      <p v-if="error" class="text-sm text-wh-accent">{{ error }}</p>

      <button
        type="submit"
        :disabled="loading"
        class="w-full rounded-md bg-wh-accent px-4 py-2 font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
      >
        {{ loading ? 'Loggar in...' : 'Logga in' }}
      </button>
    </form>

    <p class="mt-4 text-sm text-wh-mute">
      Inget konto? Be en admin skapa ett åt dig.
    </p>
  </div>
</template>
