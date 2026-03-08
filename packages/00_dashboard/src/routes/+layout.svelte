<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { authToken, user, logout, initializeAuth } from '$lib/auth';
  import { Button } from '@oute/design-system';

  onMount(async () => {
    // Initialize auth from localStorage
    initializeAuth();

    // Redirect to login if not authenticated and not already on login page
    if (!$authToken && $page.url.pathname !== '/login') {
      goto('/login');
    }
  });

  async function handleLogout() {
    logout();
    goto('/login');
  }
</script>

<div class="min-h-screen bg-neutral-50">
  {#if $authToken}
    <!-- Navigation Bar -->
    <nav class="bg-white shadow-sm border-b border-neutral-200">
      <div class="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
        <div class="flex items-center gap-8">
          <h1 class="text-2xl font-bold text-primary-600">OUTE</h1>
          <div class="hidden md:flex gap-6">
            <a href="/" class="text-neutral-700 hover:text-primary-600 font-medium">Dashboard</a>
            <a href="/profile" class="text-neutral-700 hover:text-primary-600 font-medium"
              >Profile</a
            >
          </div>
        </div>

        <div class="flex items-center gap-4">
          {#if $user}
            <span class="text-sm text-neutral-600">{$user.email}</span>
          {/if}
          <Button variant="secondary" size="sm" on:click={handleLogout}>Sign Out</Button>
        </div>
      </div>
    </nav>
  {/if}

  <!-- Main Content -->
  <main>
    <slot />
  </main>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: 'Inter', system-ui, sans-serif;
    background-color: #f9fafb;
  }

  :global(html, body) {
    height: 100%;
  }
</style>
