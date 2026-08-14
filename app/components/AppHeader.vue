<script setup lang="ts">
const user = useSupabaseUser()
const supabase = useSupabaseClient()
const { profile, isAdmin } = useProfile()
const { isAdminView, toggle: toggleViewMode } = useViewMode()
const { pendingConfirmations, myLeagues, selectedLeague, selectLeague, refresh } = useLeague()
const router = useRouter()

if (user.value) {
  refresh()
}

watch(user, u => {
  if (u) refresh()
})

async function handleLogout() {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>

<template>
  <header class="border-b border-wh-border bg-wh-surface">
    <div class="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6">
      <NuxtLink to="/" class="flex items-center gap-2 text-lg font-semibold tracking-wide text-wh-ink">
        <span class="text-wh-accent">⚔</span>
        Lyktan League Log
      </NuxtLink>

      <nav v-if="user" class="flex flex-wrap items-center gap-4 text-sm text-wh-mute">
        <NuxtLink to="/" class="relative hover:text-wh-ink">
          Översikt
          <span
            v-if="pendingConfirmations.length"
            class="absolute -right-3 -top-1.5 inline-flex h-4 w-4 items-center justify-center rounded-full bg-wh-accent text-[10px] font-semibold text-wh-ink"
          >
            {{ pendingConfirmations.length }}
          </span>
        </NuxtLink>
        <NuxtLink to="/matches" class="hover:text-wh-ink">Matcher</NuxtLink>
        <NuxtLink to="/tracker" class="hover:text-wh-ink">Tracker</NuxtLink>
        <NuxtLink to="/scoreboard" class="hover:text-wh-ink">Tabell</NuxtLink>
        <NuxtLink to="/settings" class="hover:text-wh-ink">Inställningar</NuxtLink>
        <NuxtLink v-if="isAdminView" to="/admin" class="text-wh-gold hover:text-wh-gold">Admin</NuxtLink>
      </nav>

      <div v-if="user" class="flex items-center gap-3 text-sm">
        <select
          v-if="myLeagues.length > 1"
          :value="selectedLeague?.id"
          class="rounded-md border border-wh-border bg-wh-surface-alt px-2 py-1.5 text-xs text-wh-ink outline-none focus:border-wh-accent"
          @change="selectLeague(($event.target as HTMLSelectElement).value)"
        >
          <option v-for="l in myLeagues" :key="l.id" :value="l.id">{{ l.name }}</option>
        </select>
        <button
          v-if="isAdmin"
          type="button"
          class="rounded-md border border-wh-border px-3 py-1.5 text-xs text-wh-mute hover:border-wh-gold hover:text-wh-gold"
          :title="isAdminView ? 'Visa appen som en vanlig spelare' : 'Gå tillbaka till admin-vyn'"
          @click="toggleViewMode"
        >
          {{ isAdminView ? '👁 Visa som spelare' : '👁 Visa som admin' }}
        </button>
        <span class="text-wh-mute">{{ profile?.name }}</span>
        <button
          type="button"
          class="rounded-md border border-wh-border px-3 py-1.5 text-wh-ink hover:border-wh-accent hover:text-wh-accent"
          @click="handleLogout"
        >
          Logga ut
        </button>
      </div>
    </div>
  </header>
</template>
