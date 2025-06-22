<script lang="ts">
  import { onMount } from "svelte";

  let tonOn = true;
  let videoSrc = '/with.mp4';
  $: videoSrc = tonOn ? '/with.mp4' : '/without.mp4';

  type Theme = 'light' | 'dark' | 'system';
  let theme: Theme = 'system';
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
      else applyTheme('system');
    }
  });

  function toggleTonOn() {
    tonOn = !tonOn;
  }

  const repoOwner = 'turtle-key';
  const repoName = 'TabLift';

  let menuOpen = false;
  function toggleMenu() {
    menuOpen = !menuOpen;
  }
  function closeMenu() {
    menuOpen = false;
  }
</script>

<svelte:head>
  <title>TabLift</title>
  <meta name="description" content="TabLift — Fresh visuals for tab & window management on macOS." />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet" />
  <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded" rel="stylesheet" />
</svelte:head>

<header class="fixed top-0 w-full z-50 backdrop-blur bg-[#f8fafcdd] dark:bg-[#18181cdd] h-[68px] flex items-center font-sans" style="font-family:Arial, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;">
  <div class="w-full flex items-center h-full px-4">
    <nav class="flex justify-end items-center w-full h-full">
      <ul class="hidden sm:flex flex-row gap-4 sm:gap-6 items-center h-full font-sans">
        <li>
          <a href="/privacypolicy" class="hover:underline text-base font-semibold leading-none px-1 text-slate-800 dark:text-slate-200">
            Privacy Policy
          </a>
        </li>
        <li>
          <a href="/faq" class="hover:underline text-base font-semibold leading-none px-1 text-slate-800 dark:text-slate-200">
            F.A.Q.
          </a>
        </li>
        <li>
          <button
            class="w-10 h-10 rounded-full flex items-center justify-center p-0 ml-1 hover:bg-slate-200 hover:dark:bg-slate-700 transition-colors"
            aria-label="Toggle dark mode"
            type="button"
            on:click={cycleTheme}
          >
            <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none">
              {theme === 'system'
                ? 'settings_brightness'
                : darkMode
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
          on:click={toggleMenu}
        >
          <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none">
            menu
          </span>
        </button>
        {#if menuOpen}
          <div class="absolute right-0 mt-2 w-48 rounded-xl shadow-lg bg-white dark:bg-[#18181c] border border-slate-200 dark:border-slate-800 py-2 z-50 animate-fade-in">
            <div class="flex flex-col items-center justify-center text-center">
              <a href="/privacypolicy" class="block w-full px-4 py-3 text-slate-800 dark:text-slate-200 font-semibold hover:bg-slate-100 dark:hover:bg-slate-700 rounded-t-xl text-center" on:click={closeMenu}>Privacy Policy</a>
              <a href="/faq" class="block w-full px-4 py-3 text-slate-800 dark:text-slate-200 font-semibold hover:bg-slate-100 dark:hover:bg-slate-700 text-center" on:click={closeMenu}>F.A.Q.</a>
              <button
                class="w-10 h-10 rounded-full flex items-center justify-center m-2 hover:bg-slate-200 hover:dark:bg-slate-700 transition-colors"
                aria-label="Toggle dark mode"
                type="button"
                on:click={() => { cycleTheme(); closeMenu(); }}
              >
                <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200 select-none">
                  {theme === 'system'
                    ? 'settings_brightness'
                    : darkMode
                      ? 'light_mode'
                      : 'dark_mode'}
                </span>
              </button>
            </div>
          </div>
          <div class="fixed inset-0 z-40" style="background:transparent;" on:click={closeMenu}></div>
        {/if}
      </div>
    </nav>
  </div>
</header>

<main class="min-h-screen bg-[#f7fafc] dark:bg-[#18181c] flex flex-col items-center font-sans pt-[90px]" style="font-family:Arial, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;">
  <div class="w-full max-w-4xl mx-auto px-4">
    <img src="/logo.png" alt="TabLift Icon" class="mx-auto mt-8 mb-5 w-16 h-16 rounded-2xl shadow" draggable="false" loading="lazy" decoding="async" />
    <h1 class="text-3xl sm:text-4xl font-extrabold text-gray-900 dark:text-gray-100 text-center mb-2">TabLift</h1>
    <p class="text-gray-600 dark:text-gray-300 mb-6 text-center text-sm sm:text-base max-w-lg mx-auto">
      Fresh visuals for Tab, Window and Workspace Management.
    </p>
    <div class="flex flex-col items-center mb-8 w-full">
      <a
        class="px-8 py-3 rounded-xl font-semibold text-white text-base shadow transition mb-4"
        style="background:#102943;"
        rel="noopener"
        href={`https://github.com/${repoOwner}/${repoName}/releases/latest/download/TabLift.dmg`}
        download
      >
        Download
      </a>
    </div>
    <div class="relative flex items-center flex-col mb-6 w-full max-w-4xl px-2 aspect-[700/430]">
      <img src="/macbook.png" class="w-full absolute pointer-events-none select-none" alt="macOS screenshot" style="top: -15.25%;">
      <video
        src={videoSrc}
        muted
        playsinline
        loop
        autoplay
        class="relative z-10"
        style="width:76.7%;aspect-ratio:700/430;object-fit:cover;border-radius:18px;top:3.5%;"
      ></video>
    </div>
    <div class="flex justify-center items-center w-full mb-10">
      <span class="text-lg font-semibold select-none mr-4 text-slate-400 dark:text-slate-500" style="font-family:inherit;">
        App
      </span>
      <button
          class="switch-ios mx-2"
          role="switch"
          aria-checked={tonOn}
          aria-label={tonOn ? 'Deactivate app' : 'Activate app'}
          type="button"
          on:click={toggleTonOn}
          tabindex="0"
        > <span class="slider-ios {tonOn ? 'checked' : ''}"></span>
      </button>
      <span class="text-lg font-semibold select-none ml-4" style="color: {tonOn ? '#34C759' : '#a0aec0'};font-family:inherit;">
        {tonOn ? 'activated' : 'deactivated'}
      </span>
    </div>
    <div class="w-full flex flex-col items-center">
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 justify-center items-stretch w-full max-w-4xl">
        <div class="flex flex-col items-center text-center bg-blue-50 dark:bg-blue-900 border border-blue-100 dark:border-blue-800 rounded-xl p-5 min-w-[210px] h-full">
          <div class="flex items-center gap-2 mb-1 text-blue-600 dark:text-blue-300">
            <span class="material-symbols-rounded text-base">volume_up</span>
            <span class="font-semibold text-sm">Volume &amp; Tabs</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">Quickly adjust volume and organize browser tabs with modern, compact popups.</p>
        </div>
        <div class="flex flex-col items-center text-center bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-xl p-5 min-w-[210px] h-full">
          <div class="flex items-center gap-2 mb-1 text-gray-500 dark:text-gray-300">
            <span class="material-symbols-rounded text-base">brightness_6</span>
            <span class="font-semibold text-sm">Window Management</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">Arrange, group, and save your window layouts. Instantly restore your workspace.</p>
        </div>
        <div class="flex flex-col items-center text-center bg-rose-50 dark:bg-rose-900 border border-rose-100 dark:border-rose-900 rounded-xl p-5 min-w-[210px] h-full">
          <div class="flex items-center gap-2 mb-1 text-rose-500 dark:text-rose-300">
            <span class="material-symbols-rounded text-base">music_note</span>
            <span class="font-semibold text-sm">Now Playing</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">See what’s playing in any tab or app. Details at a glance, tucked in the notch.</p>
        </div>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 justify-center items-stretch mt-4 w-full max-w-4xl">
        <div class="flex flex-col items-center text-center bg-yellow-50 dark:bg-yellow-900 border border-yellow-100 dark:border-yellow-800 rounded-xl p-5 min-w-[210px] h-full">
          <div class="flex items-center gap-1 mb-1 text-yellow-500 dark:text-yellow-300">
            <span class="material-symbols-rounded text-base">verified_user</span>
            <span class="font-semibold text-sm">Supported OS</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200 text-center">macOS 13+</p>
        </div>
        <div class="flex flex-col items-center text-center bg-green-50 dark:bg-green-900 border border-green-100 dark:border-green-800 rounded-xl p-5 min-w-[210px] h-full">
          <div class="flex items-center gap-1 mb-1 text-green-600 dark:text-green-300">
            <span class="material-symbols-rounded text-base">devices</span>
            <span class="font-semibold text-sm">Supported Devices</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200 text-center">All Macs supported. TouchBar Macs may require special mode.</p>
        </div>
      </div>
    </div>
  </div>
</main>

<footer class="w-full py-6 text-center bg-[#f7fafc] dark:bg-[#18181c] text-gray-400 dark:text-gray-500 text-xs" style="font-family:inherit;">
  <div class="w-full max-w-4xl mx-auto px-4">
    © {new Date().getFullYear()} Mihai-Eduard Ghețu. All Rights Reserved.
  </div>
</footer>

<style>
.switch-ios {
  position: relative;
  display: inline-block;
  width: 54px;
  height: 32px;
  vertical-align: middle;
  background: none;
  border: none;
  padding: 0;
}
.slider-ios {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background-color: #e5e7eb;
  border-radius: 9999px;
  transition: background-color 0.2s;
  width: 54px;
  height: 32px;
  display: block;
}
.slider-ios.checked {
  background-color: #34C759;
}
.dark .slider-ios {
  background-color: #44474c;
}
.dark .slider-ios.checked {
  background-color: #34C759;
}
.slider-ios:before {
  position: absolute;
  content: "";
  height: 24px;
  width: 24px;
  left: 4px;
  bottom: 4px;
  background-color: white;
  border-radius: 50%;
  transition: transform 0.2s;
  box-shadow: 0 1px 4px #0001;
  transform: translateX(0);
}
.slider-ios.checked:before {
  transform: translateX(22px);
}
@keyframes fade-in {
  from { opacity: 0; transform: translateY(-10px);}
  to { opacity: 1; transform: translateY(0);}
}
.animate-fade-in {
  animation: fade-in 0.18s cubic-bezier(.4,0,.2,1);
}
</style>