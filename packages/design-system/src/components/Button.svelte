<script lang="ts">
  import type { HTMLAttributes } from 'svelte/elements';

  interface $$Props extends HTMLAttributes<HTMLButtonElement> {
    variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
    size?: 'sm' | 'md' | 'lg';
    disabled?: boolean;
  }

  export let variant: 'primary' | 'secondary' | 'danger' | 'ghost' = 'primary';
  export let size: 'sm' | 'md' | 'lg' = 'md';
  export let disabled = false;

  const variantClasses = {
    primary:
      'bg-primary-600 text-white hover:bg-primary-700 active:bg-primary-800',
    secondary:
      'bg-secondary-600 text-white hover:bg-secondary-700 active:bg-secondary-800',
    danger: 'bg-error text-white hover:opacity-90 active:opacity-75',
    ghost:
      'bg-transparent text-neutral-700 hover:bg-neutral-100 active:bg-neutral-200 border border-neutral-300',
  };

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm font-medium',
    md: 'px-4 py-2 text-base font-medium',
    lg: 'px-6 py-3 text-lg font-semibold',
  };
</script>

<button
  class={`
    inline-flex items-center justify-center
    font-medium rounded-lg
    transition-all duration-200
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500
    disabled:opacity-50 disabled:cursor-not-allowed
    ${variantClasses[variant]}
    ${sizeClasses[size]}
  `}
  {disabled}
  on:click
  {...$$restProps}
>
  <slot />
</button>
