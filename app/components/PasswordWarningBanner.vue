<script setup lang="ts">
const { profile } = useProfile()
</script>

<template>
  <div
    v-if="profile?.password_change_required"
    class="flex flex-wrap items-center justify-center gap-2 bg-wh-accent px-4 py-2 text-center text-sm font-medium text-white"
  >
    <span>Du loggade in med ett tillfälligt lösenord. Byt det snarast.</span>
    <NuxtLink to="/settings" class="underline hover:no-underline">Byt lösenord</NuxtLink>
  </div>
</template>
