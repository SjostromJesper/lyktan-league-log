<template>
  <div class="min-h-screen bg-wh-bg">
    <VitePwaManifest />
    <NuxtRouteAnnouncer />
    <PasswordWarningBanner />
    <AppHeader />
    <main class="mx-auto max-w-5xl px-4 py-10 sm:px-6">
      <NuxtPage />
    </main>
  </div>
</template>
