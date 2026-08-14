<script setup lang="ts">
import type { SecondaryEntry } from '~/components/SecondaryTracker.vue'

const { myActiveMatch, reportMatch } = useLeague()
const { name: profileName } = useProfiles()
const currentUserId = useCurrentUserId()
const router = useRouter()

const DISPOSITIONS = ['Take and Hold', 'Purge the Foe', 'Disruption', 'Reconnaissance', 'Priority Assets'] as const
type Disposition = (typeof DISPOSITIONS)[number]

// Sourced from a fan-made 11th edition reference (gamedatamissions.com, "GDM 2026"), not the
// official rulebook. Only the two mirror matchups below were confirmed directly against their
// live matrix tool; the rest is best-effort — flag anything that looks wrong.
const MISSION_MATRIX: Record<Disposition, Record<Disposition, string>> = {
  'Take and Hold': {
    'Take and Hold': 'Battlefield Dominance',
    'Purge the Foe': 'Immovable Object',
    Disruption: 'Determined Acquisition',
    Reconnaissance: 'Purge and Secure',
    'Priority Assets': 'Inescapable Dominion'
  },
  'Purge the Foe': {
    'Take and Hold': 'Unstoppable Force',
    'Purge the Foe': 'Meatgrinder',
    Disruption: 'Punishment',
    Reconnaissance: 'Consecrate',
    'Priority Assets': "Destroyer's Wrath"
  },
  Disruption: {
    'Take and Hold': 'Death Trap',
    'Purge the Foe': 'Delaying Action',
    Disruption: 'Outmanoeuvre',
    Reconnaissance: 'Smoke and Mirrors',
    'Priority Assets': 'Locate and Deny'
  },
  Reconnaissance: {
    'Take and Hold': 'Reconnaissance Sweep',
    'Purge the Foe': 'Triangulation',
    Disruption: 'Surveil the Foe',
    Reconnaissance: 'Gather Intel',
    'Priority Assets': 'Search and Scour'
  },
  'Priority Assets': {
    'Take and Hold': 'Secure Asset',
    'Purge the Foe': 'Vital Link',
    Disruption: 'Extract Relic',
    Reconnaissance: 'Vanguard Operation',
    'Priority Assets': 'Sabotage'
  }
}

const SECONDARY_MISSIONS = [
  'A Grievous Blow',
  'A Tempting Target',
  'Assassination',
  'Beacon',
  'Behind Enemy Lines',
  'Bring it Down',
  'Burden of Trust',
  'Centre Ground',
  'Cleanse',
  'Defend Stronghold',
  'Display of Might',
  'Engage on All Fronts',
  'Forward Position',
  'No Prisoners',
  'Outflank',
  'Overwhelming Force',
  'Plunder',
  "Secure No Man's Land"
]

const myDisposition = ref<Disposition | ''>('')
const opponentDisposition = ref<Disposition | ''>('')

const myMissionName = computed(() => {
  if (!myDisposition.value || !opponentDisposition.value) return null
  return MISSION_MATRIX[myDisposition.value][opponentDisposition.value]
})

const opponentMissionName = computed(() => {
  if (!myDisposition.value || !opponentDisposition.value) return null
  return MISSION_MATRIX[opponentDisposition.value][myDisposition.value]
})

const mySecondaries = ref<SecondaryEntry[]>([])
const opponentSecondaries = ref<SecondaryEntry[]>([])

function availableSecondariesFor(list: SecondaryEntry[]) {
  const chosen = new Set(list.map(s => s.name))
  return SECONDARY_MISSIONS.filter(s => !chosen.has(s))
}

function addSecondary(list: SecondaryEntry[], name: string) {
  list.push({
    name,
    discarded: false,
    expanded: true,
    pointsPerRound: null,
    roundsCompleted: Array.from({ length: 5 }, () => false)
  })
}

function removeSecondary(list: SecondaryEntry[], index: number) {
  list.splice(index, 1)
}

const MAX_POINTS_PER_ROUND = 15

function secondaryPoints(list: SecondaryEntry[]) {
  let total = 0
  for (let round = 0; round < 5; round++) {
    const roundTotal = list
      .filter(s => !s.discarded && s.roundsCompleted[round])
      .reduce((sum, s) => sum + (s.pointsPerRound ?? 0), 0)
    total += Math.min(MAX_POINTS_PER_ROUND, roundTotal)
  }
  return total
}

interface RoundScore {
  myPrimary: number | null
  opponentPrimary: number | null
}

const rounds = ref<RoundScore[]>(Array.from({ length: 5 }, () => ({ myPrimary: null, opponentPrimary: null })))

function clampRoundPoints(value: number | null) {
  if (value == null) return value
  return Math.max(0, Math.min(MAX_POINTS_PER_ROUND, value))
}

const myPrimaryTotal = computed(() =>
  rounds.value.reduce((sum, r) => sum + Math.min(MAX_POINTS_PER_ROUND, r.myPrimary ?? 0), 0)
)
const opponentPrimaryTotal = computed(() =>
  rounds.value.reduce((sum, r) => sum + Math.min(MAX_POINTS_PER_ROUND, r.opponentPrimary ?? 0), 0)
)

const mySecondaryTotal = computed(() => secondaryPoints(mySecondaries.value))
const opponentSecondaryTotal = computed(() => secondaryPoints(opponentSecondaries.value))

const myTotal = computed(() => myPrimaryTotal.value + mySecondaryTotal.value)
const opponentTotal = computed(() => opponentPrimaryTotal.value + opponentSecondaryTotal.value)

const hasReportableMatch = computed(() => !!myActiveMatch.value && myActiveMatch.value.status === 'pending')

const opponentId = computed(() => {
  if (!myActiveMatch.value || !currentUserId.value) return null
  return myActiveMatch.value.player1_id === currentUserId.value
    ? myActiveMatch.value.player2_id
    : myActiveMatch.value.player1_id
})

const opponentLabel = computed(() => (opponentId.value ? profileName(opponentId.value) : 'motståndaren'))

const applyToMatch = ref(hasReportableMatch.value)
watch(hasReportableMatch, val => {
  if (!val) applyToMatch.value = false
})

const reportError = ref('')
const reportSubmitting = ref(false)

async function submitReport() {
  if (!myActiveMatch.value) return
  reportSubmitting.value = true
  reportError.value = ''
  try {
    await reportMatch(myActiveMatch.value.id, myTotal.value, opponentTotal.value)
    router.push('/')
  } catch (e) {
    reportError.value = e instanceof Error ? e.message : 'Något gick fel.'
  } finally {
    reportSubmitting.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl space-y-6">
    <h1 class="text-2xl font-semibold text-wh-ink">Matchtracker</h1>

    <p class="text-sm text-wh-mute">
      <template v-if="hasReportableMatch">Mot {{ opponentLabel }}</template>
      <template v-else>Fristående spårning — inte kopplad till någon ligamatch just nu.</template>
    </p>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-1 text-lg font-medium text-wh-ink">Rapportera till liga</h2>
      <label v-if="hasReportableMatch" class="mt-2 flex items-center gap-2 text-sm text-wh-ink">
        <input v-model="applyToMatch" type="checkbox" class="accent-wh-accent">
        Applicera slutpoängen på min pågående match mot {{ opponentLabel }}
      </label>
      <p v-else class="mt-2 text-sm text-wh-mute">
        Ingen pågående ligamatch att rapportera till just nu — spårningen sparas inte någonstans.
      </p>
    </section>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <h2 class="mb-1 text-lg font-medium text-wh-ink">Disposition</h2>
        <p class="mb-4 text-xs text-wh-mute">
          Från GDM 2026 (fan-gjord 11th edition-referens) — flagga om något ser fel ut.
        </p>
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <label class="mb-1 block text-sm text-wh-mute">Din disposition</label>
            <select
              v-model="myDisposition"
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
              <option value="" disabled>Välj...</option>
              <option v-for="d in DISPOSITIONS" :key="d" :value="d">{{ d }}</option>
            </select>
          </div>
          <div>
            <label class="mb-1 block text-sm text-wh-mute">Motståndarens disposition</label>
            <select
              v-model="opponentDisposition"
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
            >
              <option value="" disabled>Välj...</option>
              <option v-for="d in DISPOSITIONS" :key="d" :value="d">{{ d }}</option>
            </select>
          </div>
        </div>
        <div v-if="myMissionName && opponentMissionName" class="mt-4 grid gap-3 sm:grid-cols-2">
          <div class="rounded-md border border-wh-gold/50 bg-wh-surface-alt p-3 text-sm text-wh-ink">
            <p class="text-xs text-wh-mute">Din primary mission</p>
            <p class="mt-1 font-semibold text-wh-gold">{{ myMissionName }}</p>
          </div>
          <div class="rounded-md border border-wh-gold/50 bg-wh-surface-alt p-3 text-sm text-wh-ink">
            <p class="text-xs text-wh-mute">{{ opponentLabel }}s primary mission</p>
            <p class="mt-1 font-semibold text-wh-gold">{{ opponentMissionName }}</p>
          </div>
        </div>
      </section>

      <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="mb-1 text-lg font-medium text-wh-ink">Secondaries (valfritt)</h2>
        <p class="mb-4 text-xs text-wh-mute">
          Sätt poäng per runda för secondaryn och bocka i vilka rundor du klarade den, så summeras det automatiskt.
          Discarda en secondary för att gråa ut den och nolla dess poäng. Max {{ MAX_POINTS_PER_ROUND }} totala
          secondary-poäng per runda.
        </p>
        <div class="grid gap-4 sm:grid-cols-2">
          <SecondaryTracker
            label="Dina secondaries"
            :entries="mySecondaries"
            :available="availableSecondariesFor(mySecondaries)"
            @add="name => addSecondary(mySecondaries, name)"
            @remove="i => removeSecondary(mySecondaries, i)"
          />
          <SecondaryTracker
            :label="`${opponentLabel}s secondaries`"
            :entries="opponentSecondaries"
            :available="availableSecondariesFor(opponentSecondaries)"
            @add="name => addSecondary(opponentSecondaries, name)"
            @remove="i => removeSecondary(opponentSecondaries, i)"
          />
        </div>
      </section>

      <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="mb-1 text-lg font-medium text-wh-ink">Primary-poäng per runda</h2>
        <p class="mb-4 text-xs text-wh-mute">Max {{ MAX_POINTS_PER_ROUND }} poäng per runda.</p>
        <div class="space-y-3">
          <div v-for="(r, i) in rounds" :key="i" class="rounded-md border border-wh-border p-3">
            <p class="mb-2 text-xs font-medium text-wh-mute">Runda {{ i + 1 }}</p>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="mb-1 block text-xs text-wh-mute">Din primary</label>
                <input
                  v-model.number="r.myPrimary"
                  type="number"
                  min="0"
                  :max="MAX_POINTS_PER_ROUND"
                  inputmode="numeric"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                  @change="r.myPrimary = clampRoundPoints(r.myPrimary)"
                >
              </div>
              <div>
                <label class="mb-1 block text-xs text-wh-mute">Motst. primary</label>
                <input
                  v-model.number="r.opponentPrimary"
                  type="number"
                  min="0"
                  :max="MAX_POINTS_PER_ROUND"
                  inputmode="numeric"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                  @change="r.opponentPrimary = clampRoundPoints(r.opponentPrimary)"
                >
              </div>
            </div>
          </div>
        </div>

        <div class="mt-4 grid grid-cols-2 gap-4">
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3">
            <p class="text-xs text-wh-mute">Din totala VP</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ myTotal }}</p>
            <p class="text-xs text-wh-mute">{{ myPrimaryTotal }} primary + {{ mySecondaryTotal }} secondary</p>
          </div>
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3">
            <p class="text-xs text-wh-mute">{{ opponentLabel }}s totala VP</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ opponentTotal }}</p>
            <p class="text-xs text-wh-mute">
              {{ opponentPrimaryTotal }} primary + {{ opponentSecondaryTotal }} secondary
            </p>
          </div>
        </div>

        <p v-if="reportError" class="mt-3 text-sm text-wh-accent">{{ reportError }}</p>
        <button
          v-if="applyToMatch && hasReportableMatch"
          type="button"
          :disabled="reportSubmitting"
          class="mt-4 rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
          @click="submitReport"
        >
          {{ reportSubmitting ? 'Rapporterar...' : 'Rapportera resultat' }}
        </button>
        <p v-else-if="hasReportableMatch" class="mt-4 text-sm text-wh-mute">
          Bocka i "Rapportera till liga" ovan om du vill applicera detta resultat på din pågående match.
        </p>
        <p v-else class="mt-4 text-sm text-wh-mute">Fristående spårning — sparas inte någonstans.</p>
      </section>
  </div>
</template>
