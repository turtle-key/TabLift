<script lang="ts">
  import { base } from '$app/paths';
  import { page } from '$app/stores';
  import '../app.css';
  import { onMount } from "svelte";
  let menuOpen = $state(false);
  function toggleMenu() { menuOpen = !menuOpen; }
  function closeMenu() { menuOpen = false; }
  type Theme = 'light' | 'dark';
  let theme: Theme = $state('light');
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
  function highlightMenuItem(currpage: string) {
    document.querySelectorAll('.mainnav-link').forEach(el => {
      el.classList.remove('menu-active');
    });
    var elem = document.getElementById(currpage);
    elem?.classList.add('menu-active');
  }
  function getMenuIdFromPath(path: string){
    path = path.replace(/\/+$/, '');
    if (path === '' || path === '/' || path === base) return 'home';
    const segments = path.split('/');
    return segments[segments.length - 1] || 'home';
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
    const path = window.location.pathname.replace(base, '');
    const menuId = getMenuIdFromPath(path);
    highlightMenuItem(menuId);
  });
  let currPath = $derived(() =>
    $page.url.pathname.replace(base, '').replace(/\/+$/, '') || '/'
  );
  let activeId = $derived(() =>
    currPath() === '/' ? 'home' : currPath().split('/').pop()
  );
  let { children } = $props();
</script>


<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" crossorigin="anonymous">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet" />
  <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded&display=swap" rel="stylesheet" />
  <meta property="og:url" content="https://tablift.mihai.sh">
  <meta property="og:type" content="website">
  <meta property="og:title" content="TabLift — Makes ⌘+Tab work the way it should — minimized windows included">
  <meta property="og:description" content="TabLift is a lightweight macOS utility that restores minimized apps instantly when switching with ⌘+Tab. By default, macOS ignores minimized windows unless you hold the Option key. TabLift fixes this behavior, making app switching intuitive and seamless — no extra keys needed.">
  <meta property="og:image" content="https://bucket.mihai.sh/banner.png">
  <meta property="og:site_name" content="TabLift">
  <meta name="twitter:card" content="summary_large_image">
  <meta property="twitter:domain" content="tablift.mihai.sh">
  <meta property="twitter:url" content="https://tablift.mihai.sh">
  <meta name="twitter:title" content="TabLift — Makes ⌘+Tab work the way it should — minimized windows included">
  <meta name="twitter:description" content="TabLift is a lightweight macOS utility that restores minimized apps instantly when switching with ⌘+Tab. By default, macOS ignores minimized windows unless you hold the Option key. TabLift fixes this behavior, making app switching intuitive and seamless — no extra keys needed.">
  <meta name="twitter:image" content="https://bucket.mihai.sh/banner.png">
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "TabLift",
    "operatingSystem": "macOS 13+",
    "applicationCategory": "ProductivityApplication",
    "description": "TabLift — Fresh visuals for tab & window management on macOS.",
    "offers": {
      "@type": "Offer",
      "price": "0",
      "priceCurrency": "USD"
    }
  }
  </script>
</svelte:head>
{@render children()}
<header class="fixed top-0 w-full z-50 backdrop-blur bg-[#f8fafcdd] dark:bg-[#18181cdd] h-[68px] flex items-center font-sans">
  <div class="w-full flex items-center h-full px-4">
    <a
      href="https://github.com/turtle-key/TabLift"
      target="_blank"
      rel="noopener"
      aria-label="View on GitHub"
      class="github-btn flex items-center gap-2 py-2 rounded-lg font-semibold text-base bg-[#edece6] dark:bg-[#262524] text-[#22211c] dark:text-[#edece6] border border-[#d6d3c1] dark:border-[#353438] shadow-none hover:bg-[#e4e3dd] hover:dark:bg-[#302f2a] transition-colors mr-4"
    >
      <svg
        aria-hidden="true"
        fill="currentColor"
        class="github-icon"
        viewBox="0 0 16 16"
      >
        <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38
          0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52
          -.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.67.07-.52.28-.87.5-1.07-1.78-.2
          -3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21
          2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16
          1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48
          0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"/>
      </svg>
      <span class="github-label">GitHub</span>
      <span class="material-symbols-rounded external-link-icon" aria-hidden="true">open_in_new</span>
    </a>
    <nav class="flex justify-end items-center w-full h-full">
      <ul class="hidden sm:flex flex-row gap-4 sm:gap-6 items-center h-full font-sans">
        <li>
          <a
            href={base + "/privacypolicy"}
            class="mainnav-link text-base font-semibold leading-none px-1 text-black dark:text-white"
            id="privacypolicy"
            class:menu-active={activeId() === 'privacypolicy'}
          >
            Privacy Policy
          </a>
        </li>
        <li>
          <a
            href={base + "/faq"}
            class="mainnav-link text-base font-semibold leading-none px-1 text-black dark:text-white"
            id="faq"
            class:menu-active={activeId() === 'faq'}
          >
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
              {theme === 'dark'
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
              <a href={base + "/privacypolicy"} class="block w-full px-4 py-3 text-black dark:text-white font-semibold rounded-t-xl text-center" class:menu-active={activeId() === 'privacypolicy'} onclick={closeMenu}>Privacy Policy</a>
              <a href={base + "/faq"} class="block w-full px-4 py-3 text-black dark:text-white font-semibold text-center" class:menu-active={activeId() === 'faq'} onclick={closeMenu}>F.A.Q.</a>
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
:global(.menu-active) {
  background: #2B3440 !important;
  color: #fff !important;
}
:global(html.dark) :global(.menu-active) {
  background: #fff2 !important;
  color: #fff !important;
}
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
.github-btn {
  font-family: inherit;
  background: #edece6;
  color: #22211c;
  border: 1.5px solid #d6d3c1;
  box-shadow: none;
  border-radius: 8px;
  gap: 8px;
  transition: background 0.15s, color 0.15s, border 0.15s;
  display: flex;
  align-items: center;
  cursor: pointer;
  font-weight: 600;
  line-height: 1.1;
  text-decoration: none;
  padding-left: 1em;
  padding-right: 1em;
}
:global(html.dark) .github-btn {
  background: #262524;
  color: #edece6;
  border: 1.5px solid #353438;
}
.github-btn:hover {
  background: #e4e3dd;
  color: #18181c;
  border-color: #bdb9a2;
}
:global(html.dark) .github-btn:hover {
  background: #302f2a;
  color: #fff;
  border-color: #57534e;
}
.github-icon, .external-link-icon {
  width: 1em;
  height: 1em;
  min-width: 16px;
  min-height: 16px;
  max-width: 18px;
  max-height: 18px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  vertical-align: middle;
  flex-shrink: 0;
}
.external-link-icon {
  position: relative;
  top: 0.5px;
  font-size: 1em;
  line-height: 1;
}
.github-label {
  display: inline-block;
  min-width: 54px;
  text-align: center;
  transition: color 0.15s, min-width 0.15s;
}
@media (max-width: 639px) {
  .github-label {
    color: transparent !important;
    min-width: 0;
    width: 0;
    padding: 0;
    margin: 0;
    user-select: none;
    pointer-events: none;
    transition: color 0.15s, min-width 0.15s;
  }
  .github-btn {
    padding-left: 0.7em;
    padding-right: 0.7em;
    gap: 6px;
  }
  .github-icon, .external-link-icon {
    width: 1em;
    height: 1em;
    min-width: 14px;
    min-height: 14px;
    max-width: 16px;
    max-height: 16px;
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