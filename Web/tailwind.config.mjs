/** @type {import('tailwindcss').Config} */
export default {
    content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
    theme: {
        extend: {
            colors: {
                'neto-bg': '#05050A',
                'neto-card': 'rgba(255, 255, 255, 0.03)',
                'neto-border': 'rgba(255, 255, 255, 0.08)',
                'neto-indigo': '#6C5CE7',
                'neto-pink': '#FD79A8',
                'neto-teal': '#00CEC9',
                'neto-cyan': '#0984E3',
            }
        },
    },
    plugins: [],
}
