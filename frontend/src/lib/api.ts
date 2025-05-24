import type { paths } from '$lib/api-types'
import createClient from 'openapi-fetch'

const client = createClient<paths>({ baseUrl: 'http://127.0.0.1:8000' })

export async function login(username: string, password: string) {
  const { data, error } = await client.POST('/auth/login', {
    body: { username, password },
  })
  if (error) throw new Error('Login failed')
  return (data as { token: string }).token
}

export async function signup(username: string, password: string) {
  const { data, error } = await client.POST('/auth/signup', {
    body: { username, password },
  })
  if (error) throw new Error('Signup failed')
  return (data as { token: string }).token
}

export async function processFile(file: File, outputFormat: string, token: string) {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('output_format', outputFormat)

  const { data, error } = await client.POST('/files/process', {
    // @ts-ignore
    body: formData,
    headers: { Authorization: token },
  })
  if (error) throw error // Ошибка будет обработана в компоненте
  return (data as { file_id: string }).file_id
}

export async function getFileStatus(fileId: string, token: string) {
  const { data, error } = await client.GET('/files/{file_id}/status/', {
    params: { header: { Authorization: token }, path: { file_id: fileId } },
  })
  if (error) throw error
  return data as { status: 'pending' | 'processing' | 'finished' | 'error'; message?: string }
}

export async function downloadFile(fileId: string, token: string, filename: string, outputFormat: string) {
  const response = await fetch(`http://127.0.0.1:8000/files/${fileId}/download/`, {
    headers: { Authorization: token },
  })
  if (!response.ok) {
    if (response.status === 401) throw new Error('Session expired')
    throw new Error('Download failed')
  }
  const blob = await response.blob()
  const url = window.URL.createObjectURL(blob)
  const a = document.createElement('a')
  const filenameClean = filename.split('.').slice(0,-1).join('.')
  a.download = `${filenameClean}.${outputFormat.toLowerCase()}`
  a.href = url
  document.body.appendChild(a)
  a.click()
  a.remove()
  window.URL.revokeObjectURL(url)
}
