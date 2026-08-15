<script setup lang="ts">
import type { SecondaryEntry } from '~/components/SecondaryTracker.vue'
import type { PrimaryMissionOption } from '~/components/PrimaryMissionScoring.vue'
import type { TrackerMatch } from '~/types'
import { primaryMissionTotal } from '~/utils/primaryScoring'

const { myActiveMatch, reportMatch } = useLeague()
const { name: profileName } = useProfiles()
const currentUserId = useCurrentUserId()
const router = useRouter()
const {
  matches: savedMatches,
  loaded: matchesLoaded,
  refresh: refreshMatches,
  createMatch,
  updateMatch,
  deleteMatch,
  setSavedToHistory,
  expiresAt
} = useTrackerMatches()

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

const END_OF_YOUR_TURN = 'End of your turn'
const END_OF_OPPONENT_TURN = "End of opponent's turn"
const END_OF_EITHER_TURN = "End of either player's turn"
const END_OF_OPPONENT_TURN_OR_R5 = "End of opponent's turn / end of round 5"

// Scoring conditions summarized in our own words from the GDM 2026 defender cards (11th ed.),
// not transcribed rule text — labels, point values, and timing, fixed per secondary.
const DEFAULT_SECONDARY_OPTIONS: Record<string, { label: string; points: number; timing: string }[]> = {
  'A Grievous Blow': [
    { label: '1+ enemy unit (starting strength 13+) destroyed this turn', points: 5, timing: END_OF_EITHER_TURN }
  ],
  'A Tempting Target': [{ label: 'Control my tempting target objective', points: 5, timing: END_OF_YOUR_TURN }],
  Assassination: [
    { label: '1+ enemy CHARACTER destroyed this turn', points: 5, timing: END_OF_EITHER_TURN },
    { label: 'All enemy CHARACTERS destroyed during the battle', points: 5, timing: END_OF_EITHER_TURN }
  ],
  Beacon: [
    { label: "Beacon unit on the battlefield, outside my deployment zone", points: 3, timing: END_OF_OPPONENT_TURN_OR_R5 },
    { label: 'Beacon unit on the battlefield, outside my territory', points: 5, timing: END_OF_OPPONENT_TURN_OR_R5 }
  ],
  'Behind Enemy Lines': [
    { label: "Each unit wholly within opponent's deployment zone (max 5p)", points: 3, timing: END_OF_YOUR_TURN }
  ],
  'Bring it Down': [{ label: '1+ enemy model (W10+) destroyed this turn', points: 5, timing: END_OF_EITHER_TURN }],
  'Burden of Trust': [{ label: 'Each objective guarded (max 5p)', points: 2, timing: END_OF_OPPONENT_TURN_OR_R5 }],
  'Centre Ground': [
    { label: 'Unit within 3" of centre, no enemy within 3"', points: 3, timing: END_OF_YOUR_TURN },
    { label: 'Unit within 3" of centre, no enemy within 6"', points: 5, timing: END_OF_YOUR_TURN }
  ],
  Cleanse: [
    { label: 'One objective cleansed this turn', points: 2, timing: END_OF_YOUR_TURN },
    { label: 'Two or more objectives cleansed this turn', points: 5, timing: END_OF_YOUR_TURN }
  ],
  'Defend Stronghold': [
    { label: 'Control home objective', points: 3, timing: END_OF_OPPONENT_TURN_OR_R5 },
    { label: 'Bonus: no enemy in my deployment zone', points: 2, timing: END_OF_OPPONENT_TURN_OR_R5 }
  ],
  'Display of Might': [
    { label: "More units than the enemy in No Man's Land (my turn)", points: 2, timing: END_OF_YOUR_TURN },
    { label: "More units than the enemy in No Man's Land (opponent's turn)", points: 5, timing: END_OF_OPPONENT_TURN }
  ],
  'Engage on All Fronts': [
    { label: 'Presence in three table quarters', points: 3, timing: END_OF_YOUR_TURN },
    { label: 'Presence in four table quarters', points: 5, timing: END_OF_YOUR_TURN }
  ],
  'Forward Position': [
    { label: "Control opponent's home objective and/or each expansion objective", points: 5, timing: END_OF_YOUR_TURN }
  ],
  'No Prisoners': [{ label: 'Each enemy unit destroyed this turn (max 5p)', points: 2, timing: END_OF_EITHER_TURN }],
  Outflank: [
    { label: '1+ unit within 6" of a battlefield edge, outside my territory', points: 3, timing: END_OF_YOUR_TURN },
    {
      label: '2+ units within 6" of opposite edges, at least one outside my territory',
      points: 5,
      timing: END_OF_YOUR_TURN
    }
  ],
  'Overwhelming Force': [
    { label: 'Each enemy unit at an objective destroyed this turn (max 5p)', points: 3, timing: END_OF_EITHER_TURN }
  ],
  Plunder: [{ label: 'Terrain feature plundered this turn', points: 5, timing: END_OF_YOUR_TURN }],
  "Secure No Man's Land": [{ label: "Control 2+ objectives in No Man's Land", points: 5, timing: END_OF_YOUR_TURN }]
}

// Short functional summaries in our own words, not card flavour text.
const SECONDARY_DESCRIPTIONS: Record<string, string> = {
  'A Grievous Blow': 'Points for destroying large enemy units (starting strength 13+).',
  'A Tempting Target': 'Your opponent picks one of your objectives that you must defend.',
  Assassination: 'Points for destroying enemy CHARACTERS.',
  Beacon: 'Keep a chosen unit ("beacon") outside your own deployment zone/territory.',
  'Behind Enemy Lines': "Points for units inside the opponent's deployment zone.",
  'Bring it Down': 'Points for destroying tough enemy models (W10+).',
  'Burden of Trust': 'Points for objectives "guarded" by one of your units.',
  'Centre Ground': 'Points for holding the centre of the table free of enemies.',
  Cleanse: 'Points for "cleansing" objectives with a unit in your shooting phase.',
  'Defend Stronghold': 'Points for holding your home objective and deployment zone free of enemies.',
  'Display of Might': "Points for having more units than the enemy in No Man's Land.",
  'Engage on All Fronts': 'Points for having presence in multiple table quarters at once.',
  'Forward Position': "Points for controlling your opponent's objectives.",
  'No Prisoners': 'Points for every enemy unit you destroy.',
  Outflank: 'Points for units near the battlefield edges, outside your own territory.',
  'Overwhelming Force': 'Points for destroying enemies that were holding an objective.',
  Plunder: 'Plunder a terrain feature with a unit in your shooting phase.',
  "Secure No Man's Land": "Points for controlling multiple objectives in No Man's Land."
}

interface PrimaryScoringOption {
  label: string
  points: number
  timing: string
  rounds: number[]
  tierGroup?: string
  tierCount?: number
  scalesWithTierGroup?: string
}

const R_ANY = [1, 2, 3, 4, 5]
const R_1 = [1]
const R_2_5 = [2, 3, 4, 5]
const R_2_4 = [2, 3, 4]
const R_5 = [5]
const R_2_3 = [2, 3]
const R_4_5 = [4, 5]

const T_TURN = END_OF_YOUR_TURN
const T_CMD = 'End of your Command phase (end of your turn in round 5)'
const T_BATTLE_END = 'End of the battle'

function countTiers(
  rate: number,
  rounds: number[],
  timing: string,
  labelFor: (n: number, plus: string) => string,
  max = 4,
  tierGroup?: string
): PrimaryScoringOption[] {
  return Array.from({ length: max }, (_, i) => {
    const n = i + 1
    const plus = n === max ? '+' : ''
    return { label: labelFor(n, plus), points: rate * n, timing, rounds, tierGroup, tierCount: n }
  })
}

function objectiveTiers(
  rate: number,
  rounds: number[],
  timing: string,
  max = 4,
  tierGroup?: string
): PrimaryScoringOption[] {
  return countTiers(
    rate,
    rounds,
    timing,
    (n, plus) => `Control ${n}${plus} objective${n > 1 ? 's' : ''} (excl. home)`,
    max,
    tierGroup
  )
}

// Scoring conditions summarized in our own words from the GDM 2026 primary mission cards (11th ed.),
// not transcribed rule text. "For each X" style conditions are modeled as pre-multiplied count tiers
// (1 / 2 / 3 / 4+) rather than a single flat checkbox, so ticking one tier reflects the real total.
const PRIMARY_MISSION_SCORING: Record<string, PrimaryScoringOption[]> = {
  'Battlefield Dominance': [
    { label: 'Control more objectives than your opponent', points: 2, timing: T_TURN, rounds: [1, 2] },
    ...objectiveTiers(3, R_2_5, T_CMD, 4, 'bd-objectives'),
    {
      label: 'Also control your home objective',
      points: 2,
      timing: T_CMD,
      rounds: R_2_5,
      scalesWithTierGroup: 'bd-objectives'
    }
  ],
  'Immovable Object': [
    { label: 'Control one or more central objectives', points: 3, timing: T_TURN, rounds: R_ANY },
    ...objectiveTiers(5, R_2_4, T_CMD),
    ...objectiveTiers(5, R_5, T_TURN)
  ],
  'Determined Acquisition': [
    ...countTiers(
      2,
      R_ANY,
      T_TURN,
      (n, plus) => `${n}${plus} objective${n > 1 ? 's' : ''} you didn't control at the start of the turn (excl. home)`
    ),
    ...objectiveTiers(3, R_2_5, T_CMD),
    { label: "Bonus: those objectives are in your opponent's territory", points: 3, timing: T_CMD, rounds: R_2_5 }
  ],
  'Purge and Secure': [
    { label: 'One or more enemy units destroyed this turn by a friendly unit near an objective', points: 3, timing: T_TURN, rounds: R_ANY },
    { label: 'One or more enemy units that started the turn near an objective were destroyed this turn', points: 3, timing: T_TURN, rounds: R_ANY },
    ...objectiveTiers(4, R_2_5, T_CMD),
    ...countTiers(
      3,
      R_2_5,
      T_TURN,
      (n, plus) => `${n}${plus} objective${n > 1 ? 's' : ''} you didn't control at the start of the turn (excl. home)`
    )
  ],
  'Inescapable Dominion': [
    { label: 'Control three or more objectives', points: 4, timing: T_TURN, rounds: R_ANY },
    { label: 'Control two or more objectives', points: 5, timing: T_CMD, rounds: R_2_5 },
    { label: 'Control more objectives than your opponent', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: "Control your opponent's home objective", points: 5, timing: T_BATTLE_END, rounds: R_5 }
  ],
  'Unstoppable Force': [
    { label: 'One or more enemy units destroyed this turn', points: 3, timing: T_TURN, rounds: R_ANY },
    ...objectiveTiers(4, R_2_5, T_CMD),
    { label: 'Control one or more objectives you did not control at the start of the turn (excl. home)', points: 3, timing: T_TURN, rounds: R_2_5 },
    { label: 'Control one or more central objectives', points: 5, timing: T_BATTLE_END, rounds: R_5 }
  ],
  Meatgrinder: [
    { label: 'One or more enemy units destroyed this turn', points: 3, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'More enemy units destroyed this turn than friendly units destroyed last turn', points: 5, timing: T_TURN, rounds: R_2_5 },
    { label: "Control your opponent's home objective", points: 5, timing: T_TURN, rounds: R_2_5 }
  ],
  Punishment: [
    { label: 'One or more marked ("condemned") enemy units left the battlefield this turn', points: 5, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Control more objectives than your opponent', points: 5, timing: T_CMD, rounds: R_2_5 },
    { label: "Control your opponent's home objective", points: 8, timing: T_BATTLE_END, rounds: R_5 }
  ],
  Consecrate: [
    { label: 'One or two objectives are "consecrated"', points: 3, timing: T_TURN, rounds: R_ANY },
    { label: 'Three or more objectives are "consecrated"', points: 6, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Control more objectives than your opponent', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Your opponent\'s home objective is "consecrated"', points: 5, timing: T_BATTLE_END, rounds: R_5 }
  ],
  "Destroyer's Wrath": [
    { label: 'One or more enemy units destroyed this turn', points: 3, timing: T_TURN, rounds: R_ANY },
    ...objectiveTiers(4, R_2_5, T_CMD),
    { label: 'Control more objectives than your opponent', points: 6, timing: T_CMD, rounds: R_2_5 },
    { label: 'More enemy units destroyed this turn than friendly units destroyed last turn', points: 4, timing: T_TURN, rounds: R_2_5 }
  ],
  'Gather Intel': [
    { label: 'Control one or more central objectives', points: 6, timing: T_TURN, rounds: R_1 },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    ...countTiers(
      7,
      R_2_5,
      T_TURN,
      (n, plus) => `${n}${plus} friendly unit${n > 1 ? 's' : ''} completed the "Extract Intelligence" action this turn`
    ),
    { label: 'Three or more of your operation markers are on the battlefield', points: 5, timing: T_BATTLE_END, rounds: R_5 },
    { label: "One of your operation markers is near your opponent's home objective", points: 5, timing: T_BATTLE_END, rounds: R_5 }
  ],
  'Reconnaissance Sweep': [
    { label: 'Three or more friendly units spread across different table quarters, away from the centre', points: 3, timing: T_TURN, rounds: R_ANY },
    { label: 'Four or more friendly units spread across different table quarters, away from the centre', points: 6, timing: T_TURN, rounds: R_ANY },
    ...countTiers(1, R_ANY, T_TURN, (n, plus) => `${n}${plus} enemy unit${n > 1 ? 's' : ''} destroyed this turn`),
    { label: 'Control one or more objectives (excl. home)', points: 3, timing: T_CMD, rounds: R_2_5 }
  ],
  'Surveil the Foe': [
    { label: 'One or more enemy units were "surveilled" this turn', points: 4, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Control more objectives than your opponent', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: "None of your opponent's operation markers are on the battlefield", points: 5, timing: T_TURN, rounds: R_2_5 }
  ],
  Triangulation: [
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'One objective is "triangulated"', points: 3, timing: T_TURN, rounds: R_2_5 },
    { label: 'Two objectives are "triangulated"', points: 6, timing: T_TURN, rounds: R_2_5 },
    { label: 'Three or more objectives are "triangulated"', points: 10, timing: T_TURN, rounds: R_2_5 },
    { label: 'Control four or more objectives', points: 10, timing: T_BATTLE_END, rounds: R_5 }
  ],
  'Search and Scour': [
    { label: 'Control one or more central objectives', points: 3, timing: T_TURN, rounds: R_ANY },
    { label: 'One or more enemy units that started the turn in a terrain area were destroyed this turn', points: 2, timing: T_TURN, rounds: R_ANY },
    ...objectiveTiers(4, R_2_5, T_CMD),
    { label: 'No enemy units are wholly within your territory', points: 5, timing: T_BATTLE_END, rounds: R_5 }
  ],
  'Secure Asset': [
    { label: 'A friendly unit "secured the asset" this turn', points: 4, timing: T_TURN, rounds: R_ANY },
    { label: 'One or more enemy units that started the turn near a central objective were destroyed this turn', points: 2, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Control three or more objectives', points: 4, timing: T_CMD, rounds: R_2_5 }
  ],
  'Vital Link': [
    { label: 'Control one or more central objectives', points: 2, timing: T_TURN, rounds: R_ANY },
    { label: 'Bonus: one of your operation markers is near one of those objectives', points: 1, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Bonus: one or more of those objectives is a central objective', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: "Control your opponent's home objective", points: 10, timing: T_BATTLE_END, rounds: R_5 }
  ],
  'Extract Relic': [
    { label: 'A friendly unit performed a "sensor sweep" this turn', points: 4, timing: T_TURN, rounds: R_ANY },
    { label: 'One or more enemy units that started the turn near an objective were destroyed this turn', points: 3, timing: T_TURN, rounds: R_ANY },
    { label: "Only one of your opponent's operation markers is on the battlefield, isolated from enemies", points: 4, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: "Only one of your opponent's operation markers is on the battlefield, isolated from enemies", points: 5, timing: T_BATTLE_END, rounds: R_5 }
  ],
  'Vanguard Operation': [
    { label: 'A friendly unit performed a "vanguard operation" this turn', points: 4, timing: T_TURN, rounds: R_ANY },
    { label: 'One or more enemy units destroyed this turn', points: 2, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: "Control your opponent's home objective", points: 10, timing: T_BATTLE_END, rounds: R_5 }
  ],
  Sabotage: [
    ...countTiers(3, R_ANY, T_TURN, (n, plus) => `${n}${plus} friendly unit${n > 1 ? 's' : ''} "committed sabotage" this turn`),
    { label: "Bonus: those units are near an objective in your opponent's territory", points: 2, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 }
  ],
  Outmanoeuvre: [
    { label: "Control your opponent's home objective", points: 10, timing: T_TURN, rounds: R_ANY },
    ...objectiveTiers(4, R_1, T_TURN),
    ...objectiveTiers(5, R_2_3, T_CMD),
    ...objectiveTiers(6, R_4_5, T_TURN)
  ],
  'Death Trap': [
    ...countTiers(2, R_ANY, T_TURN, (n, plus) => `${n}${plus} terrain area${n > 1 ? 's' : ''} "trapped" this turn`),
    { label: 'Bonus: those terrain areas are objectives', points: 3, timing: T_TURN, rounds: R_ANY },
    { label: 'One or more enemy units that started the turn in a trapped terrain area were destroyed this turn', points: 3, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 }
  ],
  'Delaying Action': [
    ...countTiers(2, R_ANY, T_TURN, (n, plus) => `${n}${plus} enemy unit${n > 1 ? 's' : ''} destroyed this turn`),
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Control one or more central objectives and one or more expansion objectives', points: 3, timing: T_TURN, rounds: R_2_5 }
  ],
  'Locate and Deny': [
    { label: 'One or more enemy units that started the turn near an objective were destroyed this turn', points: 4, timing: T_TURN, rounds: R_ANY },
    { label: 'Only one of your operation markers is on the battlefield, isolated from enemies', points: 4, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Only one of your operation markers is on the battlefield, isolated from enemies', points: 5, timing: T_BATTLE_END, rounds: R_5 }
  ],
  'Smoke and Mirrors': [
    ...countTiers(2, R_ANY, T_TURN, (n, plus) => `${n}${plus} objective${n > 1 ? 's' : ''} "decoyed"`),
    { label: "Bonus: those objectives are in your opponent's territory", points: 2, timing: T_TURN, rounds: R_ANY },
    { label: 'Control one or more objectives (excl. home)', points: 4, timing: T_CMD, rounds: R_2_5 },
    { label: 'Four or more objectives are "decoyed"', points: 10, timing: T_BATTLE_END, rounds: R_5 }
  ]
}

// Short functional summaries in our own words, not card flavour text.
const PRIMARY_MISSION_DESCRIPTIONS: Record<string, string> = {
  'Battlefield Dominance': 'Score for holding more objectives than your opponent, then for every objective you control from round 2 on.',
  'Immovable Object': 'Score for holding the central objectives, then for every objective you control from round 2 on.',
  'Determined Acquisition': 'Score for objectives you newly take each turn, then for every objective you control from round 2 on.',
  'Purge and Secure': 'Score for destroying enemies near objectives, then for every objective you control or newly take.',
  'Inescapable Dominion': "Score for controlling several objectives at once, then a bonus for your opponent's home objective at the end.",
  'Unstoppable Force': 'Score for destroying enemies, then for every objective you control from round 2 on.',
  Meatgrinder: "Score for destroying enemies and out-killing your own previous round's losses.",
  Punishment: 'Mark enemy units at the start of your turn, then score when those marked units are destroyed.',
  Consecrate: 'Mark objectives when a unit destroys an enemy near them, then score for how many are marked.',
  "Destroyer's Wrath": 'Score for destroying enemies and holding more objectives than your opponent.',
  'Gather Intel': 'Score for holding the centre early, then for objectives controlled and units gathering intel.',
  'Reconnaissance Sweep': 'Score for spreading friendly units across the table and for destroying enemies.',
  'Surveil the Foe': 'Score for "surveilling" enemy units and for controlling objectives.',
  Triangulation: 'Score for how many objectives you "triangulate", then a big bonus for controlling most objectives at the end.',
  'Search and Scour': 'Score for holding the centre and destroying enemies near terrain, then for objectives controlled.',
  'Secure Asset': 'Score for "securing the asset" and for objectives controlled.',
  'Vital Link': "Score for holding central objectives with markers nearby, then for objectives controlled, then a big bonus for your opponent's home objective.",
  'Extract Relic': 'Score for "sensor sweep" actions and objectives controlled, with a bonus at the end.',
  'Vanguard Operation': "Score for \"vanguard operation\" actions and destroying enemies, with a big bonus for your opponent's home objective.",
  Sabotage: 'Score for units that "committed sabotage", then for objectives controlled.',
  Outmanoeuvre: "Score for objectives controlled, at an increasing rate each round, plus a big bonus for your opponent's home objective.",
  'Death Trap': 'Score for "trapping" terrain areas and destroying enemies caught inside them.',
  'Delaying Action': 'Score for destroying enemies, then for objectives controlled, then for holding a central and expansion objective together.',
  'Locate and Deny': 'Score for destroying enemies near objectives and for keeping a lone operation marker safe.',
  'Smoke and Mirrors': 'Score for "decoying" objectives, then for objectives controlled.'
}

function buildPrimaryOptions(name: string | null): PrimaryMissionOption[] {
  if (!name) return []
  const schema = PRIMARY_MISSION_SCORING[name] ?? []
  return schema.map(o => ({
    label: o.label,
    points: o.points,
    timing: o.timing,
    rounds: o.rounds,
    tierGroup: o.tierGroup,
    tierCount: o.tierCount,
    scalesWithTierGroup: o.scalesWithTierGroup,
    roundsCompleted: Array.from({ length: 5 }, () => false)
  }))
}

const myDisposition = ref<Disposition | ''>('')
const opponentDisposition = ref<Disposition | ''>('')
const dispositionsLocked = ref(false)

const myMissionName = computed(() => {
  if (!myDisposition.value || !opponentDisposition.value) return null
  return MISSION_MATRIX[myDisposition.value][opponentDisposition.value]
})

const opponentMissionName = computed(() => {
  if (!myDisposition.value || !opponentDisposition.value) return null
  return MISSION_MATRIX[opponentDisposition.value][myDisposition.value]
})

const myPrimaryOptions = ref<PrimaryMissionOption[]>(buildPrimaryOptions(myMissionName.value))
const opponentPrimaryOptions = ref<PrimaryMissionOption[]>(buildPrimaryOptions(opponentMissionName.value))

// Set while restoring a saved match so the mission-name watchers below don't wipe the
// restored round-completion state with a freshly built (all-unticked) options array.
let hydrating = false

watch(myMissionName, name => {
  if (hydrating) return
  myPrimaryOptions.value = buildPrimaryOptions(name)
})
watch(opponentMissionName, name => {
  if (hydrating) return
  opponentPrimaryOptions.value = buildPrimaryOptions(name)
})

const mySecondaries = ref<SecondaryEntry[]>([])
const opponentSecondaries = ref<SecondaryEntry[]>([])

function availableSecondariesFor(list: SecondaryEntry[]) {
  const chosen = new Set(list.map(s => s.name))
  return SECONDARY_MISSIONS.filter(s => !chosen.has(s))
}

function addSecondary(list: SecondaryEntry[], name: string) {
  const defaults = DEFAULT_SECONDARY_OPTIONS[name] ?? []
  list.push({
    name,
    discarded: false,
    options: defaults.map(d => ({
      label: d.label,
      points: d.points,
      timing: d.timing,
      roundsCompleted: Array.from({ length: 5 }, () => false)
    }))
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
      .filter(s => !s.discarded)
      .reduce(
        (sum, s) =>
          sum +
          s.options.filter(o => o.roundsCompleted[round]).reduce((a, o) => a + (o.points ?? 0), 0),
        0
      )
    total += Math.min(MAX_POINTS_PER_ROUND, roundTotal)
  }
  return total
}

const myPrimaryTotal = computed(() =>
  myMissionName.value ? primaryMissionTotal(myPrimaryOptions.value, MAX_POINTS_PER_ROUND) : 0
)
const opponentPrimaryTotal = computed(() =>
  opponentMissionName.value ? primaryMissionTotal(opponentPrimaryOptions.value, MAX_POINTS_PER_ROUND) : 0
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

const opponentLabel = computed(() => (opponentId.value ? profileName(opponentId.value) : 'the opponent'))

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
    reportError.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    reportSubmitting.value = false
  }
}

// --- Saved match list -------------------------------------------------------

const currentMatchId = ref<string | null>(null)
const currentMatch = computed(() => savedMatches.value.find(m => m.id === currentMatchId.value) ?? null)
const showNewMatchForm = ref(false)
const newMatchName = ref('')
const matchesError = ref('')

function matchDisplayName(match: TrackerMatch) {
  if (match.name) return match.name
  if (match.my_disposition && match.opponent_disposition) return `${match.my_disposition} vs ${match.opponent_disposition}`
  return 'New match'
}

function persistedMatchKey() {
  return currentUserId.value ? `wh-tracker-match:${currentUserId.value}` : null
}

function loadPersistedMatchId(): string | null {
  const key = persistedMatchKey()
  if (!key || typeof window === 'undefined') return null
  return window.localStorage.getItem(key)
}

function persistMatchId(id: string | null) {
  const key = persistedMatchKey()
  if (!key || typeof window === 'undefined') return
  if (id) window.localStorage.setItem(key, id)
  else window.localStorage.removeItem(key)
}

async function openMatch(match: TrackerMatch) {
  hydrating = true
  myDisposition.value = ((match.my_disposition as Disposition) ?? '') as Disposition | ''
  opponentDisposition.value = ((match.opponent_disposition as Disposition) ?? '') as Disposition | ''
  myPrimaryOptions.value = (match.my_primary_options as PrimaryMissionOption[]) ?? []
  opponentPrimaryOptions.value = (match.opponent_primary_options as PrimaryMissionOption[]) ?? []
  mySecondaries.value = (match.my_secondaries as SecondaryEntry[]) ?? []
  opponentSecondaries.value = (match.opponent_secondaries as SecondaryEntry[]) ?? []
  applyToMatch.value = match.apply_to_match ?? hasReportableMatch.value
  dispositionsLocked.value = false
  currentMatchId.value = match.id
  persistMatchId(match.id)
  await nextTick()
  hydrating = false
}

function closeMatch() {
  currentMatchId.value = null
  persistMatchId(null)
}

async function startNewMatch() {
  matchesError.value = ''
  try {
    const created = await createMatch(newMatchName.value)
    newMatchName.value = ''
    showNewMatchForm.value = false
    await openMatch(created)
  } catch (e) {
    matchesError.value = e instanceof Error ? e.message : 'Something went wrong.'
  }
}

async function removeMatch(match: TrackerMatch) {
  matchesError.value = ''
  try {
    await deleteMatch(match.id)
    if (currentMatchId.value === match.id) closeMatch()
  } catch (e) {
    matchesError.value = e instanceof Error ? e.message : 'Something went wrong.'
  }
}

async function toggleHistory(match: TrackerMatch) {
  matchesError.value = ''
  try {
    await setSavedToHistory(match.id, !match.saved_to_history)
  } catch (e) {
    matchesError.value = e instanceof Error ? e.message : 'Something went wrong.'
  }
}

let saveTimeout: ReturnType<typeof setTimeout> | null = null

function scheduleSave() {
  if (hydrating || !currentMatchId.value) return
  if (saveTimeout) clearTimeout(saveTimeout)
  const id = currentMatchId.value
  saveTimeout = setTimeout(() => {
    updateMatch(id, {
      my_disposition: myDisposition.value || null,
      opponent_disposition: opponentDisposition.value || null,
      my_primary_options: myPrimaryOptions.value,
      opponent_primary_options: opponentPrimaryOptions.value,
      my_secondaries: mySecondaries.value,
      opponent_secondaries: opponentSecondaries.value,
      apply_to_match: applyToMatch.value
    })
  }, 600)
}

watch([myDisposition, opponentDisposition, applyToMatch], scheduleSave)
watch([myPrimaryOptions, opponentPrimaryOptions, mySecondaries, opponentSecondaries], scheduleSave, { deep: true })

onMounted(async () => {
  await refreshMatches()
  const persisted = loadPersistedMatchId()
  const match = persisted ? savedMatches.value.find(m => m.id === persisted) : null
  if (match) await openMatch(match)
})
</script>

<template>
  <div class="max-w-2xl space-y-6">
    <h1 class="text-2xl font-semibold text-wh-ink">Match Tracker</h1>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="flex items-center justify-between gap-2">
        <h2 class="text-lg font-medium text-wh-ink">Your matches</h2>
        <button
          type="button"
          class="shrink-0 rounded-md border border-dashed border-wh-border px-3 py-1.5 text-xs text-wh-ink hover:border-wh-accent"
          @click="showNewMatchForm = !showNewMatchForm"
        >
          + New match
        </button>
      </div>
      <p class="mt-1 text-xs text-wh-mute">
        Matches are kept for 3 days unless you save them to your history.
      </p>

      <div v-if="showNewMatchForm" class="mt-3 flex flex-wrap items-center gap-2">
        <input
          v-model="newMatchName"
          type="text"
          maxlength="50"
          placeholder="Match name (optional)"
          class="min-w-0 flex-1 rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-sm text-wh-ink outline-none focus:border-wh-accent"
          @keyup.enter="startNewMatch"
        >
        <button
          type="button"
          class="rounded-md bg-wh-accent px-3 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover"
          @click="startNewMatch"
        >
          Create
        </button>
      </div>

      <p v-if="matchesError" class="mt-3 text-sm text-wh-accent">{{ matchesError }}</p>

      <ul v-if="savedMatches.length" class="mt-3 space-y-1">
        <li
          v-for="match in savedMatches"
          :key="match.id"
          class="flex items-center gap-2 rounded-md border px-3 py-2 text-sm"
          :class="match.id === currentMatchId ? 'border-wh-gold bg-wh-surface-alt' : 'border-wh-border'"
        >
          <button type="button" class="min-w-0 flex-1 text-left text-wh-ink" @click="openMatch(match)">
            <span class="block truncate">{{ matchDisplayName(match) }}</span>
            <span class="block text-xs text-wh-mute">
              {{ new Date(match.created_at).toLocaleDateString() }}
              <template v-if="!match.saved_to_history">
                — expires {{ expiresAt(match).toLocaleDateString() }}
              </template>
              <template v-else> — saved to history</template>
            </span>
          </button>
          <button
            type="button"
            :title="match.saved_to_history ? 'Remove from history (3-day expiry resumes)' : 'Save to history (never expires)'"
            class="shrink-0 rounded-md border border-wh-border px-2 py-1 text-xs text-wh-mute hover:border-wh-gold hover:text-wh-ink"
            @click="toggleHistory(match)"
          >
            {{ match.saved_to_history ? '★' : '☆' }}
          </button>
          <button
            type="button"
            title="Delete match"
            class="shrink-0 rounded-md border border-wh-border px-2 py-1 text-xs text-wh-mute hover:border-wh-accent hover:text-wh-ink"
            @click="removeMatch(match)"
          >
            ✕
          </button>
        </li>
      </ul>
      <p v-else-if="matchesLoaded" class="mt-3 text-sm text-wh-mute">No saved matches yet.</p>
    </section>

    <p v-if="!currentMatch" class="text-sm text-wh-mute">
      Open a match above, or start a new one, to begin tracking.
    </p>

    <template v-else>
    <p class="text-sm text-wh-mute">
      <template v-if="hasReportableMatch">Vs {{ opponentLabel }}</template>
      <template v-else>Standalone tracking — not linked to a league match right now.</template>
    </p>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-4">
      <h2 class="mb-2 text-lg font-medium text-wh-ink">Score</h2>
      <div class="grid grid-cols-2 gap-3">
        <div
          class="rounded-md border p-3"
          :class="
            myTotal > opponentTotal
              ? 'border-emerald-500/50 bg-emerald-500/10'
              : myTotal < opponentTotal
                ? 'border-wh-accent/50 bg-wh-accent/10'
                : 'border-wh-border bg-wh-surface-alt'
          "
        >
          <p class="text-xs text-wh-mute">You</p>
          <p class="text-xl font-semibold text-wh-ink">{{ myTotal }}</p>
          <p class="text-xs text-wh-mute">{{ myPrimaryTotal }} primary + {{ mySecondaryTotal }} secondary</p>
        </div>
        <div
          class="rounded-md border p-3"
          :class="
            opponentTotal > myTotal
              ? 'border-emerald-500/50 bg-emerald-500/10'
              : opponentTotal < myTotal
                ? 'border-wh-accent/50 bg-wh-accent/10'
                : 'border-wh-border bg-wh-surface-alt'
          "
        >
          <p class="truncate text-xs text-wh-mute">{{ opponentLabel }}</p>
          <p class="text-xl font-semibold text-wh-ink">{{ opponentTotal }}</p>
          <p class="text-xs text-wh-mute">{{ opponentPrimaryTotal }} primary + {{ opponentSecondaryTotal }} secondary</p>
        </div>
      </div>
    </section>

    <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
      <div class="flex items-center justify-between gap-2">
        <h2 class="mb-1 text-lg font-medium text-wh-ink">Disposition</h2>
        <button
          v-if="myMissionName && opponentMissionName"
          type="button"
          class="mb-1 shrink-0 rounded-md border border-wh-border px-2 py-1 text-xs text-wh-mute hover:border-wh-gold hover:text-wh-ink"
          :title="dispositionsLocked ? 'Unlock to change dispositions' : 'Lock to prevent accidental changes'"
          @click="dispositionsLocked = !dispositionsLocked"
        >
          {{ dispositionsLocked ? '🔒 Locked' : '🔓 Lock' }}
        </button>
      </div>
        <p class="mb-4 text-xs text-wh-mute">
          From GDM 2026 (a fan-made 11th edition reference) — flag it if anything looks off.
        </p>
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <label class="mb-1 block text-sm text-wh-mute">Your disposition</label>
            <select
              v-model="myDisposition"
              :disabled="dispositionsLocked"
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent disabled:opacity-50"
            >
              <option value="" disabled>Select...</option>
              <option v-for="d in DISPOSITIONS" :key="d" :value="d">{{ d }}</option>
            </select>
          </div>
          <div>
            <label class="mb-1 block text-sm text-wh-mute">Opponent's disposition</label>
            <select
              v-model="opponentDisposition"
              :disabled="dispositionsLocked"
              class="w-full rounded-md border border-wh-border bg-wh-surface-alt px-3 py-2 text-wh-ink outline-none focus:border-wh-accent disabled:opacity-50"
            >
              <option value="" disabled>Select...</option>
              <option v-for="d in DISPOSITIONS" :key="d" :value="d">{{ d }}</option>
            </select>
          </div>
        </div>
        <div v-if="myMissionName && opponentMissionName" class="mt-4 grid gap-3 sm:grid-cols-2">
          <PrimaryMissionScoring
            label="Your primary mission"
            :name="myMissionName"
            :description="PRIMARY_MISSION_DESCRIPTIONS[myMissionName] ?? ''"
            :options="myPrimaryOptions"
            :max-points-per-round="MAX_POINTS_PER_ROUND"
          />
          <PrimaryMissionScoring
            :label="`${opponentLabel}'s primary mission`"
            :name="opponentMissionName"
            :description="PRIMARY_MISSION_DESCRIPTIONS[opponentMissionName] ?? ''"
            :options="opponentPrimaryOptions"
            :max-points-per-round="MAX_POINTS_PER_ROUND"
          />
        </div>
      </section>

      <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="mb-1 text-lg font-medium text-wh-ink">Secondaries (optional)</h2>
        <p class="mb-4 text-xs text-wh-mute">
          Tick off which rounds you completed each secondary and it's summed up automatically. Discard a secondary
          to grey it out and zero its points. Max {{ MAX_POINTS_PER_ROUND }} total secondary points per round.
        </p>
        <div class="grid gap-4 sm:grid-cols-2">
          <SecondaryTracker
            label="Your secondaries"
            :entries="mySecondaries"
            :available="availableSecondariesFor(mySecondaries)"
            :max-points-per-round="MAX_POINTS_PER_ROUND"
            :descriptions="SECONDARY_DESCRIPTIONS"
            @add="name => addSecondary(mySecondaries, name)"
            @remove="i => removeSecondary(mySecondaries, i)"
          />
          <SecondaryTracker
            :label="`${opponentLabel}'s secondaries`"
            :entries="opponentSecondaries"
            :available="availableSecondariesFor(opponentSecondaries)"
            :max-points-per-round="MAX_POINTS_PER_ROUND"
            :descriptions="SECONDARY_DESCRIPTIONS"
            @add="name => addSecondary(opponentSecondaries, name)"
            @remove="i => removeSecondary(opponentSecondaries, i)"
          />
        </div>
      </section>

      <section class="rounded-lg border border-wh-border bg-wh-surface p-6">
        <h2 class="mb-1 text-lg font-medium text-wh-ink">Report to league</h2>
        <label v-if="hasReportableMatch" class="mt-2 flex items-center gap-2 text-sm text-wh-ink">
          <input v-model="applyToMatch" type="checkbox" class="accent-wh-accent">
          Apply the final score to my ongoing match against {{ opponentLabel }}
        </label>
        <p v-else class="mt-2 text-sm text-wh-mute">
          No ongoing league match to report to right now — this tracking session isn't saved anywhere.
        </p>

        <p v-if="reportError" class="mt-3 text-sm text-wh-accent">{{ reportError }}</p>
        <button
          v-if="applyToMatch && hasReportableMatch"
          type="button"
          :disabled="reportSubmitting"
          class="mt-4 rounded-md bg-wh-accent px-4 py-2 text-sm font-medium text-wh-ink hover:bg-wh-accent-hover disabled:opacity-50"
          @click="submitReport"
        >
          {{ reportSubmitting ? 'Reporting...' : 'Report result' }}
        </button>
        <p v-else-if="hasReportableMatch" class="mt-4 text-sm text-wh-mute">
          Tick the checkbox above if you want to apply this result to your ongoing match.
        </p>
        <p v-else class="mt-4 text-sm text-wh-mute">Standalone tracking — not saved anywhere.</p>
      </section>
    </template>
  </div>
</template>
