/** @type {import('tailwindcss').Config} */
export default {
    content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
    theme: {
        extend: {
            fontFamily: {
                sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
            },
            colors: {
                // Brand Primary Colors
                yala: {
                    indigo: '#6366F1',      // Electric Indigo - primary brand
                    cyan: '#00F3FF',         // Neon Cyan - digital money/optimism
                    pink: '#FF0080',         // Hot Pink - urgency/accents
                    slate: '#0F172A',        // Deep Slate - dark mode bg
                    teal: '#00C2CB',         // Priority Nature - priority expenses
                },
                // Expense Nature Colors
                nature: {
                    essential: '#F59E0B',    // Amber - basic needs
                    priority: '#8B5CF6',     // Violet - attention without urgency
                    optional: '#FB7185',     // Rose - discretionary
                },
                // Neutral scale
                neutral: {
                    950: '#0F172A',          // Deep Slate
                    900: '#1E293B',
                    800: '#334155',
                    700: '#475569',
                    600: '#64748B',
                    500: '#94A3B8',
                    400: '#CBD5E1',
                    300: '#E2E8F0',
                    200: '#F1F5F9',
                    100: '#F8FAFC',
                    50: '#FAFAFC',           // Light mode bg
                },
                // Semantic aliases
                brand: {
                    primary: '#6366F1',      // Electric Indigo
                    secondary: '#FF0080',    // Hot Pink
                    tertiary: '#00C2CB',     // Teal
                },
                accent: {
                    DEFAULT: '#6366F1',
                    light: '#818CF8',
                    cyan: '#00F3FF',
                    pink: '#FF0080',
                },
            },
            letterSpacing: {
                tight: '-0.02em',
                tighter: '-0.03em',
            },
            backgroundImage: {
                'gradient-yala': 'linear-gradient(135deg, #6366F1 0%, #8B5CF6 50%, #FF0080 100%)',
                'gradient-hero': 'linear-gradient(135deg, #6366F1 0%, #00F3FF 100%)',
                'gradient-cta': 'linear-gradient(135deg, #6366F1 0%, #FF0080 100%)',
            },
            boxShadow: {
                'yala': '0 0 30px rgba(99, 102, 241, 0.3)',
                'yala-cyan': '0 0 30px rgba(0, 243, 255, 0.3)',
                'yala-pink': '0 0 30px rgba(255, 0, 128, 0.3)',
            },
        },
    },
    plugins: [],
}
