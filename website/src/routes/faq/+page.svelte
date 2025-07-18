<script lang="ts">
  import { base } from '$app/paths';
</script>
<svelte:head>
  <title>TabLift FAQ – Answers to Common Questions</title>
  <meta name="description" content="Find answers to frequently asked questions about TabLift, the macOS utility that makes switching between apps with ⌘+Tab more intuitive by including minimized windows." />
</svelte:head>
<main class="min-h-screen bg-[#f7fafc] dark:bg-[#18181c] flex flex-col items-center font-sans pt-[90px]">
  <div class="w-full max-w-4xl mx-auto px-4 text-gray-900 dark:text-gray-100">
  <h1 class="text-3xl font-bold mb-6">Frequently Asked Questions (FAQ)</h1>

  <section class="mb-8">
    <h2 class="font-semibold text-lg mb-2">What is TabLift?</h2>
    <p>
      TabLift is a lightweight, open-source macOS utility that restores minimized app windows when switching with ⌘+Tab. By default, macOS ignores minimized windows unless you hold the Option key. TabLift fixes this, making app switching intuitive and seamless.
    </p>
  </section>

  <section class="mb-8">
    <h2 class="font-semibold text-lg mb-2">How does TabLift work?</h2>
    <p>
      TabLift runs quietly in the background. When you use ⌘+Tab to switch apps, TabLift automatically restores any minimized windows for the selected application, so you never lose track of your open apps.
    </p>
  </section>

  <section class="mb-8">
    <h2 class="font-semibold text-lg mb-2">Is TabLift free?</h2>
    <p>
      Yes! TabLift is completely free and open-source. You can download it, use it, and even contribute to its development on <a href="https://github.com/turtle-key/TabLift" target="_blank" rel="noopener" class="underline">GitHub</a>.
    </p>
  </section>

  <section class="mb-8">
    <h2 class="font-semibold text-lg mb-2">Which versions of macOS does TabLift support?</h2>
    <p>
      TabLift supports macOS 13 (Ventura) and newer. It is designed for Apple Silicon and Intel Macs.
    </p>
  </section>

  <section class="mb-8">
    <h2 class="font-semibold text-lg mb-2">Does TabLift collect any personal data?</h2>
    <p>
      TabLift does not collect any personal or sensitive information. Only anonymized usage data such as app version, macOS version, and basic feature usage may be collected to help improve the app. For more details, see our <a href={base + "/privacypolicy"} class="underline">Privacy Policy</a>.
    </p>
  </section>

  <section class="mb-8">
    <h2 class="font-semibold text-lg mb-2">How do I uninstall TabLift?</h2>
    <p>
      To uninstall TabLift, simply quit the app and move it to the Trash from your Applications folder.
    </p>
  </section>

  <section class="mb-8">
    <h2 class="font-semibold text-lg mb-2">Where can I get support or report issues?</h2>
    <p>
      For support, feature requests, or to report a bug, please open an issue on our <a href="https://github.com/turtle-key/TabLift/issues" target="_blank" rel="noopener" class="underline">GitHub Issues page</a> or contact me at <a href="mailto:ghetumihaieduard@gmail.com">ghetumihaieduard@gmail.com</a>.
    </p>
  </section>

  <section>
    <h2 class="font-semibold text-lg mb-2">Can I contribute to TabLift?</h2>
    <p>
      Absolutely! TabLift is open-source and welcomes contributions. Check out the <a href="https://github.com/turtle-key/TabLift" target="_blank" rel="noopener" class="underline">GitHub repository</a> for details on how to get started.
    </p>
  </section>
  </div>
</main>