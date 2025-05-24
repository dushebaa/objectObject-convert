<script lang="ts">
  import { token } from '$lib/stores'
  import { downloadFile, getFileStatus, processFile } from '../api'

  let file = $state<File | null>(null)
  let outputFormat = $state<string>('')
  let status = $state<'idle' | 'uploading' | 'processing' | 'finished' | 'error'>('idle')
  let errorMessage = $state<string | null>(null)
  let fileId = $state<string | null>(null)

  const videoFormats = ['mp4', 'avi', 'mkv', 'mov', 'flv', 'av1', 'webm', 'hevc']
  const imageFormats = ['png', 'jpeg', 'webp', 'jpg', 'gif', 'tiff', 'heif']
  const audioForamts = ['wav', 'mp3', 'flac', 'ogg', 'aac', 'aiff']
  const acceptedFormats = [...videoFormats, ...imageFormats, ...audioForamts].map(format => `.${format}`).join(',')

  function handleFileChange(event: Event) {
    const input = event.target as HTMLInputElement
    file = input.files?.[0] || null
  }

  async function uploadFile() {
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
          status = 'finished'
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
      await downloadFile(fileId, $token, file!.name, outputFormat)
    } catch {
      status = 'error'
      errorMessage = 'Ошибка скачивания'
    }
  }

  function logout() {
    token.set(null)
    localStorage.removeItem('token')
  }

  function getOutputOptions() {
    const fileExtension = file?.name.split('.').at(-1);
    if (!fileExtension) return [];
    for (const format of [videoFormats, imageFormats, audioForamts]) {
      if (format.includes(fileExtension)) {
        return format.filter(fm => fm !== fileExtension);
      }
    }
    return [];
  }
</script>

<div class="flex h-dvh w-full items-center">
  <div class="relative mx-auto max-w-md p-4">
    <div class="flex w-full justify-between gap-8">
      <h1 class="mb-4 text-2xl">Конвертер файлов</h1>
      <button
        onclick={logout}
        class="h-fit rounded bg-red-500 px-4 py-1 text-white"
      >
        Выйти
      </button>
    </div>
    <input
      type="file"
      accept={acceptedFormats}
      onchange={handleFileChange}
      class="mb-2 w-full rounded bg-stone-100 py-4 text-center outline"
    />
    {#if file}
      <select
        bind:value={outputFormat}
        class="mb-2 w-full rounded border p-2"
      >
        <option value="">Выберите формат</option>
        {#each getOutputOptions() as format (format)}
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
    {/if}
    {#if status === 'uploading'}
      <p class="mt-2">Загрузка...</p>
    {:else if status === 'processing'}
      <p class="mt-2">Обработка...</p>
    {:else if status === 'finished'}
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
</div>
