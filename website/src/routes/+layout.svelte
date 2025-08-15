<script lang="ts">
  import { base } from '$app/paths';
  import { page } from '$app/stores';
  import '../app.css';
  import { onMount, onDestroy } from "svelte";
  import { fly, fade } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';
  
  let menuOpen = $state(false);
  function toggleMenu() { menuOpen = !menuOpen; }
  function closeMenu() { menuOpen = false; }
  type ThemeMode = 'auto' | 'light' | 'dark';
  type Theme = 'light' | 'dark';
  let themeMode: ThemeMode = $state('auto');
  let theme: Theme = $state('light');
  let darkMode = false;

  let mediaQueryList: MediaQueryList | null = null;

  function applyThemeMode(mode: ThemeMode, userInitiated = false) {
    themeMode = mode;
    if (mode === 'auto') {
      localStorage.removeItem('theme');
      updateAutoTheme();
    } else {
      localStorage.theme = mode;
      setTheme(mode);
    }
  }

  function setTheme(newTheme: Theme) {
    theme = newTheme;
    if (theme === 'light') {
      document.documentElement.classList.remove('dark');
      darkMode = false;
    } else if (theme === 'dark') {
      document.documentElement.classList.add('dark');
      darkMode = true;
    }
  }

  function updateAutoTheme() {
    const prefersDark = mediaQueryList?.matches ?? false;
    setTheme(prefersDark ? 'dark' : 'light');
  }

  function handleSystemThemeChange(e: MediaQueryListEvent) {
    if (themeMode === 'auto') {
      setTheme(e.matches ? 'dark' : 'light');
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

  function cycleThemeMode() {
    if (themeMode === 'auto') applyThemeMode('light', true);
    else if (themeMode === 'light') applyThemeMode('dark', true);
    else if (themeMode === 'dark') applyThemeMode('auto', true);
  }

  onMount(() => {
    if (typeof window !== 'undefined') {
      mediaQueryList = window.matchMedia('(prefers-color-scheme: dark)');
      if ('theme' in localStorage) {
        const stored = localStorage.theme;
        if (stored === 'light' || stored === 'dark') {
          applyThemeMode(stored as ThemeMode, false);
        } else {
          applyThemeMode('auto', false);
        }
      } else {
        applyThemeMode('auto', false);
      }
      if (mediaQueryList.addEventListener) {
        mediaQueryList.addEventListener('change', handleSystemThemeChange);
      } else if (mediaQueryList.addListener) {
        mediaQueryList.addListener(handleSystemThemeChange);
      }
    }
    const path = window.location.pathname.replace(base, '');
    const menuId = getMenuIdFromPath(path);
    highlightMenuItem(menuId);
  });

  onDestroy(() => {
    if (mediaQueryList) {
      if (mediaQueryList.removeEventListener) {
        mediaQueryList.removeEventListener('change', handleSystemThemeChange);
      } else if (mediaQueryList.removeListener) {
        mediaQueryList.removeListener(handleSystemThemeChange);
      }
    }
  });

  let currPath = $derived.by(() =>
    $page.url.pathname.replace(base, '').replace(/\/+$/, '') || '/'
  );
  let activeId = $derived.by(() =>
    currPath === '/' ? 'home' : currPath.split('/').pop()
  );
  let { children } = $props();
</script>

<svelte:head>
  <link rel="icon" type="image/x-icon" href={base+"/favicon.ico"}>

  <!-- PNG favicons for browsers -->
  <link rel="icon" type="image/png" sizes="32x32" href={base+"/favicon-32x32.png"}>
  <link rel="icon" type="image/png" sizes="16x16" href={base+"/favicon-16x16.png"}>

  <!-- Apple touch icon -->
  <link rel="apple-touch-icon" sizes="180x180" href={base+"/apple-touch-icon.png"}>

  <!-- Android / Chrome icons -->
  <link rel="icon" type="image/png" sizes="192x192" href={base+"/android-chrome-192x192.png"}>
  <link rel="icon" type="image/png" sizes="512x512" href={base+"/android-chrome-512x512.png"}>

  <!-- Web manifest -->
  <link rel="manifest" href={base+"/site.webmanifest"}>

  <link rel="preconnect" href="https://fonts.googleapis.com" crossorigin="anonymous">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet" />
  <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded&display=swap" rel="stylesheet" />
  <meta property="og:url" content="https://tablift.dev">
  <meta property="og:type" content="website">
  <meta property="og:title" content="TabLift — Makes Cmd+Tab work the way it should — minimized windows included">
  <meta property="og:description" content="TabLift is a lightweight macOS utility that restores minimized apps instantly when switching with Cmd+Tab. By default, macOS ignores minimized windows unless you hold the Option key. TabLift fixes this behavior, making app switching intuitive and seamless — no extra keys needed.">
  <meta property="og:image" content="https://bucket.tablift.dev/banner.png">
  <meta property="og:site_name" content="TabLift">
  <meta name="twitter:card" content="summary_large_image">
  <meta property="twitter:domain" content="tablift.dev">
  <meta property="twitter:url" content="https://tablift.dev">
  <meta name="twitter:title" content="TabLift — Makes Cmd+Tab work the way it should — minimized windows included">
  <meta name="twitter:description" content="TabLift is a lightweight macOS utility that restores minimized apps instantly when switching with Cmd+Tab. By default, macOS ignores minimized windows unless you hold the Option key. TabLift fixes this behavior, making app switching intuitive and seamless — no extra keys needed.">
  <meta name="twitter:image" content="https://bucket.tablift.dev/banner.png">
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
  <!-- Google Tag Manager -->
  <script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
  new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
  j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
  'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
  })(window,document,'script','dataLayer','GTM-WDR5C3BS');</script>
  <!-- End Google Tag Manager -->
</svelte:head>

{@render children()}

<!-- Google Tag Manager (noscript) -->
<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-WDR5C3BS"
height="0" width="0" style="display:none;visibility:hidden" title="Google Tag Manager"></iframe></noscript>
<!-- End Google Tag Manager (noscript) -->

<header class="fixed top-0 w-full z-50 backdrop-blur bg-[#f8fafcdd] dark:bg-[#18181cdd] h-[68px] flex items-center font-sans border-b border-black/5 dark:border-white/10">
  <div class="w-full flex items-center h-full px-4">
    {#if currPath !== '/'}
      {#key currPath}
        <a
          href={base + "/"}
          aria-label="Go to the homepage"
          class="icon-link mr-4"
          onclick={closeMenu}
        >
          <img
            src="https://bucket.tablift.dev/app-icon-168.webp"
            alt="TabLift icon"
            class="logo-image"
          >
        </a>
      {/key}
    {/if}
    
    <a
      href="https://github.com/turtle-key/TabLift"
      target="_blank"
      rel="noopener"
      aria-label="View on GitHub"
      class="github-btn flex items-center gap-2 py-2 rounded-lg font-semibold text-base bg-[#edece6] dark:bg-[#262524] text-[#22211c] dark:text-[#edece6] border border-[#d6d3c1] dark:border-[#353438] shadow-none hover:bg-[#e4e3dd] hover:dark:bg-[#302f2a] transition-all duration-200 mr-4"
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

    <!-- Header Sponsor Button (appears when not on home page, desktop only) -->
    {#if currPath !== '/'}
      {#key currPath}
        <a
          class="header-sponsor-btn group relative rounded-lg font-medium text-sm transition-all duration-500 overflow-hidden backdrop-blur-sm mr-4 hidden sm:flex"
          href="https://github.com/sponsors/turtle-key"
          target="_blank"
          rel="noopener"
        >
          <span class="sponsor-content relative z-10 flex items-center justify-center gap-1.5 tracking-wide">
            <svg class="w-3 h-3 transition-transform duration-300 group-hover:scale-110" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/>
            </svg>
            <span class="font-semibold">Sponsor</span>
          </span>
        </a>
      {/key}
    {/if}
    
    <nav class="flex justify-end items-center w-full h-full">
      <ul class="hidden sm:flex flex-row gap-4 sm:gap-6 items-center h-full font-sans">
        <li>
          <a
            href={base + "/privacypolicy"}
            class="mainnav-link text-base font-semibold leading-none px-1 text-black dark:text-white"
            id="privacypolicy"
            class:menu-active={activeId === 'privacypolicy'}
          >
            Privacy Policy
          </a>
        </li>
        <li>
          <a
            href={base + "/faq"}
            class="mainnav-link text-base font-semibold leading-none px-1 text-black dark:text-white"
            id="faq"
            class:menu-active={activeId === 'faq'}
          >
            F.A.Q.
          </a>
        </li>
        <li>
          <a
            href={base + "/blog"}
            class="mainnav-link text-base font-semibold leading-none px-1 text-black dark:text-white"
            id="blog"
            class:menu-active={activeId === 'blog'}
          >
            Blog
          </a>
        </li>
        <li>
          <button
            class="theme-toggle-btn w-10 h-10 rounded-full flex items-center justify-center p-0 ml-1 hover:bg-slate-200 hover:dark:bg-slate-700 transition-all duration-200"
            aria-label="Toggle theme mode"
            type="button"
            onclick={cycleThemeMode}
          >
            {#if themeMode === 'auto'}
              <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none" title="Auto mode">
                brightness_auto
              </span>
            {:else if (themeMode === 'light')}
              <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none" title="Light mode">
                light_mode
              </span>
            {:else}
              <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none" title="Dark mode">
                dark_mode
              </span>
            {/if}
          </button>
        </li>
      </ul>
      
      <!-- Mobile Menu Toggle Button -->
      <div class="sm:hidden ml-auto relative">
        <button
          class="menu-toggle-btn w-10 h-10 rounded-full flex items-center justify-center hover:bg-slate-200 hover:dark:bg-slate-700 transition-all duration-200"
          aria-label={menuOpen ? "Close menu" : "Open menu"}
          onclick={toggleMenu}
        >
          <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none">
            {menuOpen ? 'close' : 'menu'}
          </span>
        </button>
      </div>
    </nav>
  </div>
</header>

<!-- Fullscreen Mobile Menu -->
{#if menuOpen}
  <div 
    class="fixed inset-0 z-[100] bg-white dark:bg-gray-900 sm:hidden"
    in:fade={{ duration: 200 }}
    out:fade={{ duration: 150 }}
  >
    <div class="flex flex-col h-full">
      <!-- Mobile Menu Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-800">
        <h2 class="text-lg font-bold text-gray-900 dark:text-white">Menu</h2>
        <button
          class="w-10 h-10 rounded-full flex items-center justify-center hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
          aria-label="Close menu"
          onclick={closeMenu}
        >
          <span class="material-symbols-rounded text-2xl text-gray-600 dark:text-gray-300">close</span>
        </button>
      </div>
      
      <!-- Mobile Menu Content -->
      <div class="flex-1 overflow-y-auto p-4">
        <div class="space-y-4">
          <!-- Navigation Links -->
          <div class="space-y-2">
            <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider px-2">Navigation</h3>
            
            <a 
              href={base + "/privacypolicy"} 
              class="mobile-menu-link flex items-center w-full px-4 py-4 text-gray-800 dark:text-gray-200 font-medium rounded-xl transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-800"
              class:menu-active={activeId === 'privacypolicy'} 
              onclick={closeMenu}
            >
              <span class="material-symbols-rounded text-xl mr-4 opacity-80">policy</span>
              Privacy Policy
            </a>
            
            <a 
              href={base + "/faq"} 
              class="mobile-menu-link flex items-center w-full px-4 py-4 text-gray-800 dark:text-gray-200 font-medium rounded-xl transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-800"
              class:menu-active={activeId === 'faq'} 
              onclick={closeMenu}
            >
              <span class="material-symbols-rounded text-xl mr-4 opacity-80">help</span>
              F.A.Q.
            </a>

            <a 
              href={base + "/blog"} 
              class="mobile-menu-link flex items-center w-full px-4 py-4 text-gray-800 dark:text-gray-200 font-medium rounded-xl transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-800"
              class:menu-active={activeId === 'blog'} 
              onclick={closeMenu}
            >
              <span class="material-symbols-rounded text-xl mr-4 opacity-80">article</span>
              Blog
            </a>
          </div>
          
          <!-- External Links -->
          <div class="space-y-2 pt-4 border-t border-gray-200 dark:border-gray-800">
            <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider px-2">Links</h3>
            
            <a 
              href="https://github.com/turtle-key/TabLift"
              target="_blank"
              rel="noopener"
              class="mobile-menu-link flex items-center w-full px-4 py-4 text-gray-800 dark:text-gray-200 font-medium rounded-xl transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-800"
              onclick={closeMenu}
            >
              <span class="mr-4 w-5 h-5">
                <svg fill="currentColor" viewBox="0 0 16 16">
                  <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.67.07-.52.28-.87.5-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"/>
                </svg>
              </span>
              GitHub
            </a>
            
            <!-- Mobile Sponsor Button -->
            <a
              class="mobile-sponsor-btn group relative flex items-center w-full px-4 py-4 rounded-xl font-medium text-gray-800 dark:text-gray-200 transition-all duration-500 overflow-hidden"
              href="https://github.com/sponsors/turtle-key"
              target="_blank"
              rel="noopener"
              onclick={closeMenu}
            >
              <span class="sponsor-content relative z-10 flex items-center gap-4">
                <svg class="w-5 h-5 transition-transform duration-300 group-hover:scale-110" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/>
                </svg>
                <span class="font-medium">Sponsor this project</span>
              </span>
            </a>
          </div>
        </div>
      </div>
      
      <!-- Theme Toggle Section -->
      <div class="p-4 border-t border-gray-200 dark:border-gray-800">
        <div class="flex items-center justify-between">
          <span class="font-medium text-gray-800 dark:text-gray-200">Theme</span>
          <div class="flex items-center gap-4">
            <button
              class="mobile-theme-btn flex flex-col items-center justify-center p-3 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              aria-label="Auto theme"
              type="button"
              onclick={() => { applyThemeMode('auto'); }}
              class:active-theme={themeMode === 'auto'}
            >
              <span class="material-symbols-rounded text-xl text-gray-600 dark:text-gray-400 mb-1">brightness_auto</span>
              <span class="text-xs dark:text-white">Auto</span>
            </button>
            
            <button
              class="mobile-theme-btn flex flex-col items-center justify-center p-3 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              aria-label="Light theme"
              type="button"
              onclick={() => { applyThemeMode('light'); }}
              class:active-theme={themeMode === 'light'}
            >
              <span class="material-symbols-rounded text-xl text-gray-600 dark:text-gray-400 mb-1">light_mode</span>
              <span class="text-xs dark:text-white">Light</span>
            </button>
            
            <button
              class="mobile-theme-btn flex flex-col items-center justify-center p-3 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              aria-label="Dark theme"
              type="button"
              onclick={() => { applyThemeMode('dark'); }}
              class:active-theme={themeMode === 'dark'}
            >
              <span class="material-symbols-rounded text-xl text-gray-600 dark:text-gray-400 mb-1">dark_mode</span>
              <span class="text-xs dark:text-white">Dark</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}

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
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
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
    background: rgba(0,0,0,0.08);
    transform: translateY(-1px);
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  }
  :global(html.dark) .mainnav-link:hover,
  :global(html.dark) .mainnav-link:focus-visible {
    background: rgba(255,255,255,0.15);
    box-shadow: 0 2px 8px rgba(255,255,255,0.1);
  }
}

.github-btn {
  font-family: inherit;
  background: #edece6;
  color: #22211c;
  border: 1.5px solid #d6d3c1;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  border-radius: 8px;
  gap: 8px;
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
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
  box-shadow: 0 1px 3px rgba(0,0,0,0.3);
}

.github-btn:hover {
  background: #e4e3dd;
  color: #18181c;
  border-color: #bdb9a2;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}

:global(html.dark) .github-btn:hover {
  background: #302f2a;
  color: #fff;
  border-color: #57534e;
  box-shadow: 0 4px 12px rgba(0,0,0,0.4);
}

.github-btn:active {
  transform: translateY(0px);
  box-shadow: 0 2px 6px rgba(0,0,0,0.1);
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
  transition: transform 0.2s ease;
}

.github-btn:hover .github-icon {
  transform: scale(1.1);
}

.github-btn:hover .external-link-icon {
  transform: translate(2px, -2px);
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
  transition: all 0.2s ease;
}

/* Header Sponsor Button (Desktop Only) */
.header-sponsor-btn {
  background: linear-gradient(135deg, rgba(255,255,255,0.8) 0%, rgba(248,250,252,0.7) 100%);
  color: #374151;
  border: 1px solid rgba(209, 213, 219, 0.5);
  box-shadow: 0 2px 8px rgba(0,0,0,0.06), inset 0 1px 0 rgba(255,255,255,0.5);
  text-decoration: none;
  align-items: center;
  justify-content: center;
  min-width: 140px;
  text-align: center;
  position: relative;
  font-weight: 500;
  letter-spacing: 0.025em;
  padding: 0.5rem 1rem;
  height: 40px;
}

:global(html.dark) .header-sponsor-btn {
  background: linear-gradient(135deg, rgba(31,41,55,0.8) 0%, rgba(17,24,39,0.7) 100%);
  color: #f3f4f6;
  border-color: rgba(75, 85, 99, 0.5);
  box-shadow: 0 2px 8px rgba(0,0,0,0.2), inset 0 1px 0 rgba(255,255,255,0.1);
}

.header-sponsor-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(
    to bottom,
    #61BB46 0%,
    #61BB46 16.66%,
    #FDB827 16.66%,
    #FDB827 33.33%,
    #F5821F 33.33%,
    #F5821F 50%,
    #E03A3E 50%,
    #E03A3E 66.66%,
    #963D97 66.66%,
    #963D97 83.33%,
    #009DDC 83.33%,
    #009DDC 100%
  );
  transform: translateY(-100%);
  transition: transform 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94);
  z-index: 1;
  border-radius: inherit;
  opacity: 0.9;
}

.header-sponsor-btn:hover::before {
  transform: translateY(0%);
}

.header-sponsor-btn:not(:hover)::before {
  transform: translateY(100%);
  transition: transform 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}

.header-sponsor-btn:hover .sponsor-content {
  color: white;
  filter: drop-shadow(0 1px 2px rgba(0,0,0,0.3));
}

/* Mobile Sponsor Button */
.mobile-sponsor-btn {
  position: relative;
  overflow: hidden;
}

.mobile-sponsor-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(
    to bottom,
    #61BB46 0%,
    #61BB46 16.66%,
    #FDB827 16.66%,
    #FDB827 33.33%,
    #F5821F 33.33%,
    #F5821F 50%,
    #E03A3E 50%,
    #E03A3E 66.66%,
    #963D97 66.66%,
    #963D97 83.33%,
    #009DDC 83.33%,
    #009DDC 100%
  );
  transform: translateY(-100%);
  transition: transform 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94);
  z-index: 1;
  border-radius: inherit;
  opacity: 0.9;
}

.mobile-sponsor-btn:hover::before {
  transform: translateY(0%);
}

.mobile-sponsor-btn:not(:hover)::before {
  transform: translateY(100%);
  transition: transform 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}

.mobile-sponsor-btn:hover .sponsor-content {
  color: white;
  filter: drop-shadow(0 1px 2px rgba(0,0,0,0.3));
}

.theme-toggle-btn:hover .material-symbols-rounded {
  transform: scale(1.1);
}

.menu-toggle-btn:hover .material-symbols-rounded {
  transform: scale(1.1);
}

.mobile-theme-btn:hover .material-symbols-rounded {
  transform: scale(1.1);
}

.mobile-menu-link.menu-active {
  background: rgba(59, 130, 246, 0.1) !important;
  color: #3b82f6 !important;
  border-left: 3px solid #3b82f6;
}

:global(html.dark) .mobile-menu-link.menu-active {
  background: rgba(59, 130, 246, 0.2) !important;
  color: #60a5fa !important;
}

.active-theme {
  background: rgba(59, 130, 246, 0.1) !important;
  color: #3b82f6 !important;
}

:global(html.dark) .active-theme {
  background: rgba(59, 130, 246, 0.2) !important;
  color: #60a5fa !important;
}

.active-theme .material-symbols-rounded {
  color: #3b82f6 !important;
}

:global(html.dark) .active-theme .material-symbols-rounded {
  color: #60a5fa !important;
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

.icon-link {
  width: 3rem;
  height: 3rem;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.5rem;
  padding: 20px;
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

.icon-link:hover, .icon-link:focus-visible {
  background: rgba(31, 41, 55, 0.1);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

:global(html.dark) .icon-link:hover, 
:global(html.dark) .icon-link:focus-visible {
  background: #302f2a;
  box-shadow: 0 4px 12px rgba(0,0,0,0.3);
}

.icon-link:active {
  transform: translateY(0px);
}

.logo-image {
  width: 40px;
  height: 40px;
  min-width: 40px;
  min-height: 40px;
  max-width: 40px;
  max-height: 40px;
  border-radius: 10px;
  object-fit: cover;
}
</style>
