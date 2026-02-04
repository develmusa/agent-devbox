// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	integrations: [
		starlight({
			title: 'Agent Devbox',
			description: 'Security-hardened DevContainer for AI coding agents',
			logo: {
				src: './src/assets/houston.webp',
			},
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/develmusa/agent-devbox' },
			],
			sidebar: [
				{
					label: 'Documentation',
					items: [
						{ label: 'Getting Started', slug: 'getting-started' },
						{ label: 'Customizing', slug: 'customizing' },
						{ label: 'Security', slug: 'security' },
					],
				},
			],
			customCss: [
				'./src/styles/custom.css',
			],
		}),
	],
});
