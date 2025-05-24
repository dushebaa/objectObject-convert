<script>
  import AuthForm from '$lib/components/AuthForm.svelte'
  import Converter from '$lib/components/Converter.svelte'
  import { token } from '$lib/stores'

  $: isLoggedIn = $token !== null
</script>

<main>
  {#if isLoggedIn}
    <Converter />
  {:else}
    <AuthForm />
  {/if}
</main>
