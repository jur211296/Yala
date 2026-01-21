/** @type {import('tailwindcss').Config} */
export default {
    content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
    theme: {
        extend: {
            fontFamily: {
                sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
            },
            colors: {
                neutral: {
                    950: '#0a0a0b',
                    900: '#111113',
                    800: '#1a1a1d',
                    700: '#27272a',
                    600: '#3f3f46',
                    500: '#71717a',
                    400: '#a1a1aa',
                    300: '#d4d4d8',
                    200: '#e4e4e7',
                    100: '#f4f4f5',
                },
                accent: {
                    DEFAULT: '#6366f1',
                    light: '#818cf8',
                },
            },
            letterSpacing: {
                tight: '-0.02em',
                tighter: '-0.03em',
            },
        },
    },
    plugins: [],
}
