<script lang="ts">
  import { onMount } from 'svelte';
  let tonOn = true;
  let videoSrc = '/with.mp4';
  let latestDmgUrl: string | null = null;
  let loadingRelease = true;

  $: videoSrc = tonOn ? '/with.mp4' : '/without.mp4';

  const repoOwner = 'turtle-key';
  const repoName = 'TabLift';

  onMount(async () => {
    loadingRelease = true;
    try {
      const res = await fetch(`https://api.github.com/repos/${repoOwner}/${repoName}/releases/latest`);
      const data = await res.json();
      if (data.assets) {
        const dmg = data.assets.find((a) => a.name.endsWith('.dmg'));
        if (dmg) latestDmgUrl = dmg.browser_download_url;
      }
    } catch {
      latestDmgUrl = null;
    }
    loadingRelease = false;
  });
</script>

<svelte:head>
  <title>TabLift</title>
  <meta name="description" content="TabLift — Fresh visuals for tab & window management on macOS." />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap" rel="stylesheet" />
  <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded" rel="stylesheet" />
</svelte:head>

<style>
  .macbook-frame {
    width: 700px;
    height: auto;
    position: relative;
    display: block;
    margin: 0 auto;
    z-index: 10;
    pointer-events: none;
    user-select: none;
  }
  .macbook-video-container {
    position: absolute;
    left: 50%;
    top: 63px;
    width: 580px;
    height: 363px;
    transform: translateX(-50%);
    border-radius: 18px;
    overflow: hidden;
    background: #111;
    z-index: 2;
    box-shadow: 0 1px 12px 0 #0002;
    display: flex;
    align-items: center;
    justify-content: center;
    pointer-events: none;
  }
  @media (max-width: 800px) {
    .macbook-frame { width: 96vw; }
    .macbook-video-container { width: 82vw; height: 51vw; }
  }
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

<div class="min-h-screen bg-[#f7fafc] flex flex-col items-center font-sans" style="font-family: 'Inter', sans-serif;">
  <!-- Top right links -->
  <div class="w-full flex justify-end items-center gap-6 pt-5 pr-10 text-xs text-gray-500">
    <a href="#" class="hover:underline">Privacy Policy</a>
    <a href="#" class="hover:underline">F.A.Q.</a>
  </div>

  <!-- Logo, title, and description -->
  <img src="/logo.png" alt="TabLift Icon" class="mx-auto mt-8 mb-5 w-16 h-16 rounded-2xl shadow" draggable="false" />

  <h1 class="text-3xl sm:text-4xl font-extrabold text-gray-900 text-center mb-2">TabLift</h1>
  <p class="text-gray-600 mb-6 text-center text-sm sm:text-base max-w-lg mx-auto">
    Fresh visuals for Tab, Window and Workspace Management.
  </p>

  <!-- Download button -->
  <div class="flex flex-col items-center mb-5 w-full">
    <a
      class="px-8 py-3 rounded-xl font-semibold text-white text-base shadow transition mb-4"
      style="background:#102943;"
      rel="noopener"
      target="_blank"
      href={latestDmgUrl || "#"}
      aria-disabled={loadingRelease || !latestDmgUrl}
    >
      {#if loadingRelease}
        Loading download...
      {:else if latestDmgUrl}
        Download
      {:else}
        Download unavailable
      {/if}
    </a>

    <!-- Toggle row in center, all stashed together -->
    <div class="flex items-center gap-5 justify-center">
      <label class="switch-ios">
        <input type="checkbox" bind:checked={tonOn} aria-checked={tonOn} />
        <span class="slider-ios"></span>
      </label>
      <span class="text-lg font-semibold select-none"
        style="color: {tonOn ? '#34C759' : '#a0aec0'}">
        {tonOn ? 'activated' : 'deactivated'}
      </span>
    </div>
  </div>

  <!-- MacBook mockup with video overlay -->
  <div class="relative flex justify-center mb-12 w-full" style="height:472px; max-width:100vw;">
    <!-- Video perfectly fitted to mac screen -->
    <div class="macbook-video-container">
      <video
        src={videoSrc}
        autoplay
        loop
        muted
        playsinline
        style="width:100%;height:100%;object-fit:cover;pointer-events:none;"
        tabindex="-1"
      ></video>
    </div>
    <!-- MacBook PNG on top -->
    <img
      src="/macbook.png"
      alt="MacBook Pro"
      draggable="false"
      class="macbook-frame"
    />
  </div>

  <!-- Feature cards (top row) -->
  <div class="flex flex-col sm:flex-row gap-4 justify-center mb-4 w-full max-w-4xl px-2">
    <div class="flex-1 bg-blue-50 border border-blue-100 rounded-xl p-5 min-w-[210px]">
      <div class="flex items-center gap-2 mb-1 text-blue-600">
        <span class="material-symbols-rounded text-base">volume_up</span>
        <span class="font-semibold text-sm">Volume &amp; Tabs</span>
      </div>
      <p class="text-xs text-gray-700">Quickly adjust volume and organize browser tabs with modern, compact popups.</p>
    </div>
    <div class="flex-1 bg-gray-50 border border-gray-100 rounded-xl p-5 min-w-[210px]">
      <div class="flex items-center gap-2 mb-1 text-gray-500">
        <span class="material-symbols-rounded text-base">brightness_6</span>
        <span class="font-semibold text-sm">Window Management</span>
      </div>
      <p class="text-xs text-gray-700">Arrange, group, and save your window layouts. Instantly restore your workspace.</p>
    </div>
    <div class="flex-1 bg-rose-50 border border-rose-100 rounded-xl p-5 min-w-[210px]">
      <div class="flex items-center gap-2 mb-1 text-rose-500">
        <span class="material-symbols-rounded text-base">music_note</span>
        <span class="font-semibold text-sm">Now Playing</span>
      </div>
      <p class="text-xs text-gray-700">See what’s playing in any tab or app. Details at a glance, tucked in the notch.</p>
    </div>
  </div>

  <!-- Feature cards (bottom row) -->
  <div class="flex flex-col sm:flex-row gap-4 justify-center mt-1 mb-10 w-full max-w-2xl px-2">
    <div class="flex-1 bg-yellow-50 border border-yellow-100 rounded-xl p-5 min-w-[210px] flex flex-col items-center">
      <div class="flex items-center gap-1 mb-1 text-yellow-500">
        <span class="material-symbols-rounded text-base">verified_user</span>
        <span class="font-semibold text-sm">Supported OS</span>
      </div>
      <p class="text-xs text-gray-700 text-center">macOS 13+</p>
    </div>
    <div class="flex-1 bg-green-50 border border-green-100 rounded-xl p-5 min-w-[210px] flex flex-col items-center">
      <div class="flex items-center gap-1 mb-1 text-green-600">
        <span class="material-symbols-rounded text-base">devices</span>
        <span class="font-semibold text-sm">Supported Devices</span>
      </div>
      <p class="text-xs text-gray-700 text-center">All Macs supported. TouchBar Macs may require special mode.</p>
    </div>
  </div>

  <!-- Footer -->
  <footer class="w-full py-6 text-center text-gray-400 text-xs">
    © {new Date().getFullYear()} Mihai-Eduard Ghețu. All Rights Reserved.
  </footer>
</div>
