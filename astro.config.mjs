import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://www.vai.vet',
  integrations: [
    mdx(),
    sitemap({
      // /pulse/{view}/{discipline}/{period}/ are thin filter variations of the two indexable Pulse pages (/pulse/, /pulse/guidelines/).
      filter: (page) => !page.includes('/founding-faculty') && !/\/pulse\/(latest|guidelines)\/[^/]+/.test(page),
    }),
  ],
  vite: {
    plugins: [tailwindcss()],
  },
});
