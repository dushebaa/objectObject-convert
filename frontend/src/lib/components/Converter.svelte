<script lang="ts">
  import { token } from '$lib/stores'
  import { downloadFile, getFileStatus, processFile } from '../api'

  let file = $state<File | null>(null)
  let outputFormat = $state<string>('')
  let status = $state<'idle' | 'uploading' | 'processing' | 'completed' | 'error'>('idle')
  let errorMessage = $state<string | null>(null)
  let fileId = $state<string | null>(null)

  const formats = ['MP4', 'AVI', 'MKV']

  function handleFileChange(event: Event) {
    const input = event.target as HTMLInputElement
    file = input.files?.[0] || null
  }

  async function uploadFile() {
    console.log(file, outputFormat, $token)
    if (!file || !outputFormat || !$token) return
    status = 'uploading'
    try {
      fileId = await processFile(file, outputFormat, $token)
      status = 'processing'
      pollStatus()
    } catch {
      status = 'error'
      errorMessage = 'Ошибка загрузки файла'
    }
  }

  function pollStatus() {
    const interval = setInterval(async () => {
      try {
        if (!fileId || !$token) throw new Error('File ID is not set')
        const data = await getFileStatus(fileId, $token)
        if (data.status === 'finished') {
          status = 'completed'
          clearInterval(interval)
        } else if (data.status === 'error') {
          status = 'error'
          errorMessage = data.message || 'Ошибка обработки'
          clearInterval(interval)
        }
      } catch {
        status = 'error'
        errorMessage = 'Ошибка проверки статуса'
        clearInterval(interval)
      }
    }, 2000)
  }

  async function handleDownload() {
    if (!fileId || !$token) return
    try {
      await downloadFile(fileId, $token)
    } catch {
      status = 'error'
      errorMessage = 'Ошибка скачивания'
    }
  }

  function logout() {
    token.set(null)
    localStorage.removeItem('token')
  }
</script>

<div class="relative mx-auto max-w-md p-4">
  <h1 class="mb-4 text-2xl">Конвертер файлов</h1>
  <button
    onclick={logout}
    class="absolute top-4 right-4 rounded bg-red-500 p-2 text-white"
  >
    Выйти
  </button>
  <input
    type="file"
    accept=".mp4,.avi,.mkv"
    onchange={handleFileChange}
    class="mb-2"
  />
  <select
    bind:value={outputFormat}
    class="mb-2 w-full rounded border p-2"
  >
    <option value="">Выберите формат</option>
    {#each formats as format (format)}
      <option value={format}>{format}</option>
    {/each}
  </select>
  <button
    onclick={uploadFile}
    disabled={!file || !outputFormat || status === 'uploading' || status === 'processing'}
    class="w-full rounded bg-blue-500 p-2 text-white hover:bg-blue-600"
  >
    Конвертировать
  </button>
  {#if status === 'uploading'}
    <p class="mt-2">Загрузка...</p>
  {:else if status === 'processing'}
    <p class="mt-2">Обработка...</p>
  {:else if status === 'completed'}
    <p class="mt-2">Готово!</p>
    <button
      onclick={handleDownload}
      class="mt-2 rounded bg-green-500 p-2 text-white hover:bg-green-600"
    >
      Скачать
    </button>
  {:else if status === 'error'}
    <p class="mt-2 text-red-500">Ошибка: {errorMessage}</p>
  {/if}
</div>
