<script setup lang="ts">
import { PAINTED_UNIT_KEYS, type PaintedUnitKey } from '~/composables/useLeague'

const { profile } = useProfile()
const { profiles, refresh: refreshProfiles, name: profileName, byId } = useProfiles()
const {
  selectedLeague,
  isMember,
  mySignup,
  myActiveMatch,
  loaded,
  refresh,
  submitSignup,
  reportMatch,
  confirmMatch,
  myPhaseMatchCount,
  paintingPointsFor
} = useLeague()
const currentUserId = useCurrentUserId()
const { refresh: refreshPaintedUnitPhotos, photoFor } = usePaintedUnitPhotos()

const armyListDraft = ref('')
const showConfirmModal = ref(false)
const signupError = ref('')
const signupSubmitting = ref(false)

const openList = ref<'mine' | 'opponent' | null>(null)

const myVpDraft = ref<number | null>(null)
const opponentVpDraft = ref<number | null>(null)
const reportError = ref('')
const reportSubmitting = ref(false)

const confirmError = ref('')
const confirmSubmitting = ref(false)

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

const openUnitModal = ref<PaintedUnitKey | null>(null)

function myPhoto(unit: PaintedUnitKey) {
  if (!selectedLeague.value || !currentUserId.value) return null
  return photoFor(selectedLeague.value.id, currentUserId.value, unit)
}

function unitStatusClass(unit: PaintedUnitKey) {
  const photo = myPhoto(unit)
  if (photo?.status === 'approved') return 'bg-wh-gold text-wh-bg'
  if (photo?.status === 'submitted') return 'border-2 border-wh-gold text-wh-gold animate-pulse'
  if (photo?.unpainted_path || photo?.painted_path) return 'border border-wh-gold/50 text-wh-mute'
  return 'border border-wh-border text-wh-mute hover:border-wh-gold'
}

const opponentId = computed(() => {
  if (!myActiveMatch.value || !currentUserId.value) return null
  return myActiveMatch.value.player1_id === currentUserId.value
    ? myActiveMatch.value.player2_id
    : myActiveMatch.value.player1_id
})

const opponentDiscord = computed(() => (opponentId.value ? byId(opponentId.value)?.discord ?? '' : ''))

const myList = computed(() => {
  if (!myActiveMatch.value || !currentUserId.value) return ''
  return myActiveMatch.value.player1_id === currentUserId.value
    ? myActiveMatch.value.player1_list
    : myActiveMatch.value.player2_list
})

const opponentList = computed(() => {
  if (!myActiveMatch.value || !currentUserId.value) return ''
  return myActiveMatch.value.player1_id === currentUserId.value
    ? myActiveMatch.value.player2_list
    : myActiveMatch.value.player1_list
})

const isReporter = computed(() => myActiveMatch.value?.reporter_id === currentUserId.value)

const amPlayer1 = computed(() => myActiveMatch.value?.player1_id === currentUserId.value)

const myVp = computed(() => (amPlayer1.value ? myActiveMatch.value?.player1_vp : myActiveMatch.value?.player2_vp) ?? null)
const opponentVp = computed(
  () => (amPlayer1.value ? myActiveMatch.value?.player2_vp : myActiveMatch.value?.player1_vp) ?? null
)
const myWtc = computed(
  () => (amPlayer1.value ? myActiveMatch.value?.player1_wtc : myActiveMatch.value?.player2_wtc) ?? null
)
const opponentWtc = computed(
  () => (amPlayer1.value ? myActiveMatch.value?.player2_wtc : myActiveMatch.value?.player1_wtc) ?? null
)
const myLeaguePoints = computed(
  () => (amPlayer1.value ? myActiveMatch.value?.player1_league_points : myActiveMatch.value?.player2_league_points) ?? null
)
const opponentLeaguePoints = computed(
  () => (amPlayer1.value ? myActiveMatch.value?.player2_league_points : myActiveMatch.value?.player1_league_points) ?? null
)

function openConfirm() {
  signupError.value = ''
  if (!armyListDraft.value.trim()) {
    signupError.value = 'Klistra in din armélista först.'
    return
  }
  showConfirmModal.value = true
}

async function confirmSignup() {
  signupSubmitting.value = true
  signupError.value = ''
  try {
    await submitSignup(armyListDraft.value)
    armyListDraft.value = ''
    showConfirmModal.value = false
  } catch (e) {
    signupError.value = e instanceof Error ? e.message : 'Något gick fel.'
    showConfirmModal.value = false
  } finally {
    signupSubmitting.value = false
  }
}

async function submitReport() {
  if (!myActiveMatch.value) return
  if (myVpDraft.value == null || opponentVpDraft.value == null) {
    reportError.value = 'Fyll i VP för båda spelarna.'
    return
  }
  reportSubmitting.value = true
  reportError.value = ''
  try {
    await reportMatch(myActiveMatch.value.id, myVpDraft.value, opponentVpDraft.value)
    myVpDraft.value = null
    opponentVpDraft.value = null
  } catch (e) {
    reportError.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    reportSubmitting.value = false
  }
}

async function respondToReport(action: 'confirm' | 'dispute') {
  if (!myActiveMatch.value) return
  confirmSubmitting.value = true
  confirmError.value = ''
  try {
    await confirmMatch(myActiveMatch.value.id, action)
  } catch (e) {
    confirmError.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    confirmSubmitting.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl space-y-6">
    <div>
      <h1 class="text-2xl font-semibold text-wh-ink">Hej, {{ profile?.name }}</h1>
      <p class="mt-1 text-wh-mute">Här är läget i ligan just nu.</p>
    </div>

    <div v-if="loaded && !selectedLeague" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
      Du är inte med i någon liga just nu. Kontakta en admin.
    </div>

    <div
      v-else-if="loaded && selectedLeague && !isMember"
      class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute"
    >
      Du är inte medlem i {{ selectedLeague.name }} än. Be en admin lägga till dig.
    </div>

    <template v-else-if="loaded && selectedLeague">
      <div class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <p class="text-sm text-wh-mute">Vald liga</p>
        <p class="mt-1 text-xl font-semibold text-wh-ink">{{ selectedLeague.name }}</p>
        <p v-if="selectedLeague.description" class="mt-1 text-sm text-wh-mute">{{ selectedLeague.description }}</p>
        <p class="mt-2 text-sm text-wh-mute">
          Fas {{ selectedLeague.current_phase }} av {{ selectedLeague.phase_count }} — du har spelat
          {{ myPhaseMatchCount }} av {{ selectedLeague.matches_per_phase }} matcher
        </p>
      </div>

      <!-- Painted units -->
      <div class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="text-lg font-medium text-wh-ink">Målade units</h2>
        <p class="mt-1 text-sm text-wh-mute">
          Ladda upp en bild omålad och en målad för varje unit. En admin granskar och godkänner innan du får dina
          poäng.
        </p>
        <div class="mt-3 flex flex-wrap items-center gap-2">
          <button
            v-for="(unit, index) in PAINTED_UNIT_KEYS"
            :key="unit"
            type="button"
            :title="`Unit ${index + 1}`"
            :class="[
              'flex h-9 w-9 items-center justify-center rounded-md text-sm font-medium transition-colors',
              unitStatusClass(unit)
            ]"
            @click="openUnitModal = unit"
          >
            {{ index + 1 }}
          </button>
          <span class="ml-1 text-sm text-wh-mute">{{ currentUserId ? paintingPointsFor(currentUserId) : 0 }}p</span>
        </div>
      </div>

      <PaintedUnitUploadModal
        v-if="openUnitModal && selectedLeague"
        :league-id="selectedLeague.id"
        :unit-key="openUnitModal"
        :unit-number="PAINTED_UNIT_KEYS.indexOf(openUnitModal) + 1"
        :photo="myPhoto(openUnitModal)"
        @close="openUnitModal = null"
      />

      <!-- Army lists for the current match -->
      <div v-if="myActiveMatch" class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="text-lg font-medium text-wh-ink">Listor</h2>
        <p class="mt-1 text-sm text-wh-mute">Motståndare: {{ profileName(opponentId!) }}</p>
        <p v-if="opponentDiscord" class="text-sm text-wh-mute">Discord: {{ opponentDiscord }}</p>
        <div class="mt-3 flex flex-wrap gap-3">
          <button
            type="button"
            class="rounded-md border border-wh-border px-3 py-1.5 text-sm text-wh-ink hover:border-wh-accent"
            @click="openList = 'mine'"
          >
            Visa din lista
          </button>
          <button
            type="button"
            class="rounded-md border border-wh-border px-3 py-1.5 text-sm text-wh-ink hover:border-wh-accent"
            @click="openList = 'opponent'"
          >
            Visa {{ profileName(opponentId!) }}s lista
          </button>
        </div>
      </div>

      <ListModal
        v-if="openList === 'mine'"
        title="Din lista"
        :army-list="myList"
        @close="openList = null"
      />
      <ListModal
        v-if="openList === 'opponent'"
        :title="`${profileName(opponentId!)}s lista`"
        :army-list="opponentList"
        @close="openList = null"
      />

      <!-- Active match: waiting for report -->
      <div v-if="myActiveMatch && myActiveMatch.status === 'pending'" class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <h2 class="text-lg font-medium text-wh-ink">Din match</h2>
          <NuxtLink
            to="/tracker"
            class="rounded-md border border-wh-border px-3 py-1.5 text-sm text-wh-ink hover:border-wh-accent"
          >
            Öppna matchtracker
          </NuxtLink>
        </div>

        <form class="mt-3 space-y-3" @submit.prevent="submitReport">
          <label class="block text-sm text-wh-mute">Rapportera resultat (VP)</label>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="mb-1 block text-xs text-wh-mute">Dina VP</label>
              <input
                v-model.number="myVpDraft"
                type="number"
                min="0"
                required
                class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
              >
            </div>
            <div>
              <label class="mb-1 block text-xs text-wh-mute">Motståndarens VP</label>
              <input
                v-model.number="opponentVpDraft"
                type="number"
                min="0"
                required
                class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
              >
            </div>
          </div>
          <p v-if="reportError" class="text-sm text-wh-accent">{{ reportError }}</p>
          <button
            type="submit"
            :disabled="reportSubmitting"
            class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
          >
            Rapportera
          </button>
        </form>
      </div>

      <!-- Active match: reported, waiting on me to confirm -->
      <div
        v-else-if="myActiveMatch && myActiveMatch.status === 'reported' && !isReporter"
        class="rounded-lg border border-wh-gold/50 bg-wh-surface p-6"
      >
        <h2 class="text-lg font-medium text-wh-gold">Bekräfta resultat</h2>
        <p class="mt-1 text-sm text-wh-ink">
          {{ profileName(opponentId!) }} rapporterade följande resultat. Stämmer det?
        </p>
        <div class="mt-3 grid grid-cols-2 gap-3 text-sm">
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3">
            <p class="text-wh-mute">Du</p>
            <p class="text-wh-ink">{{ myVp }} VP</p>
            <p class="text-wh-mute">WTC {{ myWtc }} · League Points {{ myLeaguePoints }}</p>
          </div>
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3">
            <p class="text-wh-mute">{{ profileName(opponentId!) }}</p>
            <p class="text-wh-ink">{{ opponentVp }} VP</p>
            <p class="text-wh-mute">WTC {{ opponentWtc }} · League Points {{ opponentLeaguePoints }}</p>
          </div>
        </div>
        <p v-if="confirmError" class="mt-2 text-sm text-wh-accent">{{ confirmError }}</p>
        <div class="mt-4 flex gap-3">
          <button
            type="button"
            :disabled="confirmSubmitting"
            class="rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
            @click="respondToReport('confirm')"
          >
            Ja, stämmer
          </button>
          <button
            type="button"
            :disabled="confirmSubmitting"
            class="rounded-md border border-wh-border px-4 py-2 text-sm text-wh-ink hover:border-wh-accent disabled:opacity-50"
            @click="respondToReport('dispute')"
          >
            Nej, bestrid
          </button>
        </div>
      </div>

      <!-- Active match: reported, waiting on opponent -->
      <div v-else-if="myActiveMatch && myActiveMatch.status === 'reported' && isReporter" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
        Du rapporterade resultatet. Väntar på att {{ profileName(opponentId!) }} bekräftar.
      </div>

      <!-- Active match: disputed, waiting on admin -->
      <div v-else-if="myActiveMatch && myActiveMatch.status === 'disputed'" class="rounded-lg border border-wh-accent/50 bg-wh-surface p-6">
        <h2 class="text-lg font-medium text-wh-accent">Matchen är bestridd</h2>
        <p class="mt-1 text-sm text-wh-ink">
          Resultatet mot {{ profileName(opponentId!) }} bestreds och väntar på att en admin löser det.
        </p>
        <div class="mt-3 grid grid-cols-2 gap-3 text-sm">
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3">
            <p class="text-wh-mute">Du</p>
            <p class="text-wh-ink">{{ myVp }} VP</p>
          </div>
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3">
            <p class="text-wh-mute">{{ profileName(opponentId!) }}</p>
            <p class="text-wh-ink">{{ opponentVp }} VP</p>
          </div>
        </div>
      </div>

      <!-- Ready, waiting to be paired -->
      <div v-else-if="mySignup" class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute">
        Du är anmäld som redo och väntar på att bli lottad mot en motståndare.
      </div>

      <!-- Idle, but this phase's match cap is reached -->
      <div
        v-else-if="myPhaseMatchCount >= selectedLeague.matches_per_phase"
        class="rounded-lg border border-wh-border bg-wh-surface p-6 text-wh-mute"
      >
        Du har spelat max antal matcher ({{ selectedLeague.matches_per_phase }}) för den här fasen. Vänta på att admin
        startar nästa fas.
      </div>

      <!-- Idle: submit a list -->
      <div v-else class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="text-lg font-medium text-wh-ink">Anmäl dig redo för en match</h2>
        <p class="mt-1 text-sm text-wh-mute">Klistra in din fullständiga armélista nedan.</p>
        <textarea
          v-model="armyListDraft"
          rows="10"
          placeholder="Klistra in din armélista här..."
          class="mt-3 w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 font-mono text-sm text-wh-ink outline-none focus:border-wh-accent"
        />
        <p v-if="signupError" class="mt-2 text-sm text-wh-accent">{{ signupError }}</p>
        <button
          type="button"
          class="mt-3 rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
          @click="openConfirm"
        >
          Redo
        </button>
      </div>
    </template>

    <ConfirmListModal
      v-if="showConfirmModal"
      :army-list="armyListDraft"
      @cancel="showConfirmModal = false"
      @confirm="confirmSignup"
    />
  </div>
</template>
