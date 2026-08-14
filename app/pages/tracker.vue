<script setup lang="ts">
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

const mySecondaries = ref<string[]>([])
const opponentSecondaries = ref<string[]>([])

function availableSecondariesFor(list: string[]) {
  return SECONDARY_MISSIONS.filter(s => !list.includes(s))
}

function addSecondary(list: string[], event: Event) {
  const select = event.target as HTMLSelectElement
  const value = select.value
  select.value = ''
  if (!value) return
  list.push(value)
}

function removeSecondary(list: string[], index: number) {
  list.splice(index, 1)
}

interface RoundScore {
  myPrimary: number | null
  mySecondary: number | null
  opponentPrimary: number | null
  opponentSecondary: number | null
}

const rounds = ref<RoundScore[]>(
  Array.from({ length: 5 }, () => ({
    myPrimary: null,
    mySecondary: null,
    opponentPrimary: null,
    opponentSecondary: null
  }))
)

const myTotal = computed(() => rounds.value.reduce((sum, r) => sum + (r.myPrimary ?? 0) + (r.mySecondary ?? 0), 0))
const opponentTotal = computed(() =>
  rounds.value.reduce((sum, r) => sum + (r.opponentPrimary ?? 0) + (r.opponentSecondary ?? 0), 0)
)

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
        <h2 class="mb-4 text-lg font-medium text-wh-ink">Secondaries (valfritt)</h2>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <p class="mb-1 text-xs text-wh-mute">Dina secondaries</p>
            <ul class="space-y-1">
              <li
                v-for="(s, i) in mySecondaries"
                :key="s"
                class="flex items-center justify-between gap-2 rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-sm text-wh-ink"
              >
                {{ s }}
                <button type="button" class="text-wh-mute hover:text-wh-accent" @click="removeSecondary(mySecondaries, i)">
                  ✕
                </button>
              </li>
            </ul>
            <select
              value=""
              class="mt-1 w-full rounded-md border border-dashed border-wh-border bg-wh-surface-alt px-3 py-2 text-sm text-wh-mute outline-none focus:border-wh-accent"
              @change="addSecondary(mySecondaries, $event)"
            >
              <option value="" disabled selected>+ Lägg till secondary</option>
              <option v-for="s in availableSecondariesFor(mySecondaries)" :key="s" :value="s">{{ s }}</option>
            </select>
          </div>
          <div>
            <p class="mb-1 text-xs text-wh-mute">{{ opponentLabel }}s secondaries</p>
            <ul class="space-y-1">
              <li
                v-for="(s, i) in opponentSecondaries"
                :key="s"
                class="flex items-center justify-between gap-2 rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-sm text-wh-ink"
              >
                {{ s }}
                <button
                  type="button"
                  class="text-wh-mute hover:text-wh-accent"
                  @click="removeSecondary(opponentSecondaries, i)"
                >
                  ✕
                </button>
              </li>
            </ul>
            <select
              value=""
              class="mt-1 w-full rounded-md border border-dashed border-wh-border bg-wh-surface-alt px-3 py-2 text-sm text-wh-mute outline-none focus:border-wh-accent"
              @change="addSecondary(opponentSecondaries, $event)"
            >
              <option value="" disabled selected>+ Lägg till secondary</option>
              <option v-for="s in availableSecondariesFor(opponentSecondaries)" :key="s" :value="s">{{ s }}</option>
            </select>
          </div>
        </div>
      </section>

      <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="mb-4 text-lg font-medium text-wh-ink">Poäng per runda</h2>
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
                  inputmode="numeric"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                >
              </div>
              <div>
                <label class="mb-1 block text-xs text-wh-mute">Din secondary</label>
                <input
                  v-model.number="r.mySecondary"
                  type="number"
                  min="0"
                  inputmode="numeric"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                >
              </div>
              <div>
                <label class="mb-1 block text-xs text-wh-mute">Motst. primary</label>
                <input
                  v-model.number="r.opponentPrimary"
                  type="number"
                  min="0"
                  inputmode="numeric"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                >
              </div>
              <div>
                <label class="mb-1 block text-xs text-wh-mute">Motst. secondary</label>
                <input
                  v-model.number="r.opponentSecondary"
                  type="number"
                  min="0"
                  inputmode="numeric"
                  class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent"
                >
              </div>
            </div>
          </div>
        </div>

        <div class="mt-4 grid grid-cols-2 gap-4">
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3">
            <p class="text-xs text-wh-mute">Din totala VP</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ myTotal }}</p>
          </div>
          <div class="rounded-md border border-wh-border bg-wh-surface-alt p-3">
            <p class="text-xs text-wh-mute">{{ opponentLabel }}s totala VP</p>
            <p class="mt-1 text-xl font-semibold text-wh-ink">{{ opponentTotal }}</p>
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
