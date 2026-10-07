import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://www.vai.vet',
  // The founder-centric /about/leadership/ page was retired with the institutional About rebuild; keep the URL alive as a redirect.
  redirects: { '/about/leadership': '/about/' },
  integrations: [
    mdx(),
    sitemap({
      // /pulse/{view}/{discipline}/{period}/ are thin filter variations of the two indexable Pulse pages (/pulse/, /pulse/guidelines/).
      filter: (page) => !page.includes('/founding-faculty') && !page.includes('/about/leadership') && !/\/pulse\/(latest|guidelines)\/[^/]+/.test(page),
    }),
  ],
  vite: {
    plugins: [tailwindcss()],
  },
});
