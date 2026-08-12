import { serverSupabaseClient } from '#supabase/server'
import type { EmailOtpType } from '@supabase/supabase-js'

export default defineEventHandler(async event => {
  const query = getQuery(event)
  const tokenHash = query.token_hash as string | undefined
  const type = query.type as EmailOtpType | undefined
  const next = (query.next as string) || '/confirm'

  if (tokenHash && type) {
    const client = await serverSupabaseClient(event)
    const { error } = await client.auth.verifyOtp({ type, token_hash: tokenHash })
    if (!error) {
      return sendRedirect(event, next)
    }
  }

  return sendRedirect(event, '/login')
})
