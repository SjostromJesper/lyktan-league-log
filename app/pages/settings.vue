<script setup lang="ts">
const { profile, refresh, updateProfile, changePassword } = useProfile()

const name = ref('')
const army = ref('')
const profileMessage = ref('')
const profileError = ref('')
const profileSubmitting = ref(false)

const newPassword = ref('')
const newPasswordRepeat = ref('')
const passwordMessage = ref('')
const passwordError = ref('')
const passwordSubmitting = ref(false)

onMounted(async () => {
  if (!profile.value) await refresh()
  name.value = profile.value?.name ?? ''
  army.value = profile.value?.army ?? ''
})

watch(profile, p => {
  name.value = p?.name ?? ''
  army.value = p?.army ?? ''
})

async function saveProfile() {
  profileError.value = ''
  profileMessage.value = ''
  profileSubmitting.value = true
  try {
    await updateProfile({ name: name.value, army: army.value })
    profileMessage.value = 'Sparat.'
  } catch (e) {
    profileError.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    profileSubmitting.value = false
  }
}

async function savePassword() {
  passwordError.value = ''
  passwordMessage.value = ''
  if (newPassword.value !== newPasswordRepeat.value) {
    passwordError.value = 'Lösenorden matchar inte.'
    return
  }
  passwordSubmitting.value = true
  try {
    await changePassword(newPassword.value)
    passwordMessage.value = 'Lösenordet är uppdaterat.'
    newPassword.value = ''
    newPasswordRepeat.value = ''
  } catch (e) {
    passwordError.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    passwordSubmitting.value = false
  }
}
</script>

<template>
  <div class="max-w-md space-y-8">
    <h1 class="text-2xl font-semibold text-wh-ink">Inställningar</h1>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-4 text-lg font-medium text-wh-ink">Profil</h2>
      <form class="space-y-4" @submit.prevent="saveProfile">
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
          <label class="mb-1 block text-sm text-wh-mute">Armé</label>
          <input
            v-model="army"
            type="text"
            placeholder="T.ex. Space Marines"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <p v-if="profileError" class="text-sm text-wh-accent">{{ profileError }}</p>
        <p v-if="profileMessage" class="text-sm text-emerald-500">{{ profileMessage }}</p>
        <button
          type="submit"
          :disabled="profileSubmitting"
          class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
        >
          Spara
        </button>
      </form>
    </section>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-4 text-lg font-medium text-wh-ink">Byt lösenord</h2>
      <form class="space-y-4" @submit.prevent="savePassword">
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Nytt lösenord</label>
          <input
            v-model="newPassword"
            type="password"
            required
            minlength="6"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Upprepa lösenord</label>
          <input
            v-model="newPasswordRepeat"
            type="password"
            required
            minlength="6"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <p v-if="passwordError" class="text-sm text-wh-accent">{{ passwordError }}</p>
        <p v-if="passwordMessage" class="text-sm text-emerald-500">{{ passwordMessage }}</p>
        <button
          type="submit"
          :disabled="passwordSubmitting"
          class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
        >
          Uppdatera lösenord
        </button>
      </form>
    </section>
  </div>
</template>
