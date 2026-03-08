<script lang="ts">
  import { goto } from '$app/navigation';
  import { login } from '$lib/auth';

  let email = '';
  let password = '';
  let error = '';
  let loading = false;

  async function handleLogin() {
    if (!email || !password) {
      error = 'Please fill in all fields';
      return;
    }

    loading = true;
    error = '';

    try {
      await login(email, password);
      // Redirect to dashboard
      goto('/');
    } catch (err) {
      error = err instanceof Error ? err.message : 'Login failed';
    } finally {
      loading = false;
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      handleLogin();
    }
  }
</script>

<div class="min-h-screen bg-gradient-to-br from-primary-50 to-primary-100 flex items-center justify-center p-4">
  <div class="bg-white rounded-lg shadow-lg p-8 w-full max-w-md">
    <div class="text-center mb-8">
      <h1 class="text-3xl font-bold text-primary-600">OUTE</h1>
      <p class="text-neutral-600 mt-2">Project Management Platform</p>
    </div>

    <form on:submit|preventDefault={handleLogin} class="space-y-4">
      {#if error}
        <div class="bg-error/10 text-error p-3 rounded-lg text-sm">
          {error}
        </div>
      {/if}

      <div>
        <label for="email" class="block text-sm font-medium text-neutral-700 mb-2">
          Email
        </label>
        <input
          id="email"
          type="email"
          bind:value={email}
          on:keydown={handleKeydown}
          placeholder="you@example.com"
          class="w-full px-4 py-2 border border-neutral-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition"
          disabled={loading}
        />
      </div>

      <div>
        <label for="password" class="block text-sm font-medium text-neutral-700 mb-2">
          Password
        </label>
        <input
          id="password"
          type="password"
          bind:value={password}
          on:keydown={handleKeydown}
          placeholder="••••••••"
          class="w-full px-4 py-2 border border-neutral-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition"
          disabled={loading}
        />
      </div>

      <button
        type="submit"
        disabled={loading}
        class="w-full bg-primary-600 text-white py-2 rounded-lg font-medium hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
      >
        {#if loading}
          Logging in...
        {:else}
          Sign In
        {/if}
      </button>
    </form>

    <p class="text-center text-neutral-600 text-sm mt-6">
      Demo credentials:
      <br />
      <code class="text-xs bg-neutral-100 px-2 py-1 rounded">demo@example.com</code>
    </p>
  </div>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: 'Inter', sans-serif;
  }
</style>
