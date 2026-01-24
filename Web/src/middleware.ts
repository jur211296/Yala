import { defineMiddleware } from 'astro:middleware';

const supportedLanguages = ['es', 'en', 'de', 'fr', 'it', 'pt'] as const;
type SupportedLanguage = typeof supportedLanguages[number];

function getPreferredLanguage(acceptLanguage: string | null): SupportedLanguage {
  if (!acceptLanguage) return 'es';

  // Parse Accept-Language header (e.g., "en-US,en;q=0.9,es;q=0.8")
  const languages = acceptLanguage
    .split(',')
    .map(lang => {
      const [code, q] = lang.trim().split(';q=');
      return {
        code: code.split('-')[0].toLowerCase(), // Get base language code
        quality: q ? parseFloat(q) : 1.0,
      };
    })
    .sort((a, b) => b.quality - a.quality);

  // Find the first supported language
  for (const { code } of languages) {
    if (supportedLanguages.includes(code as SupportedLanguage)) {
      return code as SupportedLanguage;
    }
  }

  return 'es'; // Default to Spanish
}

export const onRequest = defineMiddleware(async ({ request, redirect, cookies }, next) => {
  const url = new URL(request.url);

  // Only redirect on the root path
  if (url.pathname === '/') {
    // Check if user has a language preference stored
    const savedLang = cookies.get('lang')?.value;

    if (savedLang && supportedLanguages.includes(savedLang as SupportedLanguage)) {
      // User already selected a language, don't redirect
      return next();
    }

    // Get preferred language from browser
    const acceptLanguage = request.headers.get('accept-language');
    const preferredLang = getPreferredLanguage(acceptLanguage);

    // If preferred language is not Spanish (default), redirect
    if (preferredLang !== 'es') {
      return redirect(`/${preferredLang}/`, 302);
    }
  }

  return next();
});
