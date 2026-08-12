import { createClient } from '@supabase/supabase-js'

export default defineEventHandler(async event => {
  const config = useRuntimeConfig()
  const authHeader = getHeader(event, 'authorization')
  const token = authHeader?.replace('Bearer ', '')
  if (!token) {
    throw createError({ statusCode: 401, statusMessage: 'Ingen session.' })
  }

  const admin = createClient(config.public.supabase.url, config.supabaseServiceRoleKey)

  const { data: callerData, error: callerError } = await admin.auth.getUser(token)
  if (callerError || !callerData.user) {
    throw createError({ statusCode: 401, statusMessage: 'Ogiltig session.' })
  }

  const { data: callerProfile } = await admin
    .from('profiles')
    .select('role')
    .eq('id', callerData.user.id)
    .single()

  if (callerProfile?.role !== 'admin') {
    throw createError({ statusCode: 403, statusMessage: 'Endast admin kan skapa konton.' })
  }

  const body = await readBody<{ email: string; password: string; name: string; army?: string }>(event)
  if (!body.email?.trim() || !body.password || !body.name?.trim()) {
    throw createError({ statusCode: 400, statusMessage: 'Mail, lösenord och namn krävs.' })
  }
  if (body.password.length < 6) {
    throw createError({ statusCode: 400, statusMessage: 'Lösenordet måste vara minst 6 tecken.' })
  }

  const { data, error } = await admin.auth.admin.createUser({
    email: body.email.trim().toLowerCase(),
    password: body.password,
    email_confirm: true,
    user_metadata: { name: body.name.trim(), army: body.army?.trim() ?? '', role: 'player' }
  })

  if (error) {
    throw createError({ statusCode: 400, statusMessage: error.message })
  }

  return { id: data.user?.id }
})
