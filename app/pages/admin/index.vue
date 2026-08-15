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
const { refresh: refreshPaintedUnitPhotos, photoFor } = usePaintedUnitPhotos()

onMounted(async () => {
  await Promise.all([refresh(), refreshProfiles()])
})

watch(
  () => selectedLeague.value?.id,
  leagueId => {
    if (leagueId) refreshPaintedUnitPhotos(leagueId)
  },
  { immediate: true }
)

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

// League create/edit modal
const showLeagueModal = ref(false)
const leagueModalMode = ref<'create' | 'edit'>('create')
const editingLeague = ref<League | null>(null)
const leagueActionError = ref('')
const confirmDeleteId = ref<string | null>(null)

function openCreateLeagueModal() {
  leagueModalMode.value = 'create'
  editingLeague.value = null
  showLeagueModal.value = true
}

function openEditLeagueModal(league: League) {
  leagueModalMode.value = 'edit'
  editingLeague.value = league
  showLeagueModal.value = true
}

async function handleLeagueSubmit(payload: {
  name: string
  description: string
  phaseCount: number
  matchesPerPhase: number
}) {
  if (leagueModalMode.value === 'create') {
    await createLeague(payload.name, {
      description: payload.description,
      phaseCount: payload.phaseCount,
      matchesPerPhase: payload.matchesPerPhase
    })
  } else if (editingLeague.value) {
    await updateLeague(editingLeague.value.id, {
      name: payload.name,
      description: payload.description,
      phase_count: payload.phaseCount,
      matches_per_phase: payload.matchesPerPhase
    })
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

async function handleActivate(leagueId: string) {
  leagueActionError.value = ''
  try {
    await setActiveLeague(leagueId)
  } catch (e) {
    leagueActionError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}

async function handleSelectLeague(leagueId: string) {
  if (!leagueId) return
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

// Create account modal
const showAccountModal = ref(false)

async function handleCreateAccount(payload: {
  name: string
  army: string
  email: string
  password: string
  leagueIds: string[]
}) {
  const {
    data: { session }
  } = await supabase.auth.getSession()
  const result = await $fetch<{ id: string }>('/api/admin/create-user', {
    method: 'POST',
    headers: { Authorization: `Bearer ${session?.access_token}` },
    body: { email: payload.email, password: payload.password, name: payload.name, army: payload.army }
  })
  await refreshProfiles()
  if (result.id) {
    for (const leagueId of payload.leagueIds) {
      await addMemberToLeague(result.id, leagueId)
    }
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
const reviewingUnit = ref<{ userId: string; unit: PaintedUnitKey } | null>(null)

function isPainted(userId: string, unit: PaintedUnitKey) {
  return paintedUnits.value.find(p => p.user_id === userId)?.[unit] ?? false
}

function pendingPhoto(userId: string, unit: PaintedUnitKey) {
  if (!selectedLeague.value) return null
  const photo = photoFor(selectedLeague.value.id, userId, unit)
  return photo?.status === 'submitted' ? photo : null
}

function handleUnitPillClick(userId: string, unit: PaintedUnitKey) {
  if (pendingPhoto(userId, unit)) {
    reviewingUnit.value = { userId, unit }
  } else {
    handleTogglePainted(userId, unit)
  }
}

async function handleTogglePainted(userId: string, unit: PaintedUnitKey) {
  paintError.value = ''
  try {
    await setPaintedUnit(userId, unit, !isPainted(userId, unit))
  } catch (e) {
    paintError.value = e instanceof Error ? e.message : 'Något gick fel.'
  }
}
</script>

<template>
  <div class="max-w-3xl space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h1 class="text-2xl font-semibold text-wh-ink">Admin</h1>
      <div class="flex flex-wrap gap-2">
        <button
          type="button"
          class="rounded-md border border-wh-border px-3 py-1.5 text-sm text-wh-ink hover:border-wh-accent"
          @click="showAccountModal = true"
        >
          + Nytt konto
        </button>
        <button
          type="button"
          class="rounded-md bg-wh-accent px-3 py-1.5 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
          @click="openCreateLeagueModal"
        >
          + Ny liga
        </button>
      </div>
    </div>

    <!-- Currently managed league -->
    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <label class="mb-1 block text-xs text-wh-mute">Hanterar liga</label>
          <select
            :value="selectedLeague?.id ?? ''"
            class="rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            @change="handleSelectLeague(($event.target as HTMLSelectElement).value)"
          >
            <option v-if="!allLeagues.length" value="" disabled>Inga ligor än</option>
            <option v-for="l in allLeagues" :key="l.id" :value="l.id">
              {{ l.name }}{{ l.is_archived ? ' (arkiverad)' : '' }}
            </option>
          </select>

          <template v-if="selectedLeague">
            <span v-if="selectedLeague.is_active" class="ml-2 text-sm text-wh-gold">Aktiv</span>
            <p v-if="selectedLeague.description" class="mt-2 text-sm text-wh-mute">{{ selectedLeague.description }}</p>
            <p class="mt-1 text-xs text-wh-mute">
              Fas {{ selectedLeague.current_phase }} av {{ selectedLeague.phase_count }} ·
              {{ selectedLeague.matches_per_phase }} matcher/fas
            </p>
          </template>
          <p v-else class="mt-2 text-sm text-wh-mute">Skapa en liga för att komma igång.</p>
        </div>

        <div v-if="selectedLeague" class="flex flex-wrap gap-3 text-xs">
          <button
            v-if="selectedLeague.is_active && selectedLeague.current_phase < selectedLeague.phase_count"
            type="button"
            class="text-wh-mute hover:text-wh-accent"
            @click="handleAdvancePhase(selectedLeague.id)"
          >
            Nästa fas
          </button>
          <button type="button" class="text-wh-mute hover:text-wh-accent" @click="openEditLeagueModal(selectedLeague)">
            Redigera
          </button>
          <button
            v-if="selectedLeague.is_active && !selectedLeague.is_archived"
            type="button"
            class="text-wh-mute hover:text-wh-accent"
            @click="handleDeactivate(selectedLeague.id)"
          >
            Avaktivera
          </button>
          <button
            v-else-if="!selectedLeague.is_archived"
            type="button"
            class="text-wh-mute hover:text-wh-accent"
            @click="handleActivate(selectedLeague.id)"
          >
            Gör aktiv
          </button>
        </div>
      </div>
      <p v-if="leagueActionError" class="mt-3 text-sm text-wh-accent">{{ leagueActionError }}</p>
    </section>

    <!-- Disputed matches: always visible when present, needs attention -->
    <section v-if="disputedMatches.length" class="rounded-lg border border-wh-accent/50 bg-wh-surface p-6">
      <h2 class="mb-4 text-lg font-medium text-wh-accent">Bestridda matcher</h2>
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

    <!-- Ready to play -->
    <CollapsibleSection v-if="selectedLeague" title="Redo att spela" default-open :badge="signups.length || undefined">
      <div class="mb-4 flex justify-end">
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
    </CollapsibleSection>

    <!-- Members -->
    <CollapsibleSection
      v-if="selectedLeague"
      :title="`Medlemmar i ${selectedLeague.name}`"
      default-open
      :badge="members.length || undefined"
    >
      <p v-if="paintError" class="mb-3 text-sm text-wh-accent">{{ paintError }}</p>
      <ul class="mb-4 space-y-2">
        <li
          v-for="m in members"
          :key="m.user_id"
          class="flex flex-wrap items-center justify-between gap-3 rounded-md border border-wh-border p-3 text-sm"
        >
          <span class="text-wh-ink">{{ profileName(m.user_id) }}</span>
          <div class="flex flex-wrap items-center gap-3">
            <div class="flex items-center gap-1" title="Målade units">
              <button
                v-for="(unit, index) in PAINTED_UNIT_KEYS"
                :key="unit"
                type="button"
                :title="pendingPhoto(m.user_id, unit) ? `Unit ${index + 1} — väntar på granskning` : `Unit ${index + 1}`"
                :class="[
                  'flex h-6 w-6 items-center justify-center rounded text-xs font-medium transition-colors',
                  pendingPhoto(m.user_id, unit)
                    ? 'border-2 border-wh-gold text-wh-gold animate-pulse'
                    : isPainted(m.user_id, unit)
                      ? 'bg-wh-gold text-wh-bg'
                      : 'border border-wh-border text-wh-mute hover:border-wh-gold'
                ]"
                @click="handleUnitPillClick(m.user_id, unit)"
              >
                {{ index + 1 }}
              </button>
              <span class="ml-1 text-xs text-wh-mute">{{ paintingPointsFor(m.user_id) }}p</span>
            </div>
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
    </CollapsibleSection>

    <!-- All leagues -->
    <CollapsibleSection title="Alla ligor" :badge="allLeagues.length || undefined">
      <ul class="space-y-3">
        <li v-for="l in allLeagues" :key="l.id" class="rounded-md border border-wh-border p-3 text-sm">
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
                @click="handleActivate(l.id)"
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
              <button type="button" class="text-wh-mute hover:text-wh-accent" @click="openEditLeagueModal(l)">
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
              <button type="button" class="text-wh-mute hover:text-wh-accent" @click="handleDelete(l.id)">
                {{ confirmDeleteId === l.id ? 'Bekräfta radering' : 'Ta bort' }}
              </button>
            </div>
          </div>
        </li>
        <li v-if="!allLeagues.length" class="text-sm text-wh-mute">Inga ligor skapade än.</li>
      </ul>
    </CollapsibleSection>

    <!-- All accounts -->
    <CollapsibleSection title="Alla konton" :badge="profiles.length || undefined">
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
    </CollapsibleSection>

    <PaintedUnitReviewModal
      v-if="reviewingUnit && selectedLeague && pendingPhoto(reviewingUnit.userId, reviewingUnit.unit)"
      :league-id="selectedLeague.id"
      :player-name="profileName(reviewingUnit.userId)"
      :unit-key="reviewingUnit.unit"
      :unit-number="PAINTED_UNIT_KEYS.indexOf(reviewingUnit.unit) + 1"
      :photo="pendingPhoto(reviewingUnit.userId, reviewingUnit.unit)!"
      @close="reviewingUnit = null; refresh()"
    />

    <LeagueFormModal
      v-if="showLeagueModal"
      :mode="leagueModalMode"
      :initial-name="editingLeague?.name"
      :initial-description="editingLeague?.description"
      :initial-phase-count="editingLeague?.phase_count"
      :initial-matches-per-phase="editingLeague?.matches_per_phase"
      :on-submit="handleLeagueSubmit"
      @close="showLeagueModal = false"
    />

    <NewAccountModal
      v-if="showAccountModal"
      :all-leagues="allLeagues"
      :on-submit="handleCreateAccount"
      @close="showAccountModal = false"
    />

    <RematchModal
      v-if="rematchFor"
      :player-name="profileName(rematchFor.user_id)"
      :candidates="rematchCandidates"
      @cancel="rematchFor = null"
      @confirm="handleManualPair"
    />
  </div>
</template>
