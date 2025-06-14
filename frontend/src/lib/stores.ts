import { writable } from 'svelte/store'

export const token = writable<string | null>(localStorage.getItem('token') || null)
