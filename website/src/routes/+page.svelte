<script lang="ts">
  import { onMount } from 'svelte';

  let tonOn = true;
  let videoSrc = '/with.mp4';

  $: videoSrc = tonOn ? '/with.mp4' : '/without.mp4';

  let darkMode = false;

  // Persist dark mode in localStorage
  onMount(() => {
    if (typeof window !== 'undefined') {
      darkMode = localStorage.getItem('tablift-dark') === 'true';
      updateDarkClass();
    }
  });

  function toggleDark() {
    darkMode = !darkMode;
    localStorage.setItem('tablift-dark', darkMode ? 'true' : 'false');
    updateDarkClass();
  }

  function updateDarkClass() {
    if (typeof document !== 'undefined') {
      if (darkMode) {
        document.documentElement.classList.add('dark');
      } else {
        document.documentElement.classList.remove('dark');
      }
    }
  }

  const repoOwner = 'turtle-key';
  const repoName = 'TabLift';
</script>

<svelte:head>
  <title>TabLift</title>
  <meta name="description" content="TabLift — Fresh visuals for tab & window management on macOS." />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet" />
  <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded" rel="stylesheet" />
</svelte:head>

<!-- NAVBAR -->
<header class="fixed top-0 w-full z-50 backdrop-blur bg-[#f8fafcdd] dark:bg-[#13161add] h-[68px] flex items-center border-b border-slate-100 dark:border-slate-800 transition-colors" style="font-family: Arial, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;">
  <nav class="w-full flex justify-end items-center max-w-7xl mx-auto h-full pr-1 sm:pr-3">
    <ul class="flex flex-row gap-4 sm:gap-6 items-center h-full font-sans">
      <li>
        <a href="/privacypolicy" class="hover:underline text-base font-semibold leading-none px-1 text-slate-800 dark:text-slate-100" style="font-family:inherit;">
          Privacy Policy
        </a>
      </li>
      <li>
        <a href="/faq" class="hover:underline text-base font-semibold leading-none px-1 text-slate-800 dark:text-slate-100" style="font-family:inherit;">
          F.A.Q.
        </a>
      </li>
      <li>
        <!-- Dark mode toggle button, rightmost -->
        <button
          class="rounded-full p-2 ml-1 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors"
          aria-label="Toggle dark mode"
          on:click={toggleDark}
        >
          <span class="material-symbols-rounded text-2xl text-slate-600 dark:text-slate-200">
            {darkMode ? 'dark_mode' : 'light_mode'}
          </span>
        </button>
      </li>
    </ul>
  </nav>
</header>

<div class="min-h-screen bg-[#f7fafc] dark:bg-[#090c10] flex flex-col items-center font-sans pt-[90px] transition-colors duration-300" style="font-family: Arial, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;">
  <!-- Logo, title, and description -->
  <img src="/logo.png" alt="TabLift Icon" class="mx-auto mt-8 mb-5 w-16 h-16 rounded-2xl shadow" draggable="false" loading="lazy" decoding="async" />

  <h1 class="text-3xl sm:text-4xl font-extrabold text-gray-900 dark:text-slate-100 text-center mb-2">TabLift</h1>
  <p class="text-gray-600 dark:text-slate-300 mb-6 text-center text-sm sm:text-base max-w-lg mx-auto">
    Fresh visuals for Tab, Window and Workspace Management.
  </p>

  <!-- Download button -->
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

  <!-- MacBook mockup with resizable, fixed aspect ratio video inside -->
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

  <!-- Centered toggle row under the mac -->
  <div class="flex justify-center items-center w-full mb-10">
    <span class="text-lg font-semibold select-none mr-4 text-slate-400 dark:text-slate-400" style="font-family:inherit;">
      App
    </span>
    <label class="switch-ios mx-2" role="switch" aria-checked={tonOn}>
      <input type="checkbox" bind:checked={tonOn} />
      <span class="slider-ios"></span>
    </label>
    <span class="text-lg font-semibold select-none ml-4" style="color: {tonOn ? '#34C759' : '#a0aec0'};font-family:inherit;">
      {tonOn ? 'activated' : 'deactivated'}
    </span>
  </div>

  <!-- Feature cards -->
  <div class="flex flex-col sm:flex-row gap-4 justify-center mb-4 w-full max-w-4xl px-2">
    <div class="flex-1 bg-blue-50 dark:bg-blue-950 dark:border-blue-900 border border-blue-100 rounded-xl p-5 min-w-[210px]">
      <div class="flex items-center gap-2 mb-1 text-blue-600 dark:text-blue-300">
        <span class="material-symbols-rounded text-base">volume_up</span>
        <span class="font-semibold text-sm">Volume &amp; Tabs</span>
      </div>
      <p class="text-xs text-gray-700 dark:text-slate-200">Quickly adjust volume and organize browser tabs with modern, compact popups.</p>
    </div>
    <div class="flex-1 bg-gray-50 dark:bg-slate-900 dark:border-slate-800 border border-gray-100 rounded-xl p-5 min-w-[210px]">
      <div class="flex items-center gap-2 mb-1 text-gray-500 dark:text-slate-300">
        <span class="material-symbols-rounded text-base">brightness_6</span>
        <span class="font-semibold text-sm">Window Management</span>
      </div>
      <p class="text-xs text-gray-700 dark:text-slate-200">Arrange, group, and save your window layouts. Instantly restore your workspace.</p>
    </div>
    <div class="flex-1 bg-rose-50 dark:bg-rose-950 dark:border-rose-900 border border-rose-100 rounded-xl p-5 min-w-[210px]">
      <div class="flex items-center gap-2 mb-1 text-rose-500 dark:text-rose-300">
        <span class="material-symbols-rounded text-base">music_note</span>
        <span class="font-semibold text-sm">Now Playing</span>
      </div>
      <p class="text-xs text-gray-700 dark:text-slate-200">See what’s playing in any tab or app. Details at a glance, tucked in the notch.</p>
    </div>
  </div>

  <!-- Secondary feature cards -->
  <div class="flex flex-col sm:flex-row gap-4 justify-center mt-1 mb-10 w-full max-w-2xl px-2">
    <div class="flex-1 bg-yellow-50 dark:bg-yellow-900 dark:border-yellow-800 border border-yellow-100 rounded-xl p-5 min-w-[210px] flex flex-col items-center">
      <div class="flex items-center gap-1 mb-1 text-yellow-500 dark:text-yellow-200">
        <span class="material-symbols-rounded text-base">verified_user</span>
        <span class="font-semibold text-sm">Supported OS</span>
      </div>
      <p class="text-xs text-gray-700 dark:text-slate-200 text-center">macOS 13+</p>
    </div>
    <div class="flex-1 bg-green-50 dark:bg-green-900 dark:border-green-800 border border-green-100 rounded-xl p-5 min-w-[210px] flex flex-col items-center">
      <div class="flex items-center gap-1 mb-1 text-green-600 dark:text-green-200">
        <span class="material-symbols-rounded text-base">devices</span>
        <span class="font-semibold text-sm">Supported Devices</span>
      </div>
      <p class="text-xs text-gray-700 dark:text-slate-200 text-center">All Macs supported. TouchBar Macs may require special mode.</p>
    </div>
  </div>

  <!-- Footer -->
  <footer class="w-full py-6 text-center text-gray-400 dark:text-slate-500 text-xs" style="font-family:inherit;">
    © {new Date().getFullYear()} Mihai-Eduard Ghețu. All Rights Reserved.
  </footer>
</div>

<style>
.switch-ios {
  position: relative;
  display: inline-block;
  width: 54px;
  height: 32px;
  vertical-align: middle;
}
.switch-ios input {
  opacity: 0;
  width: 0;
  height: 0;
}
.slider-ios {
  position: absolute;
  cursor: pointer;
  top: 0; left: 0; right: 0; bottom: 0;
  background-color: #e5e7eb;
  border-radius: 9999px;
  transition: background-color 0.2s;
}
.dark .slider-ios {
  background-color: #334155;
}
.switch-ios input:checked + .slider-ios {
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
}
.switch-ios input:checked + .slider-ios:before {
  transform: translateX(22px);
}
</style>