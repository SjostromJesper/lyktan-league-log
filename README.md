# Lyktan League Log

En liten webbapp för att köra Warhammer 40,000-eskalationsligor på Butiklyktan: spelare loggar in, anmäler sig redo med sin armélista, blir ihoplottade av admin, rapporterar matchresultat och ser tabellen.

## Stack

- Nuxt 4 (SPA-läge) + Vue 3 + TypeScript
- Tailwind CSS v4
- Supabase (Postgres, Auth, RLS)

## Utveckling

```bash
npm install
npm run dev
```

Kräver en `.env` med `SUPABASE_URL`, `SUPABASE_KEY` och `SUPABASE_SERVICE_ROLE_KEY`.

## Databas

Schemat hanteras via Supabase-migrationer i `supabase/migrations/`. Applicera med:

```bash
npx supabase db push
```
