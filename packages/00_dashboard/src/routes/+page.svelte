<script lang="ts">
  import { user } from '$lib/auth';
</script>

<div class="max-w-7xl mx-auto px-4 py-8">
  <div class="bg-white rounded-lg shadow-lg p-8 text-center">
    <h2 class="text-4xl font-bold text-primary-600 mb-4">Hello World! 🚀</h2>
    <p class="text-lg text-neutral-700 mb-6">Welcome to OUTE Dashboard</p>

    {#if $user}
      <p class="text-md text-neutral-600">
        Logged in as <span class="font-semibold">{$user.email}</span>
      </p>
    {/if}

    <div class="mt-8 p-6 bg-primary-50 rounded-lg border border-primary-200">
      <h3 class="text-lg font-semibold text-primary-700 mb-2">✅ Setup Status</h3>
      <ul class="text-left space-y-2 text-neutral-700 inline-block">
        <li>✓ SvelteKit configured</li>
        <li>✓ Authentication working</li>
        <li>✓ Design System integrated</li>
        <li>✓ Navigation ready</li>
      </ul>
    </div>

    <div class="mt-8 text-neutral-500 text-sm">
      <p>Dashboard is ready for development</p>
      <p>Next: Implement projects listing</p>
    </div>
  </div>
</div>

<style>
  div {
    min-height: calc(100vh - 80px);
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>
