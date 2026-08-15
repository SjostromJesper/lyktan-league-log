export interface PrimaryMissionOption {
  label: string
  points: number
  timing: string
  rounds: number[]
  roundsCompleted: boolean[]
  // Tiered "control N objectives" options carry a group id + their N, so a linked
  // bonus checkbox (below) can scale itself off whichever tier is actually ticked.
  tierGroup?: string
  tierCount?: number
  // When set, this option is worth `points` flat (e.g. the objective's own base rate)
  // plus `scaleRate` per ticked tierCount(s) in the same tierGroup — not `points` alone,
  // since a "scales" bonus is often on top of a flat contribution, not a pure multiplier.
  scalesWithTierGroup?: string
  scaleRate?: number
}

export function primaryOptionPoints(option: PrimaryMissionOption, options: PrimaryMissionOption[], round: number) {
  if (!option.scalesWithTierGroup) return option.points
  const tierCount = options
    .filter(o => o.tierGroup === option.scalesWithTierGroup && o.roundsCompleted[round - 1])
    .reduce((sum, o) => sum + (o.tierCount ?? 0), 0)
  return option.points + (option.scaleRate ?? 0) * tierCount
}

export function primaryRoundPoints(options: PrimaryMissionOption[], round: number) {
  return options.reduce(
    (sum, o) => sum + (o.roundsCompleted[round - 1] ? primaryOptionPoints(o, options, round) : 0),
    0
  )
}

export function primaryMissionTotal(options: PrimaryMissionOption[], maxPointsPerRound: number) {
  let total = 0
  for (let round = 1; round <= 5; round++) {
    total += Math.min(maxPointsPerRound, primaryRoundPoints(options, round))
  }
  return total
}

// Tiered "control N objectives" options are mutually exclusive (you control however many
// you control) — clicking one clears any other ticked option in the same tierGroup for that
// round, and clicking the already-ticked one clears it (so "none" stays a valid state).
export function toggleTierOption(options: PrimaryMissionOption[], option: PrimaryMissionOption, round: number) {
  if (!option.tierGroup) return
  const idx = round - 1
  const wasSelected = option.roundsCompleted[idx]
  for (const o of options) {
    if (o.tierGroup === option.tierGroup) o.roundsCompleted[idx] = false
  }
  option.roundsCompleted[idx] = !wasSelected
}
