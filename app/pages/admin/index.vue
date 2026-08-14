<script setup lang="ts">
import type { League, Match, Signup } from '~/types'
import { PAINTED_UNIT_KEYS, type PaintedUnitKey } from '~/composables/useLeague'

definePageMeta({ middleware: 'admin' })

const supabase = useSupabaseClient()
const { profiles, refresh: refreshProfiles, name: profileName } = useProfiles()
const {
  allLeagues,
  selectedLeague,
  selectLeague,
  members,
  leaguesForUser,
  signups,
  disputedMatches,
  refresh,
  createLeague,
  setActiveLeague,
  deactivateLeague,
  updateLeague,
  advancePhase,
  archiveLeague,
  unarchiveLeague,
  deleteLeague,
  addMember,
  addMemberToLeague,
  removeMember,
  pairAll,
  pairIndividual,
  pairManual,
  resolveDispute,
  paintingPointsFor,
  setPaintedUnit,
  paintedUnits
} = useLeague()

function leagueName(leagueId: string) {
  return allLeagues.value.find(l => l.id === leagueId)?.name ?? 'Okänd liga'
}

function availableLeaguesFor(userId: string) {
  const memberOf = new Set(leaguesForUser(userId))
  return allLeagues.value.filter(l => !memberOf.has(l.id))
}

const addToLeagueError = ref('')

async function handleAddToLeague(userId: string, event: Event) {
  const select = event.target as HTMLSelectElement
  const leagueId = select.value
  select.value = ''
  if (!leagueId) return
  addToLeagueError.value = ''
  try {
    await addMemberToLeague(userId, leagueId)
  } catch (e) {
    addToLeagueError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

onMounted(async () => {
  await Promise.all([refresh(), refreshProfiles()])
})

const newLeagueName = ref('')
const newLeagueDescription = ref('')
const newLeaguePhaseCount = ref(1)
const newLeagueMatchesPerPhase = ref(3)
const leagueError = ref('')

async function submitLeague() {
  leagueError.value = ''
  try {
    await createLeague(newLeagueName.value, {
      description: newLeagueDescription.value,
      phaseCount: newLeaguePhaseCount.value,
      matchesPerPhase: newLeagueMatchesPerPhase.value
    })
    newLeagueName.value = ''
    newLeagueDescription.value = ''
    newLeaguePhaseCount.value = 1
    newLeagueMatchesPerPhase.value = 3
  } catch (e) {
    leagueError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

const editingLeagueId = ref<string | null>(null)
const editName = ref('')
const editDescription = ref('')
const editPhaseCount = ref(1)
const editMatchesPerPhase = ref(3)
const editError = ref('')
const leagueActionError = ref('')
const confirmDeleteId = ref<string | null>(null)

function startEdit(league: League) {
  editingLeagueId.value = league.id
  editName.value = league.name
  editDescription.value = league.description
  editPhaseCount.value = league.phase_count
  editMatchesPerPhase.value = league.matches_per_phase
  editError.value = ''
}

function cancelEdit() {
  editingLeagueId.value = null
}

async function saveEdit() {
  if (!editingLeagueId.value) return
  editError.value = ''
  try {
    await updateLeague(editingLeagueId.value, {
      name: editName.value,
      description: editDescription.value,
      phase_count: editPhaseCount.value,
      matches_per_phase: editMatchesPerPhase.value
    })
    editingLeagueId.value = null
  } catch (e) {
    editError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleAdvancePhase(leagueId: string) {
  leagueActionError.value = ''
  try {
    await advancePhase(leagueId)
  } catch (e) {
    leagueActionError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleArchive(leagueId: string) {
  leagueActionError.value = ''
  try {
    await archiveLeague(leagueId)
  } catch (e) {
    leagueActionError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleUnarchive(leagueId: string) {
  leagueActionError.value = ''
  try {
    await unarchiveLeague(leagueId)
  } catch (e) {
    leagueActionError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleDeactivate(leagueId: string) {
  leagueActionError.value = ''
  try {
    await deactivateLeague(leagueId)
  } catch (e) {
    leagueActionError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleSelectLeague(leagueId: string) {
  leagueActionError.value = ''
  try {
    await selectLeague(leagueId)
  } catch (e) {
    leagueActionError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleDelete(leagueId: string) {
  if (confirmDeleteId.value !== leagueId) {
    confirmDeleteId.value = leagueId
    return
  }
  leagueActionError.value = ''
  try {
    await deleteLeague(leagueId)
    confirmDeleteId.value = null
  } catch (e) {
    leagueActionError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

const newEmail = ref('')
const newPassword = ref('')
const newName = ref('')
const newArmy = ref('')
const selectedLeagueIds = ref<string[]>([])
const createUserError = ref('')
const creatingUser = ref(false)

interface CreatedAccount {
  name: string
  email: string
  password: string
}

const lastCreatedAccount = ref<CreatedAccount | null>(null)
const copyMessage = ref('')

async function submitCreateUser() {
  createUserError.value = ''
  lastCreatedAccount.value = null
  creatingUser.value = true
  try {
    const {
      data: { session }
    } = await supabase.auth.getSession()
    const result = await $fetch<{ id: string }>('/api/admin/create-user', {
      method: 'POST',
      headers: { Authorization: `Bearer ${session?.access_token}` },
      body: { email: newEmail.value, password: newPassword.value, name: newName.value, army: newArmy.value }
    })
    await refreshProfiles()
    if (result.id) {
      for (const leagueId of selectedLeagueIds.value) {
        await addMemberToLeague(result.id, leagueId)
      }
    }
    lastCreatedAccount.value = { name: newName.value, email: newEmail.value, password: newPassword.value }
    newEmail.value = ''
    newPassword.value = ''
    newName.value = ''
    newArmy.value = ''
    selectedLeagueIds.value = []
  } catch (e: unknown) {
    const err = e as { data?: { statusMessage?: string }; message?: string }
    createUserError.value = err.data?.statusMessage ?? err.message ?? 'Något gick fel.'
  } finally {
    creatingUser.value = false
  }
}

async function copyCredentials() {
  if (!lastCreatedAccount.value) return
  const { name, email, password } = lastCreatedAccount.value
  const text = `Hej ${name}! Ditt konto till Lyktan League Log:\nURL: ${window.location.origin}\nE-post: ${email}\nLösenord: ${password}\n\nLogga in och byt lösenord under Inställningar.`
  try {
    await navigator.clipboard.writeText(text)
    copyMessage.value = 'Kopierat!'
  } catch {
    copyMessage.value = 'Kunde inte kopiera automatiskt, markera texten manuellt.'
  }
}

const memberIds = computed(() => new Set(members.value.map(m => m.user_id)))
const nonMembers = computed(() => profiles.value.filter(p => !memberIds.value.has(p.id)))

const pairError = ref('')
const rematchFor = ref<Signup | null>(null)

const rematchCandidates = computed(() => {
  if (!rematchFor.value) return []
  return signups.value
    .filter(s => s.user_id !== rematchFor.value!.user_id)
    .map(s => ({ id: s.user_id, name: profileName(s.user_id) }))
})

async function handlePairAll() {
  pairError.value = ''
  try {
    await pairAll()
  } catch (e) {
    pairError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handlePairIndividual(userId: string) {
  pairError.value = ''
  try {
    const matched = await pairIndividual(userId)
    if (!matched) {
      rematchFor.value = signups.value.find(s => s.user_id === userId) ?? null
    }
  } catch (e) {
    pairError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleManualPair(opponentId: string) {
  if (!rematchFor.value) return
  pairError.value = ''
  try {
    await pairManual(rematchFor.value.user_id, opponentId)
    rematchFor.value = null
  } catch (e) {
    pairError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

const disputeEdits = reactive<Record<string, { p1: number; p2: number }>>({})
const disputeError = ref('')

function editsFor(m: Match) {
  if (!disputeEdits[m.id]) {
    disputeEdits[m.id] = { p1: m.player1_vp ?? 0, p2: m.player2_vp ?? 0 }
  }
  return disputeEdits[m.id]
}

async function handleResolveDispute(m: Match) {
  disputeError.value = ''
  const edits = editsFor(m)
  try {
    await resolveDispute(m.id, 'confirm', edits.p1, edits.p2)
    delete disputeEdits[m.id]
  } catch (e) {
    disputeError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleVoidDispute(matchId: string) {
  disputeError.value = ''
  try {
    await resolveDispute(matchId, 'void')
    delete disputeEdits[matchId]
  } catch (e) {
    disputeError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

const paintError = ref('')

function isPainted(userId: string, unit: PaintedUnitKey) {
  return paintedUnits.value.find(p => p.user_id === userId)?.[unit] ?? false
}

async function handleTogglePainted(userId: string, unit: PaintedUnitKey, event: Event) {
  paintError.value = ''
  const checked = (event.target as HTMLInputElement).checked
  try {
    await setPaintedUnit(userId, unit, checked)
  } catch (e) {
    paintError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}
</script>

<template>
  <div class="max-w-3xl space-y-8">
    <h1 class="text-2xl font-semibold text-wh-ink">Admin</h1>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-4 text-lg font-medium text-wh-ink">Ligor</h2>
      <p v-if="leagueActionError" class="mb-3 text-sm text-wh-accent">{{ leagueActionError }}</p>
      <ul class="mb-4 space-y-3">
        <li v-for="l in allLeagues" :key="l.id" class="rounded-md border border-wh-border p-3 text-sm">
          <template v-if="editingLeagueId === l.id">
            <div class="space-y-3">
              <div>
                <label class="mb-1 block text-xs text-wh-mute">Namn</label>
                <input
                  v-model="editName"
                  type="text"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                >
              </div>
              <div>
                <label class="mb-1 block text-xs text-wh-mute">Beskrivning</label>
                <textarea
                  v-model="editDescription"
                  rows="2"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                />
              </div>
              <div class="flex gap-3">
                <div class="w-32">
                  <label class="mb-1 block text-xs text-wh-mute">Antal faser</label>
                  <input
                    v-model.number="editPhaseCount"
                    type="number"
                    min="1"
                    class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                  >
                </div>
                <div class="w-32">
                  <label class="mb-1 block text-xs text-wh-mute">Matcher/fas</label>
                  <input
                    v-model.number="editMatchesPerPhase"
                    type="number"
                    min="1"
                    class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                  >
                </div>
              </div>
              <p v-if="editError" class="text-sm text-wh-accent">{{ editError }}</p>
              <div class="flex gap-2">
                <button
                  type="button"
                  class="rounded-md bg-wh-accent px-3 py-1.5 text-wh-ink hover:bg-wh-accent-hover"
                  @click="saveEdit"
                >
                  Spara
                </button>
                <button
                  type="button"
                  class="rounded-md border border-wh-border px-3 py-1.5 text-wh-mute hover:border-wh-accent"
                  @click="cancelEdit"
                >
                  Avbryt
                </button>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <span class="text-wh-ink">{{ l.name }}</span>
                <span v-if="l.id === selectedLeague?.id" class="ml-2 text-xs text-wh-mute">(hanteras nu)</span>
                <span v-if="l.is_active" class="ml-2 text-wh-gold">Aktiv</span>
                <span v-if="l.is_archived" class="ml-2 text-wh-mute">Arkiverad</span>
                <p v-if="l.description" class="mt-1 text-xs text-wh-mute">{{ l.description }}</p>
                <p class="mt-1 text-xs text-wh-mute">
                  Fas {{ l.current_phase }} av {{ l.phase_count }} · {{ l.matches_per_phase }} matcher/fas
                </p>
              </div>
              <div class="flex flex-wrap gap-3 text-xs">
                <button
                  v-if="l.id !== selectedLeague?.id"
                  type="button"
                  class="text-wh-mute hover:text-wh-accent"
                  @click="handleSelectLeague(l.id)"
                >
                  Hantera
                </button>
                <button
                  v-if="!l.is_active && !l.is_archived"
                  type="button"
                  class="text-wh-mute hover:text-wh-accent"
                  @click="setActiveLeague(l.id)"
                >
                  Gör aktiv
                </button>
                <button
                  v-if="l.is_active && !l.is_archived"
                  type="button"
                  class="text-wh-mute hover:text-wh-accent"
                  @click="handleDeactivate(l.id)"
                >
                  Avaktivera
                </button>
                <button
                  v-if="l.is_active && l.current_phase < l.phase_count"
                  type="button"
                  class="text-wh-mute hover:text-wh-accent"
                  @click="handleAdvancePhase(l.id)"
                >
                  Nästa fas
                </button>
                <button type="button" class="text-wh-mute hover:text-wh-accent" @click="startEdit(l)">
                  Redigera
                </button>
                <button
                  v-if="!l.is_archived"
                  type="button"
                  class="text-wh-mute hover:text-wh-accent"
                  @click="handleArchive(l.id)"
                >
                  Arkivera
                </button>
                <button v-else type="button" class="text-wh-mute hover:text-wh-accent" @click="handleUnarchive(l.id)">
                  Återställ
                </button>
                <button
                  type="button"
                  class="text-wh-mute hover:text-wh-accent"
                  @click="handleDelete(l.id)"
                >
                  {{ confirmDeleteId === l.id ? 'Bekräfta radering' : 'Ta bort' }}
                </button>
              </div>
            </div>
          </template>
        </li>
        <li v-if="!allLeagues.length" class="text-sm text-wh-mute">Inga ligor skapade än.</li>
      </ul>

      <form class="space-y-3" @submit.prevent="submitLeague">
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Ny liga</label>
          <input
            v-model="newLeagueName"
            type="text"
            required
            placeholder="T.ex. Liga 1 2026"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Beskrivning (valfritt)</label>
          <textarea
            v-model="newLeagueDescription"
            rows="2"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          />
        </div>
        <div class="flex gap-3">
          <div class="w-32">
            <label class="mb-1 block text-sm text-wh-mute">Antal faser</label>
            <input
              v-model.number="newLeaguePhaseCount"
              type="number"
              min="1"
              required
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
          <div class="w-32">
            <label class="mb-1 block text-sm text-wh-mute">Matcher per fas</label>
            <input
              v-model.number="newLeagueMatchesPerPhase"
              type="number"
              min="1"
              required
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
          </div>
        </div>
        <button type="submit" class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover">
          Skapa
        </button>
      </form>
      <p v-if="leagueError" class="mt-2 text-sm text-wh-accent">{{ leagueError }}</p>
    </section>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-4 text-lg font-medium text-wh-ink">Skapa spelarkonto</h2>
      <p class="mb-4 text-sm text-wh-mute">
        Sätt ett tillfälligt lösenord och dela det själv med spelaren (Discord, SMS, i person). Spelaren måste byta
        det vid första inloggning.
      </p>
      <form class="grid gap-3 sm:grid-cols-2" @submit.prevent="submitCreateUser">
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Namn</label>
          <input
            v-model="newName"
            type="text"
            required
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Armé (valfritt)</label>
          <input
            v-model="newArmy"
            type="text"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <div>
          <label class="mb-1 block text-sm text-wh-mute">E-post</label>
          <input
            v-model="newEmail"
            type="email"
            required
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <div>
          <label class="mb-1 block text-sm text-wh-mute">Tillfälligt lösenord</label>
          <input
            v-model="newPassword"
            type="text"
            required
            minlength="6"
            class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
          >
        </div>
        <div class="sm:col-span-2">
          <label class="mb-1 block text-sm text-wh-mute">Lägg till i ligor (valfritt)</label>
          <div class="space-y-1">
            <label v-for="l in allLeagues" :key="l.id" class="flex items-center gap-2 text-sm text-wh-ink">
              <input v-model="selectedLeagueIds" type="checkbox" :value="l.id" class="accent-wh-accent">
              {{ l.name }}
              <span v-if="l.is_active" class="text-xs text-wh-gold">Aktiv</span>
              <span v-if="l.is_archived" class="text-xs text-wh-mute">Arkiverad</span>
            </label>
            <p v-if="!allLeagues.length" class="text-sm text-wh-mute">Inga ligor skapade än.</p>
          </div>
        </div>
        <p v-if="createUserError" class="text-sm text-wh-accent sm:col-span-2">{{ createUserError }}</p>
        <button
          type="submit"
          :disabled="creatingUser"
          class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50 sm:col-span-2"
        >
          {{ creatingUser ? 'Skapar...' : 'Skapa konto' }}
        </button>
      </form>

      <div v-if="lastCreatedAccount" class="mt-4 rounded-md border border-wh-gold/50 bg-wh-surface-alt p-4 text-sm">
        <p class="text-wh-ink">
          Kontot för <span class="font-medium">{{ lastCreatedAccount.name }}</span> skapades. Dela inloggningen:
        </p>
        <p class="mt-2 text-wh-mute">E-post: {{ lastCreatedAccount.email }}</p>
        <p class="text-wh-mute">Lösenord: {{ lastCreatedAccount.password }}</p>
        <button
          type="button"
          class="mt-3 rounded-md border border-wh-border px-3 py-1.5 text-xs text-wh-ink hover:border-wh-accent hover:text-wh-accent"
          @click="copyCredentials"
        >
          Kopiera meddelande
        </button>
        <span v-if="copyMessage" class="ml-2 text-xs text-wh-mute">{{ copyMessage }}</span>
      </div>
    </section>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-4 text-lg font-medium text-wh-ink">Alla konton</h2>
      <p v-if="addToLeagueError" class="mb-3 text-sm text-wh-accent">{{ addToLeagueError }}</p>
      <ul class="space-y-2">
        <li
          v-for="p in profiles"
          :key="p.id"
          class="flex flex-wrap items-center justify-between gap-3 rounded-md border border-wh-border p-3 text-sm"
        >
          <div>
            <NuxtLink :to="`/players/${p.id}`" class="text-wh-ink hover:text-wh-gold hover:underline">
              {{ p.name }}
            </NuxtLink>
            <span class="text-xs text-wh-mute">({{ p.email }})</span>
            <div class="mt-1 flex flex-wrap gap-1">
              <span
                v-for="leagueId in leaguesForUser(p.id)"
                :key="leagueId"
                class="rounded-full border border-wh-border px-2 py-0.5 text-xs text-wh-mute"
              >
                {{ leagueName(leagueId) }}
              </span>
              <span v-if="!leaguesForUser(p.id).length" class="text-xs text-wh-mute">Ingen liga</span>
            </div>
          </div>
          <select
            v-if="availableLeaguesFor(p.id).length"
            class="rounded-md border border-wh-border bg-wh-surface-alt px-2 py-1 text-xs text-wh-ink outline-none focus:border-wh-accent"
            @change="handleAddToLeague(p.id, $event)"
          >
            <option value="" disabled selected>Lägg till i liga...</option>
            <option v-for="l in availableLeaguesFor(p.id)" :key="l.id" :value="l.id">{{ l.name }}</option>
          </select>
        </li>
        <li v-if="!profiles.length" class="text-sm text-wh-mute">Inga konton skapade än.</li>
      </ul>
    </section>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-4 text-lg font-medium text-wh-ink">Medlemmar {{ selectedLeague ? `i ${selectedLeague.name}` : '' }}</h2>

      <div v-if="!selectedLeague" class="text-sm text-wh-mute">Skapa en liga och klicka "Hantera" på den först.</div>

      <template v-else>
        <p v-if="paintError" class="mb-3 text-sm text-wh-accent">{{ paintError }}</p>
        <ul class="mb-4 space-y-2">
          <li
            v-for="m in members"
            :key="m.user_id"
            class="flex flex-wrap items-center justify-between gap-3 rounded-md border border-wh-border p-3 text-sm"
          >
            <span class="text-wh-ink">{{ profileName(m.user_id) }}</span>
            <div class="flex flex-wrap items-center gap-3">
              <label
                v-for="(unit, index) in PAINTED_UNIT_KEYS"
                :key="unit"
                class="flex items-center gap-1 text-xs text-wh-mute"
              >
                <input
                  type="checkbox"
                  class="accent-wh-accent"
                  :checked="isPainted(m.user_id, unit)"
                  @change="handleTogglePainted(m.user_id, unit, $event)"
                >
                Unit {{ index + 1 }}
              </label>
              <span class="text-xs text-wh-gold">{{ paintingPointsFor(m.user_id) }}p målat</span>
              <button type="button" class="text-wh-mute hover:text-wh-accent" @click="removeMember(m.user_id)">
                Ta bort
              </button>
            </div>
          </li>
          <li v-if="!members.length" class="text-sm text-wh-mute">Inga medlemmar i ligan än.</li>
        </ul>

        <div v-if="nonMembers.length" class="flex flex-wrap items-end gap-3">
          <select
            id="add-member-select"
            class="rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            @change="addMember(($event.target as HTMLSelectElement).value); ($event.target as HTMLSelectElement).value = ''"
          >
            <option value="" disabled selected>Lägg till spelare...</option>
            <option v-for="p in nonMembers" :key="p.id" :value="p.id">{{ p.name || p.email }}</option>
          </select>
        </div>
      </template>
    </section>

    <section v-if="selectedLeague" class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h2 class="text-lg font-medium text-wh-ink">Redo att spela</h2>
        <button
          type="button"
          :disabled="signups.length < 2"
          class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
          @click="handlePairAll"
        >
          Lotta alla
        </button>
      </div>
      <p v-if="pairError" class="mb-3 text-sm text-wh-accent">{{ pairError }}</p>
      <ul class="space-y-2">
        <li
          v-for="s in signups"
          :key="s.id"
          class="flex flex-wrap items-center justify-between gap-3 rounded-md border border-wh-border p-3 text-sm"
        >
          <div>
            <span class="text-wh-ink">{{ profileName(s.user_id) }}</span>
            <details class="mt-1">
              <summary class="cursor-pointer text-xs text-wh-gold">Visa lista</summary>
              <pre class="mt-1 max-w-md whitespace-pre-wrap rounded-md border border-wh-border bg-wh-surface-alt p-2 text-xs text-wh-ink">{{ s.army_list }}</pre>
            </details>
          </div>
          <button
            type="button"
            :disabled="signups.length < 2"
            class="rounded-md border border-wh-border px-3 py-1.5 text-wh-mute hover:border-wh-accent hover:text-wh-accent disabled:opacity-50"
            @click="handlePairIndividual(s.user_id)"
          >
            Lotta denna spelare
          </button>
        </li>
        <li v-if="!signups.length" class="text-sm text-wh-mute">Ingen är redo just nu.</li>
      </ul>
    </section>

    <section v-if="disputedMatches.length" class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-4 text-lg font-medium text-wh-ink">Bestridda matcher</h2>
      <p v-if="disputeError" class="mb-3 text-sm text-wh-accent">{{ disputeError }}</p>
      <ul class="space-y-3">
        <li v-for="m in disputedMatches" :key="m.id" class="rounded-md border border-wh-border p-3 text-sm">
          <p class="text-wh-mute">
            Rapporterat av {{ profileName(m.reporter_id!) }}: {{ m.player1_vp }} VP – {{ m.player2_vp }} VP
            (League Points {{ m.player1_league_points }}–{{ m.player2_league_points }})
          </p>
          <div class="mt-3 grid grid-cols-2 gap-3 sm:max-w-sm">
            <div>
              <label class="mb-1 block text-xs text-wh-mute">{{ profileName(m.player1_id) }} VP</label>
              <input
                v-model.number="editsFor(m).p1"
                type="number"
                min="0"
                class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
              >
            </div>
            <div>
              <label class="mb-1 block text-xs text-wh-mute">{{ profileName(m.player2_id) }} VP</label>
              <input
                v-model.number="editsFor(m).p2"
                type="number"
                min="0"
                class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
              >
            </div>
          </div>
          <div class="mt-3 flex gap-2">
            <button
              type="button"
              class="rounded-md bg-wh-accent px-3 py-1.5 text-wh-ink hover:bg-wh-accent-hover"
              @click="handleResolveDispute(m)"
            >
              Godkänn med dessa poäng
            </button>
            <button
              type="button"
              class="rounded-md border border-wh-border px-3 py-1.5 text-wh-mute hover:border-wh-accent hover:text-wh-accent"
              @click="handleVoidDispute(m.id)"
            >
              Häv matchen
            </button>
          </div>
        </li>
      </ul>
    </section>

    <RematchModal
      v-if="rematchFor"
      :player-name="profileName(rematchFor.user_id)"
      :candidates="rematchCandidates"
      @cancel="rematchFor = null"
      @confirm="handleManualPair"
    />
  </div>
</template>
