import tailwindcss from '@tailwindcss/vite'

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  ssr: false,
  app: {
    head: {
      title: 'Lyktan League Log',
      meta: [
        { name: 'theme-color', content: '#0d0d0f' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' },
        { name: 'apple-mobile-web-app-title', content: 'Lyktan' }
      ],
      link: [{ rel: 'apple-touch-icon', href: '/apple-touch-icon.png' }]
    }
  },
  css: ['~/assets/css/main.css'],
  modules: ['@nuxtjs/supabase', '@vite-pwa/nuxt'],
  runtimeConfig: {
    supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY
  },
  supabase: {
    redirectOptions: {
      login: '/login',
      callback: '/login',
      exclude: ['/login']
    }
  },
  pwa: {
    registerType: 'autoUpdate',
    manifest: {
      name: 'Lyktan League Log',
      short_name: 'Lyktan',
      description: 'Håll koll på din Warhammer 40k-eskalationsliga.',
      theme_color: '#0d0d0f',
      background_color: '#0d0d0f',
      display: 'standalone',
      start_url: '/',
      icons: [
        { src: '/icons/icon-192x192.png', sizes: '192x192', type: 'image/png' },
        { src: '/icons/icon-512x512.png', sizes: '512x512', type: 'image/png' },
        { src: '/icons/icon-maskable-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
      ]
    },
    workbox: {
      navigateFallback: '/',
      globPatterns: ['**/*.{js,css,html,png,svg,ico}']
    },
    client: {
      installPrompt: true
    }
  },
  vite: {
    plugins: [tailwindcss()]
  }
})
