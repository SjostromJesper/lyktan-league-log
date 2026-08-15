export type UserRole = 'player' | 'admin'

export interface Profile {
  id: string
  email: string
  name: string
  army: string
  discord: string
  role: UserRole
  password_change_required: boolean
  created_at: string
}

export interface League {
  id: string
  name: string
  description: string
  is_active: boolean
  phase_count: number
  matches_per_phase: number
  current_phase: number
  is_archived: boolean
  created_at: string
}

export interface LeagueMember {
  league_id: string
  user_id: string
  joined_at: string
}

export interface PaintedUnits {
  league_id: string
  user_id: string
  unit1: boolean
  unit2: boolean
  unit3: boolean
  unit4: boolean
  unit5: boolean
}

export interface Signup {
  id: string
  league_id: string
  user_id: string
  army_list: string
  phase_number: number | null
  created_at: string
}

export type MatchStatus = 'pending' | 'reported' | 'confirmed' | 'disputed'

export interface Match {
  id: string
  league_id: string
  player1_id: string
  player1_list: string
  player2_id: string
  player2_list: string
  status: MatchStatus
  reporter_id: string | null
  player1_vp: number | null
  player2_vp: number | null
  player1_wtc: number | null
  player2_wtc: number | null
  player1_league_points: number | null
  player2_league_points: number | null
  phase_number: number | null
  created_at: string
  reported_at: string | null
  confirmed_at: string | null
}

export interface TrackerMatch {
  id: string
  user_id: string
  name: string | null
  my_disposition: string | null
  opponent_disposition: string | null
  my_primary_options: unknown[]
  opponent_primary_options: unknown[]
  my_secondaries: unknown[]
  opponent_secondaries: unknown[]
  apply_to_match: boolean
  saved_to_history: boolean
  created_at: string
  updated_at: string
}

export interface Database {
  public: {
    Tables: {
      profiles: { Row: Profile; Insert: Partial<Profile>; Update: Partial<Profile> }
      leagues: { Row: League; Insert: Partial<League>; Update: Partial<League> }
      league_members: { Row: LeagueMember; Insert: Partial<LeagueMember>; Update: Partial<LeagueMember> }
      signups: { Row: Signup; Insert: Partial<Signup>; Update: Partial<Signup> }
      matches: { Row: Match; Insert: Partial<Match>; Update: Partial<Match> }
      painted_units: { Row: PaintedUnits; Insert: Partial<PaintedUnits>; Update: Partial<PaintedUnits> }
      tracker_matches: { Row: TrackerMatch; Insert: Partial<TrackerMatch>; Update: Partial<TrackerMatch> }
    }
  }
}
