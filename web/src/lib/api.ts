import axios from 'axios';
export const api = axios.create({ baseURL: import.meta.env.VITE_API_URL ?? '' });
api.interceptors.request.use(config => { const token = sessionStorage.getItem('accessToken'); if (token) config.headers.Authorization = `Bearer ${token}`; if (config.method && ['post','put','patch'].includes(config.method)) config.headers['Idempotency-Key'] = crypto.randomUUID(); return config; });
api.interceptors.response.use(response => response, error => Promise.reject(error));
