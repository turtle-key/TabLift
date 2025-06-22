<script lang="ts">
	import { base } from '$app/paths';
	import '../app.css';
	import { onMount } from "svelte";
	let menuOpen = $state(false);
  function toggleMenu() {
    menuOpen = !menuOpen;
  }
  function closeMenu() {
    menuOpen = false;
  }
	type Theme = 'light' | 'dark';
  let theme: Theme = $state('light');;
  let darkMode = false;

  function applyTheme(newTheme: Theme) {
    theme = newTheme;
    if (theme === 'light') {
      document.documentElement.classList.remove('dark');
      localStorage.theme = 'light';
      darkMode = false;
    } else if (theme === 'dark') {
      document.documentElement.classList.add('dark');
      localStorage.theme = 'dark';
      darkMode = true;
    }
  }

  function cycleTheme() {
    if (theme === 'dark') applyTheme('light');
    else applyTheme('dark');
  }

  onMount(() => {
    if (typeof window !== 'undefined') {
      if (localStorage.theme === 'dark') applyTheme('dark');
      else if (localStorage.theme === 'light') applyTheme('light');
    }
  });
	let { children } = $props();
</script>

{@render children()}

<svelte:head>
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet" />
  <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded" rel="stylesheet" />
</svelte:head>
<header class="fixed top-0 w-full z-50 backdrop-blur bg-[#f8fafcdd] dark:bg-[#18181cdd] h-[68px] flex items-center font-sans">
  <div class="w-full flex items-center h-full px-4">
    <nav class="flex justify-end items-center w-full h-full">
      <ul class="hidden sm:flex flex-row gap-4 sm:gap-6 items-center h-full font-sans">
        <li>
          <a href="{base}/privacypolicy" class="mainnav-link text-base font-semibold leading-none px-1 text-black dark:text-white">
            Privacy Policy
          </a>
        </li>
        <li>
          <a href="{base}/faq" class="mainnav-link text-base font-semibold leading-none px-1 text-black dark:text-white">
            F.A.Q.
          </a>
        </li>
        <li>
          <button
            class="w-10 h-10 rounded-full flex items-center justify-center p-0 ml-1 hover:bg-slate-200 hover:dark:bg-slate-700"
            aria-label="Toggle dark mode"
            type="button"
            onclick={cycleTheme}
          >
            <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none">
              {theme == 'dark'
                  ? 'light_mode'
                  : 'dark_mode'}
            </span>
          </button>
        </li>
      </ul>
      <div class="sm:hidden ml-auto relative">
        <button
          class="w-10 h-10 rounded-full flex items-center justify-center hover:bg-slate-200 hover:dark:bg-slate-700 transition-colors"
          aria-label="Open menu"
          onclick={toggleMenu}
        >
          <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none">
            menu
          </span>
        </button>
        {#if menuOpen}
          <div class="absolute right-0 mt-2 w-48 rounded-xl shadow-lg bg-white dark:bg-[#18181c] border border-slate-200 dark:border-slate-800 py-2 z-50 animate-fade-in">
            <div class="flex flex-col items-center justify-center text-center">
              <a href="/privacypolicy" class=" block w-full px-4 py-3 text-black dark:text-white font-semibold rounded-t-xl text-center" onclick={closeMenu}>Privacy Policy</a>
              <a href="/faq" class="block w-full px-4 py-3 text-black dark:text-white font-semibold text-center" onclick={closeMenu}>F.A.Q.</a>
              <button
                class="w-10 h-10 rounded-full flex items-center justify-center m-2 hover:bg-slate-200 hover:dark:bg-slate-700 transition-colors"
                aria-label="Toggle dark mode"
                type="button"
                onclick={() => { cycleTheme(); closeMenu(); }}
              >
                <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none">
                  {theme === 'dark'
                      ? 'light_mode'
                      : 'dark_mode'}
                </span>
              </button>
            </div>
          </div>
        {/if}
      </div>
    </nav>
  </div>
</header>

<footer class="w-full py-6 text-center bg-[#f7fafc] dark:bg-[#18181c] text-gray-400 dark:text-gray-500 text-xs" style="font-family:inherit;">
  <div class="w-full max-w-4xl mx-auto px-4">
    © {new Date().getFullYear()} Mihai-Eduard Ghețu. All Rights Reserved.
  </div>
</footer>
<style>
	.mainnav-link {
  text-decoration: none;
  border-radius: 0.5rem;
  transition: background 0.16s, color 0.16s;
  font-weight: 600;
  padding-left: 13px;
  padding-right: 13px;
  padding-top: 7px;
  padding-bottom: 7px;
  display: inline-block;
  line-height: 1.4;
}
@media (hover: hover) {
  .mainnav-link:hover,
  .mainnav-link:focus-visible {
    background: rgba(0,0,0,0.06);
  }
  :global(html.dark) .mainnav-link:hover,
  :global(html.dark) .mainnav-link:focus-visible {
    background: rgba(255,255,255,0.13);
  }
}
@keyframes fade-in {
  from { opacity: 0; transform: translateY(-10px);}
  to { opacity: 1; transform: translateY(0);}
}
.animate-fade-in {
  animation: fade-in 0.18s cubic-bezier(.4,0,.2,1);
}
</style>
