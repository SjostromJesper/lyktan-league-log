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
  // When set, this option isn't worth a flat `points` — instead `points` is a
  // per-unit rate multiplied by the ticked tierCount(s) in the same tierGroup.
  scalesWithTierGroup?: string
}

export function primaryOptionPoints(option: PrimaryMissionOption, options: PrimaryMissionOption[], round: number) {
  if (!option.scalesWithTierGroup) return option.points
  const tierCount = options
    .filter(o => o.tierGroup === option.scalesWithTierGroup && o.roundsCompleted[round - 1])
    .reduce((sum, o) => sum + (o.tierCount ?? 0), 0)
  return option.points * tierCount
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
