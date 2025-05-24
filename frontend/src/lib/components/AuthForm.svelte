<script lang="ts">
  import { token } from '$lib/stores'
  import { login, signup } from '../api'

  let username = ''
  let password = ''
  let isRegisterMode = false
  let errorMessage = ''

  async function handleSubmit() {
    try {
      const newToken = await (isRegisterMode
        ? signup(username, password)
        : login(username, password))
      console.log(newToken)
      token.set(newToken)
      localStorage.setItem('token', newToken)
      errorMessage = ''
    } catch {
      errorMessage = isRegisterMode ? 'Ошибка регистрации' : 'Ошибка входа'
    }
  }

  function toggleMode() {
    isRegisterMode = !isRegisterMode
    errorMessage = ''
  }
</script>

<div class="mx-auto max-w-md p-4">
  <h1 class="mb-4 text-2xl">{isRegisterMode ? 'Регистрация' : 'Вход'}</h1>
  <input
    type="text"
    bind:value={username}
    placeholder="Имя пользователя"
    class="mb-2 w-full rounded border p-2"
  />
  <input
    type="password"
    bind:value={password}
    placeholder="Пароль"
    class="mb-2 w-full rounded border p-2"
  />
  <button
    on:click={handleSubmit}
    class="w-full rounded bg-blue-500 p-2 text-white hover:bg-blue-600"
  >
    {isRegisterMode ? 'Зарегистрироваться' : 'Войти'}
  </button>
  <p class="mt-2">
    {isRegisterMode ? 'Уже есть аккаунт?' : 'Нет аккаунта?'}
    <button
      on:click={toggleMode}
      class="text-blue-500 hover:underline"
    >
      {isRegisterMode ? 'Войти' : 'Зарегистрироваться'}
    </button>
  </p>
  {#if errorMessage}
    <p class="mt-2 text-red-500">{errorMessage}</p>
  {/if}
</div>
