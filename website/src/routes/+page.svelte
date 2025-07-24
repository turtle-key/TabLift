<script lang="ts">
  import { run } from 'svelte/legacy';
  let tonOn = $state(true);
  const VIDEO_WITH = "https://bucket.mihai.sh/with.mp4";
  const VIDEO_WITHOUT = "https://bucket.mihai.sh/without.mp4";
  let videoSrc = $state(VIDEO_WITH);
  run(() => {
    videoSrc = tonOn ? VIDEO_WITH : VIDEO_WITHOUT;
  });
  function toggleTonOn() {
    tonOn = !tonOn;
  }
  const repoOwner = 'turtle-key';
  const repoName = 'TabLift';
</script>

<svelte:head>
  <title>TabLift</title>
  <meta name="description" content="TabLift — Makes ⌘+Tab work the way it should — minimized windows included." />
</svelte:head>

<main class="min-h-screen bg-[#f7fafc] dark:bg-[#18181c] flex flex-col items-center font-sans pt-[90px]">
  <div class="w-full max-w-4xl mx-auto px-4">
    <img
      src="https://bucket.mihai.sh/app-icon-168.webp"
      srcset="https://bucket.mihai.sh/app-icon-168.webp 168w, https://bucket.mihai.sh/app-icon-336.webp 336w"
      sizes="(max-width: 400px) 50vw, 168px"
      alt="TabLift Icon"
      class="mx-auto mt-12 mb-8 w-[168px] h-[168px] rounded-3xl shadow"
      draggable="false"
      loading="lazy"
      decoding="async"
      width="168"
      height="168"
    />
    <h1 class="text-6xl md:text-7xl font-extrabold text-gray-900 dark:text-gray-100 text-center mb-3">TabLift</h1>
    <p class="text-gray-600 dark:text-gray-300 mb-8 text-center text-xl sm:text-2xl max-w-2xl mx-auto">
      Makes ⌘+Tab work the way it should — minimized windows included.
    </p>
    <div class="flex flex-col items-center mb-8 w-full">
      <a
        class="download-btn px-8 py-3 rounded-xl font-semibold text-white text-base shadow transition-all duration-300 mb-4"
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
        src="https://bucket.mihai.sh/macbook-380.webp"
        srcset="https://bucket.mihai.sh/macbook-380.webp 380w, https://bucket.mihai.sh/macbook-760.webp 760w, https://bucket.mihai.sh/macbook-1200.webp 1200w"
        sizes="(max-width: 600px) 90vw, (max-width: 1200px) 760px, 1200px"
        alt="macOS screenshot"
        width="380"
        height="247"
        class="z-10 w-full absolute pointer-events-none select-none"
        style="top: -15.75%;"
        draggable="false"
        loading="eager"
        fetchpriority="high"
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
          class="switch-ios mx-2 transition-all duration-200"
          role="switch"
          aria-checked={tonOn}
          aria-label={tonOn ? 'Deactivate app' : 'Activate app'}
          type="button"
          onclick={toggleTonOn}
          tabindex="0"
        > <span class="slider-ios {tonOn ? 'checked' : ''}"></span>
      </button>
      <span class="text-lg font-semibold select-none ml-4 transition-all duration-200" style="color: {tonOn ? '#34C759' : '#a0aec0'};font-family:inherit;">
        {tonOn ? 'activated' : 'deactivated'}
      </span>
    </div>
    <div class="w-full flex flex-col items-center">
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 justify-center items-stretch w-full max-w-4xl">
        <div class="feature-card flex flex-col items-center text-center bg-blue-50 dark:bg-blue-900 border border-blue-100 dark:border-blue-800 rounded-xl p-5 min-w-[210px] h-full transition-all duration-300 cursor-pointer">
          <div class="flex items-center gap-2 mb-1 text-blue-600 dark:text-blue-300">
            <span class="material-symbols-rounded text-base transition-transform duration-300">window</span>
            <span class="font-semibold text-sm">Windows</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">Quickly switch between the minimized apps and their windows.</p>
        </div>
        <div class="feature-card flex flex-col items-center text-center bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-xl p-5 min-w-[210px] h-full transition-all duration-300 cursor-pointer">
          <div class="flex items-center gap-2 mb-1 text-gray-500 dark:text-gray-300">
            <span class="material-symbols-rounded text-base transition-transform duration-300">memory</span>
            <span class="font-semibold text-sm">Minimal Resource Usage</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">Optimized to run smoothly while consuming minimal CPU, memory, and battery.</p>
        </div>
        <div class="feature-card flex flex-col items-center text-center bg-rose-50 dark:bg-rose-900 border border-rose-100 dark:border-rose-900 rounded-xl p-5 min-w-[210px] h-full transition-all duration-300 cursor-pointer">
          <div class="flex items-center gap-2 mb-1 text-rose-500 dark:text-rose-300">
            <span class="material-symbols-rounded text-base transition-transform duration-300">space_dashboard</span>
            <span class="font-semibold text-sm">Modern UI</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200">A clean, intuitive, and responsive interface designed for a seamless user experience</p>
        </div>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 justify-center items-stretch mt-4 w-full max-w-4xl">
        <div class="feature-card flex flex-col items-center text-center bg-yellow-50 dark:bg-yellow-900 border border-yellow-100 dark:border-yellow-800 rounded-xl p-5 min-w-[210px] h-full transition-all duration-300 cursor-pointer">
          <div class="flex items-center gap-1 mb-1 text-yellow-500 dark:text-yellow-300">
            <span class="material-symbols-rounded text-base transition-transform duration-300">verified_user</span>
            <span class="font-semibold text-sm">Supported OS</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200 text-center">macOS 13+</p>
        </div>
        <div class="feature-card flex flex-col items-center text-center bg-green-50 dark:bg-green-900 border border-green-100 dark:border-green-800 rounded-xl p-5 min-w-[210px] h-full transition-all duration-300 cursor-pointer">
          <div class="flex items-center gap-1 mb-1 text-green-600 dark:text-green-300">
            <span class="material-symbols-rounded text-base transition-transform duration-300">devices</span>
            <span class="font-semibold text-sm">Supported Devices</span>
          </div>
          <p class="text-xs text-gray-700 dark:text-gray-200 text-center">All Macs supported.</p>
        </div>
      </div>
    </div>
  </div>
</main>

<style>
.logo-center-container {
  display: flex;
  justify-content: center;
  margin: 3rem auto 2rem auto;
}

.download-btn {
  position: relative;
  overflow: hidden;
  box-shadow: 0 4px 15px rgba(16, 41, 67, 0.3);
  transform: translateY(0);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.download-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
  transition: left 0.5s;
}

.download-btn:hover {
  transform: translateY(-3px) scale(1.05);
  box-shadow: 0 8px 25px rgba(16, 41, 67, 0.4);
  background: #1a3a5c !important;
}

.download-btn:hover::before {
  left: 100%;
}

.download-btn:active {
  transform: translateY(-1px) scale(1.02);
  box-shadow: 0 4px 15px rgba(16, 41, 67, 0.3);
}

.switch-ios {
  position: relative;
  display: inline-block;
  width: 54px;
  height: 32px;
  vertical-align: middle;
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
}

.switch-ios:hover {
  transform: scale(1.05);
}

.switch-ios:active {
  transform: scale(0.98);
}

.slider-ios {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background-color: #e5e7eb;
  border-radius: 9999px;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  width: 54px;
  height: 32px;
  display: block;
  box-shadow: inset 0 2px 4px rgba(0,0,0,0.1);
}

.slider-ios.checked {
  background-color: #34C759;
  box-shadow: inset 0 2px 4px rgba(0,0,0,0.1), 0 0 10px rgba(52, 199, 89, 0.3);
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
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
  transform: translateX(0);
}

.slider-ios.checked:before {
  transform: translateX(22px);
  box-shadow: 0 2px 8px rgba(0,0,0,0.2);
}

.switch-ios:hover .slider-ios:before {
  box-shadow: 0 4px 12px rgba(0,0,0,0.2);
}

.feature-card {
  position: relative;
  overflow: hidden;
}

.feature-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.1), transparent);
  transition: left 0.6s;
}

.feature-card:hover {
  transform: translateY(-5px) scale(1.02);
  box-shadow: 0 10px 25px rgba(0,0,0,0.1);
  border-color: rgba(0,0,0,0.2);
}

:global(html.dark) .feature-card:hover {
  box-shadow: 0 10px 25px rgba(0,0,0,0.3);
  border-color: rgba(255,255,255,0.3);
}

.feature-card:hover::before {
  left: 100%;
}

.feature-card:hover .material-symbols-rounded {
  transform: scale(1.2) rotate(5deg);
}

.feature-card:active {
  transform: translateY(-2px) scale(1.01);
}

/* Individual card hover colors */
.feature-card:nth-child(1):hover {
  background: rgba(59, 130, 246, 0.1);
}

:global(html.dark) .feature-card:nth-child(1):hover {
  background: rgba(59, 130, 246, 0.2);
}

.feature-card:nth-child(2):hover {
  background: rgba(107, 114, 128, 0.1);
}

:global(html.dark) .feature-card:nth-child(2):hover {
  background: rgba(107, 114, 128, 0.2);
}

.feature-card:nth-child(3):hover {
  background: rgba(244, 63, 94, 0.1);
}

:global(html.dark) .feature-card:nth-child(3):hover {
  background: rgba(244, 63, 94, 0.2);
}

.feature-card:nth-child(4):hover {
  background: rgba(245, 158, 11, 0.1);
}

:global(html.dark) .feature-card:nth-child(4):hover {
  background: rgba(245, 158, 11, 0.2);
}

.feature-card:nth-child(5):hover {
  background: rgba(34, 197, 94, 0.1);
}

:global(html.dark) .feature-card:nth-child(5):hover {
  background: rgba(34, 197, 94, 0.2);
}
</style>
