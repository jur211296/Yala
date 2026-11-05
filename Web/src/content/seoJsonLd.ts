// Nodos schema.org de las páginas de funciones y preguntas frecuentes. Se suman al @graph del Layout,
// que ya declara la organización, el sitio y la app (`#organization`, `#website`, `#app`).
import { features, faq, featureUrl, seoPaths, ui, type Feature, type Qa, type SeoLang } from './seo';

const site = 'https://yala-app.pe';
const homeUrl = (lang: SeoLang) => (lang === 'es' ? `${site}/` : `${site}/en/`);

export const faqPageNode = (url: string, lang: SeoLang, items: Qa[]) => ({
  '@type': 'FAQPage',
  '@id': `${url}#faq`,
  url,
  inLanguage: lang,
  mainEntity: items.map(({ q, a }) => ({
    '@type': 'Question',
    name: q,
    acceptedAnswer: { '@type': 'Answer', text: a },
  })),
});

const breadcrumb = (url: string, items: { name: string; url: string }[]) => ({
  '@type': 'BreadcrumbList',
  '@id': `${url}#breadcrumb`,
  itemListElement: items.map((it, i) => ({ '@type': 'ListItem', position: i + 1, name: it.name, item: it.url })),
});

export const alternatesFor = (paths: Record<SeoLang, string>) =>
  (['es', 'en'] as SeoLang[]).map((l) => ({ l, href: site + paths[l] }));

export function featureJsonLd(f: Feature, lang: SeoLang) {
  const url = site + featureUrl(f, lang);
  const t = f.text[lang];
  return [
    {
      '@type': 'WebPage',
      '@id': `${url}#webpage`,
      url,
      name: t.title,
      description: t.description,
      inLanguage: lang,
      isPartOf: { '@id': `${site}/#website` },
      about: { '@id': `${site}/#app` },
      breadcrumb: { '@id': `${url}#breadcrumb` },
    },
    breadcrumb(url, [
      { name: ui[lang].home, url: homeUrl(lang) },
      { name: ui[lang].features, url: site + seoPaths.features[lang] },
      { name: t.nav, url },
    ]),
    faqPageNode(url, lang, t.faq),
  ];
}

export function featuresIndexJsonLd(lang: SeoLang) {
  const url = site + seoPaths.features[lang];
  return [
    {
      '@type': 'CollectionPage',
      '@id': `${url}#webpage`,
      url,
      name: ui[lang].featuresTitle,
      description: ui[lang].featuresDescription,
      inLanguage: lang,
      isPartOf: { '@id': `${site}/#website` },
      about: { '@id': `${site}/#app` },
      mainEntity: {
        '@type': 'ItemList',
        itemListElement: features.map((f, i) => ({
          '@type': 'ListItem', position: i + 1, name: f.text[lang].nav, url: site + featureUrl(f, lang),
        })),
      },
    },
    breadcrumb(url, [
      { name: ui[lang].home, url: homeUrl(lang) },
      { name: ui[lang].features, url },
    ]),
  ];
}

export function faqJsonLd(lang: SeoLang) {
  const url = site + seoPaths.faq[lang];
  return [
    faqPageNode(url, lang, faq[lang]),
    breadcrumb(url, [
      { name: ui[lang].home, url: homeUrl(lang) },
      { name: ui[lang].faq, url },
    ]),
  ];
}
