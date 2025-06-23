<script lang="ts">
  let tonOn = true;
  const VIDEO_WITH = "https://bucket.mihai.sh/with.mp4";
  const VIDEO_WITHOUT = "https://bucket.mihai.sh/without.mp4";
  let videoSrc = VIDEO_WITH;
  $: videoSrc = tonOn ? VIDEO_WITH : VIDEO_WITHOUT;
  function toggleTonOn() {
    tonOn = !tonOn;
  }
  const repoOwner = 'turtle-key';
  const repoName = 'TabLift';
</script>

<svelte:head>
  <title>TabLift</title>
  <meta name="description" content="TabLift — Makes ⌘+Tab work the way it should — minimized windows included." />
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

<main class="min-h-screen bg-[#f7fafc] dark:bg-[#18181c] flex flex-col items-center font-sans pt-[90px]">
  <div class="w-full max-w-4xl mx-auto px-4">
    <img src="https://bucket.mihai.sh/app-icon.png" alt="TabLift Icon" class="mx-auto mt-12 mb-8 w-[168px] h-[168px] rounded-3xl shadow" draggable="false" loading="lazy" decoding="async" />
    <h1 class="text-6xl md:text-7xl font-extrabold text-gray-900 dark:text-gray-100 text-center mb-3">TabLift</h1>
    <p class="text-gray-600 dark:text-gray-300 mb-8 text-center text-xl sm:text-2xl max-w-2xl mx-auto">
      Makes ⌘+Tab work the way it should — minimized windows included.
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
    <div class="relative flex flex-col items-center mb-20 w-full">
      <img
        src="https://bucket.mihai.sh/macbook.png"
        alt="macOS screenshot"
        class="z-10 w-full absolute pointer-events-none select-none"
        style="top: -15.75%;"
        draggable="false"
      />
      <div class="relative w-[76.7%] flex justify-center items-center">
        <video
          src={videoSrc}
          muted
          playsinline
          loop
          autoplay
          class="w-full h-full object-cover"
          style="border-radius:7px 7px 0px 0px;"
        ></video>
      </div>
    </div>
    <div class="flex justify-center items-center w-full mb-10">
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
            <span class="material-symbols-rounded text-base">window</span>
            <span class="font-semibold text-sm">Windows</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">Quickly switch between the minimized apps and their windows.</p>
        </div>
        <div class="flex flex-col items-center text-center bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-xl p-5 min-w-[210px] h-full">
          <div class="flex items-center gap-2 mb-1 text-gray-500 dark:text-gray-300">
            <span class="material-symbols-rounded text-base">memory</span>
            <span class="font-semibold text-sm">Minimal Resource Usage</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">Optimized to run smoothly while consuming minimal CPU, memory, and battery.</p>
        </div>
        <div class="flex flex-col items-center text-center bg-rose-50 dark:bg-rose-900 border border-rose-100 dark:border-rose-900 rounded-xl p-5 min-w-[210px] h-full">
          <div class="flex items-center gap-2 mb-1 text-rose-500 dark:text-rose-300">
            <span class="material-symbols-rounded text-base">space_dashboard</span>
            <span class="font-semibold text-sm">Modern UI</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">A clean, intuitive, and responsive interface designed for a seamless user experience</p>
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
          <p class="text-xs text-gray-700 dark:text-gray-200 text-center">All Macs supported.</p>
        </div>
      </div>
    </div>
  </div>
</main>

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
</style>